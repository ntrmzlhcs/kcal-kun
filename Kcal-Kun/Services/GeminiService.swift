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

struct MealRawComponent: Decodable {
    let blvName: String
    let grams: Double
}

enum GeminiServiceError: LocalizedError {
    case missingApiKey
    case noLabelDetected
    case noMealDetected
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
        case .noMealDetected:
            return "Keine Mahlzeit erkannt. Bitte ein anderes Foto versuchen."
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

    static func analyzeMeal(from jpegData: Data, blvNames: [String]) async throws -> [MealRawComponent] {
        guard let apiKey = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String,
              !apiKey.isEmpty, apiKey != "DEIN_GEMINI_API_KEY_HIER"
        else { throw GeminiServiceError.missingApiKey }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw GeminiServiceError.invalidResponse }

        let productList = blvNames.joined(separator: "\n")
        let prompt = """
            Analyse the food in the image. For each visible food component, find the single best \
            matching entry from the product list below and estimate the gram amount.
            Return ONLY a JSON array — no markdown, no explanation:
            [{"blvName": "<exact name from list>", "grams": <number>}, ...]
            If no food is visible, return: []

            Product list:
            \(productList)
            """

        let base64Image = jpegData.base64EncodedString()
        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["inlineData": ["mimeType": "image/jpeg", "data": base64Image]],
                    ["text": prompt]
                ]
            ]],
            "generationConfig": ["temperature": 0, "responseMimeType": "application/json"]
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

        struct GeminiAPIResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        guard let apiResponse = try? JSONDecoder().decode(GeminiAPIResponse.self, from: data),
              let jsonText = apiResponse.candidates.first?.content.parts.first?.text,
              let jsonData = jsonText.data(using: .utf8)
        else { throw GeminiServiceError.invalidResponse }

        guard let components = try? JSONDecoder().decode([MealRawComponent].self, from: jsonData)
        else { throw GeminiServiceError.invalidResponse }

        if components.isEmpty { throw GeminiServiceError.noMealDetected }
        return components
    }

    static func analyzeNutrition(prompt: String) async throws -> String {
        guard let apiKey = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String,
              !apiKey.isEmpty, apiKey != "DEIN_GEMINI_API_KEY_HIER"
        else { throw GeminiServiceError.missingApiKey }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw GeminiServiceError.invalidResponse }
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.4]
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
            default:  throw GeminiServiceError.serverError(httpResponse.statusCode)
            }
        }

        struct GeminiAPIResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        guard let apiResponse = try? JSONDecoder().decode(GeminiAPIResponse.self, from: data),
              let text = apiResponse.candidates.first?.content.parts.first?.text,
              !text.isEmpty
        else { throw GeminiServiceError.invalidResponse }

        return text
    }

    static func buildNutritionPrompt(
        entries: [DiaryEntry],
        workoutKcals: [Date: Double],
        profile: UserProfile?
    ) -> String {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let days  = (0..<7).map { cal.date(byAdding: .day, value: -$0, to: today)! }.reversed()

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_CH")
        fmt.dateFormat = "dd. MMMM yyyy"

        var byDay: [Date: [DiaryEntry]] = [:]
        for entry in entries {
            byDay[cal.startOfDay(for: entry.date), default: []].append(entry)
        }

        let profileText: String
        if let p = profile {
            let goalLabel = p.goalType == .deficit ? "Kaloriendefizit" : "Massephase"
            let target    = Int(p.goalType == .deficit ? p.bmr - p.kcalDelta : p.bmr + p.kcalDelta)
            profileText = """
            - Grösse: \(Int(p.heightCm)) cm, Gewicht: \(String(format: "%.1f", p.weightKg)) kg
            - Grundumsatz (BMR): \(Int(p.bmr)) kcal
            - Ziel: \(goalLabel), Delta: \(Int(p.kcalDelta)) kcal/Tag
            - Effektives Tagesziel (ohne Bewegung): \(target) kcal
            """
        } else {
            profileText = "(kein Profil vorhanden)"
        }

        var daysLines = ""
        var totalKcal = 0.0, totalWorkout = 0.0
        var daysWithEntries = 0, daysWithWorkout = 0

        for day in days {
            let dayEntries = byDay[day] ?? []
            let workout    = workoutKcals[day] ?? 0
            let dayKcal    = dayEntries.reduce(0) { $0 + $1.kcal }
            let dayProtein = dayEntries.reduce(0) { $0 + $1.protein }
            let dayCarbs   = dayEntries.reduce(0) { $0 + $1.carbs }
            let dayFat     = dayEntries.reduce(0) { $0 + $1.fat }
            let dayFiber   = dayEntries.reduce(0) { $0 + $1.fiber }

            totalKcal    += dayKcal
            totalWorkout += workout
            if dayKcal   > 0 { daysWithEntries += 1 }
            if workout   > 0 { daysWithWorkout += 1 }

            daysLines += "\n\n\(fmt.string(from: day)) | Ernährung: \(Int(dayKcal)) kcal (P \(Int(dayProtein))g, K \(Int(dayCarbs))g, F \(Int(dayFat))g, B \(String(format: "%.1f", dayFiber))g) | Bewegung: \(Int(workout)) kcal"
            if dayEntries.isEmpty {
                daysLines += "\n  (keine Einträge)"
            } else {
                for entry in dayEntries {
                    daysLines += "\n  - \(entry.product.name), \(Int(entry.grams.rounded()))g"
                }
            }
        }

        let avgKcal    = Int((totalKcal    / 7).rounded())
        let avgWorkout = Int((totalWorkout / 7).rounded())
        let from = fmt.string(from: days.first ?? today)
        let to   = fmt.string(from: today)

        return """
        Du bist Ernährungs- und Sportwissenschaftler. Analysiere die Ernährung und Aktivität der letzten 7 Tage.
        Stütze dich auf aktuelle wissenschaftliche Erkenntnisse, ohne Bias oder kommerzielle Interessen.

        Nutzerprofil:
        \(profileText)

        Einträge \(from)–\(to):\(daysLines)

        Ø Ernährungskalorien/Tag: \(avgKcal) kcal | Ø Bewegungskalorien/Tag: \(avgWorkout) kcal
        Tage mit Einträgen: \(daysWithEntries)/7 | Tage mit Bewegung: \(daysWithWorkout)/7

        Analysiere auf Deutsch in 3–5 Absätzen:
        1. Energiebilanz (Ist vs. Ziel inkl. Bewegung, Konsistenz)
        2. Makronährstoffqualität und -verteilung
        3. Lebensmittelqualität (Verarbeitungsgrad, Vielfalt, Nährstoffdichte)
        4. Bewegungsverhalten und dessen Einfluss auf die Bilanz
        5. Konkrete, priorisierte Empfehlungen
        Sei direkt und präzise. Keine allgemeinen Floskeln.
        """
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
