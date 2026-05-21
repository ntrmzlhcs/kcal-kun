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

struct DishAnalysisResult: Decodable {
    let name: String
    let estimatedGrams: Double
    let kcal: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let fiber: Double
}

struct MealRawComponent: Decodable {
    let blvName: String
    let grams: Double
}

enum GeminiServiceError: LocalizedError {
    case missingApiKey
    case noLabelDetected
    case noMealDetected
    case noDishDetected
    case networkUnavailable
    case rateLimited
    case invalidResponse
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "Gemini-API-Key fehlt. Geh ins Profil → KI-Setup, um deinen Key einzurichten."
        case .noLabelDetected:
            return "Kein Nährwerttisch erkannt. Foto wiederholen oder manuell eingeben."
        case .noMealDetected:
            return "Keine Mahlzeit erkannt. Bitte ein anderes Foto versuchen."
        case .noDishDetected:
            return "Kein Gericht erkannt. Bitte ein anderes Foto versuchen."
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

    /// DoS-Schutz: maximale akzeptierte Response-Grösse. Typische Gemini-Response
    /// ist 5–15 KB; 500 KB ist 30× generös und deckt alle Edge-Cases ab. Bei
    /// einer manipulierten Antwort (z. B. via Man-in-the-Middle) verhindert
    /// dies Memory-Exhaustion.
    private static let maxResponseBytes = 500_000

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
        guard let apiKey = APIKeyService.getKey(),
              !apiKey.isEmpty
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

        guard data.count < maxResponseBytes else {
            throw GeminiServiceError.invalidResponse
        }

