import Foundation

struct NutritionScanResult {
    var productNameGuess: String?
    var kcalPer100g: Double?
    var proteinPer100g: Double?
    var fatPer100g: Double?
    var carbsPer100g: Double?
    var fiberPer100g: Double?
    var sugarPer100g: Double?
    var saltPer100g: Double?
}

enum GeminiServiceError: LocalizedError {
    case missingApiKey
    case noLabelDetected
    case networkUnavailable
    case rateLimited
    case invalidResponse
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "API-Key fehlt. Bitte Secrets.xcconfig prüfen."
        case .noLabelDetected:
            return "Kein Nährwerttisch erkannt. Foto wiederholen oder manuell eingeben."
        case .networkUnavailable:
            return "Kein Internet. Werte manuell eingeben."
        case .rateLimited:
            return "Zu viele Anfragen. Bitte kurz warten."
        case .invalidResponse:
            return "Antwort konnte nicht gelesen werden. Manuell eingeben."
        case .serverError(let code):
            return "Fehler \(code). Manuell eingeben."
        }
    }
}

struct GeminiService {
    static let modelName = "gemini-2.5-flash"

    private static let extractionPrompt = """
        You are a nutrition data extraction assistant.
        Analyse the food packaging label in the image and return ONLY a JSON object
        with the following structure — no markdown, no explanation, just the JSON:
        {
          "kcalPer100g": <number or null>,
          "proteinPer100g": <number or null>,
          "fatPer100g": <number or null>,
          "carbsPer100g": <number or null>,
          "fiberPer100g": <number or null>,
          "sugarPer100g": <number or null>,
          "saltPer100g": <number or null>,
          "productNameGuess": "<string or null>"
        }
        Rules:
        - All values must be per 100g. If per serving, convert using serving size.
        - Use null for any field not visible.
        - If no nutrition table is visible, return: {"error": "no_label_detected"}
        - No text outside the JSON object.
        """

    static func extractNutrition(from jpegData: Data) async throws -> NutritionScanResult {
        guard let apiKey = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String,
              !apiKey.isEmpty,
              apiKey != "DEIN_GEMINI_API_KEY_HIER"
        else {
            throw GeminiServiceError.missingApiKey
        }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiServiceError.invalidResponse
        }

        let base64Image = jpegData.base64EncodedString()

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "inlineData": [
                                "mimeType": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        ["text": extractionPrompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0,
                "responseMimeType": "application/json"
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            if urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                throw GeminiServiceError.networkUnavailable
            }
            throw GeminiServiceError.invalidResponse
        }

        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200: break
            case 429: throw GeminiServiceError.rateLimited
            default: throw GeminiServiceError.serverError(httpResponse.statusCode)
            }
        }

        return try parseResponse(data)
    }

    private static func parseResponse(_ data: Data) throws -> NutritionScanResult {
        struct GeminiAPIResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable {
                        let text: String
                    }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        struct GeminiRawResult: Decodable {
            let kcalPer100g: Double?
            let proteinPer100g: Double?
            let fatPer100g: Double?
            let carbsPer100g: Double?
            let fiberPer100g: Double?
            let sugarPer100g: Double?
            let saltPer100g: Double?
            let productNameGuess: String?
            let error: String?
        }

        guard let apiResponse = try? JSONDecoder().decode(GeminiAPIResponse.self, from: data),
              let jsonText = apiResponse.candidates.first?.content.parts.first?.text
        else {
            throw GeminiServiceError.invalidResponse
        }

        guard let jsonData = jsonText.data(using: .utf8),
              let raw = try? JSONDecoder().decode(GeminiRawResult.self, from: jsonData)
        else {
            throw GeminiServiceError.invalidResponse
        }

        if raw.error == "no_label_detected" {
            throw GeminiServiceError.noLabelDetected
        }

        return NutritionScanResult(
            productNameGuess: raw.productNameGuess,
            kcalPer100g: raw.kcalPer100g,
            proteinPer100g: raw.proteinPer100g,
            fatPer100g: raw.fatPer100g,
            carbsPer100g: raw.carbsPer100g,
            fiberPer100g: raw.fiberPer100g,
            sugarPer100g: raw.sugarPer100g,
            saltPer100g: raw.saltPer100g
        )
    }
}