        return try parseResponse(data)
    }

    static func analyzeMeal(from jpegData: Data, blvNames: [String]) async throws -> [MealRawComponent] {
        guard let apiKey = APIKeyService.getKey(),
              !apiKey.isEmpty
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

        guard data.count < maxResponseBytes else {
            throw GeminiServiceError.invalidResponse
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

    static func analyzeDish(from jpegData: Data) async throws -> DishAnalysisResult {
        guard let apiKey = APIKeyService.getKey(),
              !apiKey.isEmpty
        else { throw GeminiServiceError.missingApiKey }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw GeminiServiceError.invalidResponse }

        let prompt = """
            Du analysierst das Gericht im Foto. Berücksichtige:
            - Alle sichtbaren Zutaten
            - Typische Kochöle/Fette zur Zubereitung (Olivenöl, Butter, Sonnenblumenöl fürs Braten/Backen)
            - Typische Portionsgrössen der Schweizer/mitteleuropäischen Küche

            Gib NUR ein JSON-Objekt zurück — kein Markdown, keine Erklärung:
            {
              "name": "<kurzer, präziser Name auf Deutsch>",
              "estimatedGrams": <Gesamtgewicht der Portion in g>,
              "kcal": <Gesamtkalorien>,
              "protein": <Gesamtprotein in g>,
              "fat": <Gesamtfett inkl. Kochfett in g>,
              "carbs": <Gesamtkohlenhydrate in g>,
              "fiber": <Gesamtballaststoffe in g>
            }
            Wenn kein Essen sichtbar: {"error": "no_dish_detected"}
            """

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["inlineData": ["mimeType": "image/jpeg", "data": jpegData.base64EncodedString()]],
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
        struct ErrorCheck: Decodable { let error: String? }

        guard let apiResponse = try? JSONDecoder().decode(GeminiAPIResponse.self, from: data),
              let jsonText = apiResponse.candidates.first?.content.parts.first?.text,
              let jsonData = jsonText.data(using: .utf8)
        else { throw GeminiServiceError.invalidResponse }

        if let check = try? JSONDecoder().decode(ErrorCheck.self, from: jsonData),
           check.error == "no_dish_detected" {
            throw GeminiServiceError.noDishDetected
        }

        guard let result = try? JSONDecoder().decode(DishAnalysisResult.self, from: jsonData)
        else { throw GeminiServiceError.invalidResponse }

        return result
    }

    static func analyzeNutrition(prompt: String) async throws -> String {
        guard let apiKey = APIKeyService.getKey(),
              !apiKey.isEmpty
        else { throw GeminiServiceError.missingApiKey }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw GeminiServiceError.invalidResponse }
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.4, "responseMimeType": "application/json"]
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
        profile: UserProfile?,
        rollingWeights: [Date: Double] = [:]
    ) -> String {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let allDays   = (0..<30).map { cal.date(byAdding: .day, value: -$0, to: today)! }.reversed()
        let recentDays = Array(allDays.suffix(7))
        let olderDays  = Array(allDays.prefix(23))

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_CH")
        fmt.dateFormat = "dd. MMMM yyyy"

        var byDay: [Date: [DiaryEntry]] = [:]
        for entry in entries {
            byDay[cal.startOfDay(for: entry.date), default: []].append(entry)
        }

        var profileText: String
        if let p = profile {
            let goalLabel: String = switch p.goalType {
            case .deficit:     "Kaloriendefizit"
            case .maintenance: "Gewicht halten"
            case .surplus:     "Massephase"
            }
            let targetKcal: Double = switch p.goalType {
            case .deficit:     p.bmr - p.kcalDelta
            case .maintenance: p.bmr
            case .surplus:     p.bmr + p.kcalDelta
            }
            let target     = Int(targetKcal)
            profileText = """
            - Grösse: \(Int(p.heightCm)) cm, Gewicht: \(String(format: "%.1f", p.weightKg)) kg
            - Grundumsatz (BMR): \(Int(p.bmr)) kcal
            - Ziel: \(goalLabel) (\(p.goalType.displayName)), Delta: \(Int(p.kcalDelta)) kcal/Tag
            - Effektives Tagesziel (ohne Bewegung): \(target) kcal
            - Ernährungsstil: \(p.dietStyle.label) (\(p.dietStyle.splitLabel))
            - Makro-Ziele: Protein \(Int(p.proteinGoal(kcal: targetKcal)))g · KH \(Int(p.carbGoal(kcal: targetKcal)))g · Fett \(Int(p.fatGoal(kcal: targetKcal)))g
            """
            if let bf = p.bodyFatPercent {
                profileText += "\n- Körperfettanteil: \(String(format: "%.1f", bf)) %"
            }
        } else {
            profileText = "(kein Profil vorhanden)"
        }

        // Gewichtsabschnitt
        var weightSection = ""
        let sortedWeights = rollingWeights.sorted { $0.key < $1.key }
        if sortedWeights.count >= 2 {
            let first = sortedWeights.first!
            let last  = sortedWeights.last!
            let delta = last.value - first.value
            let sign  = delta >= 0 ? "+" : ""
            let days30 = cal.dateComponents([.day], from: first.key, to: last.key).day ?? 0
            var lines  = sortedWeights.map { "\(fmt.string(from: $0.key)): \(String(format: "%.1f", $0.value)) kg" }.joined(separator: "\n")
            lines += "\nTrend: \(String(format: "%.1f", first.value)) kg → \(String(format: "%.1f", last.value)) kg (\(sign)\(String(format: "%.1f", delta)) kg über \(days30) Tage)"
            weightSection = "\n\nGEWICHTSVERLAUF (Ø 7 Messungen):\n\(lines)"
        }

        // Ältere 23 Tage (Übersicht, ohne Produktliste)
        var olderLines = ""
        var olderKcal = 0.0, olderWorkout = 0.0
        var olderWithEntries = 0, olderWithWorkout = 0
        for day in olderDays {
            let dayEntries = byDay[day] ?? []
            let workout    = workoutKcals[day] ?? 0
            let dayKcal    = dayEntries.reduce(0) { $0 + $1.kcal }
            let dayProtein = dayEntries.reduce(0) { $0 + $1.protein }
            let dayCarbs   = dayEntries.reduce(0) { $0 + $1.carbs }
            let dayFat     = dayEntries.reduce(0) { $0 + $1.fat }
            olderKcal    += dayKcal
            olderWorkout += workout
            if dayKcal  > 0 { olderWithEntries += 1 }
            if workout  > 0 { olderWithWorkout += 1 }
            olderLines += "\n\(fmt.string(from: day)) | \(Int(dayKcal)) kcal (P \(Int(dayProtein))g K \(Int(dayCarbs))g F \(Int(dayFat))g) | Workout: \(Int(workout)) kcal"
        }
        let olderAvgKcal    = olderWithEntries > 0 ? Int((olderKcal / Double(olderWithEntries)).rounded()) : 0
        let olderAvgWorkout = olderWithWorkout > 0 ? Int((olderWorkout / Double(olderWithWorkout)).rounded()) : 0

        // Letzte 7 Tage (Detail mit Produktliste)
        var recentLines = ""
        var recentKcal = 0.0, recentWorkout = 0.0
        var recentWithEntries = 0, recentWithWorkout = 0
        for day in recentDays {
            let dayEntries = byDay[day] ?? []
            let workout    = workoutKcals[day] ?? 0
            let dayKcal    = dayEntries.reduce(0) { $0 + $1.kcal }
            let dayProtein = dayEntries.reduce(0) { $0 + $1.protein }
            let dayCarbs   = dayEntries.reduce(0) { $0 + $1.carbs }
            let dayFat     = dayEntries.reduce(0) { $0 + $1.fat }
            let dayFiber   = dayEntries.reduce(0) { $0 + $1.fiber }
            recentKcal    += dayKcal
            recentWorkout += workout
            if dayKcal  > 0 { recentWithEntries += 1 }
            if workout  > 0 { recentWithWorkout += 1 }
            recentLines += "\n\n\(fmt.string(from: day)) | Ernährung: \(Int(dayKcal)) kcal (P \(Int(dayProtein))g, K \(Int(dayCarbs))g, F \(Int(dayFat))g, B \(String(format: "%.1f", dayFiber))g) | Bewegung: \(Int(workout)) kcal"
            if dayEntries.isEmpty {
                recentLines += "\n  (keine Einträge)"
            } else {
                for entry in dayEntries {
                    recentLines += "\n  - \(entry.product?.name ?? entry.productName), \(Int(entry.grams.rounded()))g"
                }
            }
        }
        let recentAvgKcal    = Int((recentKcal    / 7).rounded())
        let recentAvgWorkout = Int((recentWorkout / 7).rounded())

        let from30 = fmt.string(from: allDays.first ?? today)

        return """
        Du bist Ernährungs- und Sportwissenschaftler. Analysiere Ernährung und Aktivität der letzten 30 Tage.
        Stütze dich auf aktuelle wissenschaftliche Erkenntnisse, ohne Bias oder kommerzielle Interessen.\(weightSection)

        Nutzerprofil:
        \(profileText)

        TAGE 8–30 (Übersicht, \(from30) – \(fmt.string(from: recentDays.first ?? today))):\(olderLines)

        Ø Tage 8–30: \(olderAvgKcal) kcal Ernährung/Tag | \(olderAvgWorkout) kcal Workout/Tag (an Workout-Tagen) | Tage mit Einträgen: \(olderWithEntries)/23 | Tage mit Workout: \(olderWithWorkout)/23

        LETZTE 7 TAGE (Detail, \(fmt.string(from: recentDays.first ?? today)) – \(fmt.string(from: today))):\(recentLines)

        Ø letzte 7 Tage: \(recentAvgKcal) kcal Ernährung/Tag | \(recentAvgWorkout) kcal Workout/Tag | Tage mit Einträgen: \(recentWithEntries)/7 | Tage mit Workout: \(recentWithWorkout)/7

        Antworte ausschliesslich mit validem JSON (kein Text davor/danach):
        {
          "sections": [
            {
              "id": "energy",
              "title": "Energiebilanz & Trend",
              "highlight": "<max. 40 Zeichen: 1 zentrale Erkenntnis>",
              "body": "<2–4 Sätze. Beziehe Gewichtstrend, Zieltyp (\(profile?.goalType.displayName ?? "unbekannt")) und Tagesziel ein.>"
            },
            {
              "id": "comparison",
              "title": "Letzte 7 vs. 30 Tage",
              "highlight": "<Verbesserung oder Verschlechterung in 1 Phrase>",
              "body": "<Vergleich Kalorien, Makros, Konsistenz. Beziehe den Ernährungsstil und die Makro-Ziele ein.>"
            },
            {
              "id": "macros",
              "title": "Makros & Protein",
              "highlight": "<Status in 1 Phrase>",
              "body": "<Protein-Adequacy vs. Ziel, Kohlenhydrat- und Fettqualität, Ballaststoffe, Bezug auf Ernährungsstil-Splits.>"
            },
            {
              "id": "movement",
              "title": "Bewegung",
              "highlight": "<Frequenz oder Einfluss kurz>",
              "body": "<Workout-Frequenz, Einfluss auf Energiebilanz, Eat-back-Kalorien.>"
            },
            {
              "id": "foodquality",
              "title": "Lebensmittelqualität",
              "highlight": "<1 Schlagwort>",
              "body": "<Verarbeitungsgrad, Vielfalt, Nährstoffdichte in 2–3 Sätzen.>"
            },
            {
              "id": "meals",
              "title": "Mahlzeitenvorschläge",
              "meals": [
                { "name": "<Name>", "portions": "<Menge>", "macros": "<P/KH/F · kcal>" },
                { "name": "<Name>", "portions": "<Menge>", "macros": "<P/KH/F · kcal>" },
                { "name": "<Name>", "portions": "<Menge>", "macros": "<P/KH/F · kcal>" }
              ]
            }
          ]
        }
        Ersetze alle <...>-Platzhalter durch echte Werte. Sei direkt, präzise. Keine Floskeln. Sprache: Deutsch.
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
