import Foundation

/// Open Food Facts (OFF) ist eine offene, crowd-sourced Lebensmittel-Datenbank
/// unter Open Database License (ODbL). 3 Mio+ Produkte weltweit, starke DACH-
/// Coverage. Frei kommerziell nutzbar — nur Attribution erforderlich (siehe
/// AboutAppView + Privacy Policy).
///
/// Wir nutzen die v2-API mit `?fields=` um die Response klein zu halten.
/// Kein API-Key, keine Rate-Limits, kein User-Tracking — nur ein freundlicher
/// `User-Agent`-Header.

/// Internes, schlankes Ergebnis nach erfolgreichem OFF-Lookup. Felder, die
/// in OFF nicht verlässlich gepflegt sind, bleiben nil.
struct OFFNutrientResult {
    let barcode: String
    let name: String
    let brand: String?
    let kcalPer100g: Double
    let proteinPer100g: Double
    let fatPer100g: Double
    let carbsPer100g: Double
    let fiberPer100g: Double?
    let sugarPer100g: Double?
    let saltPer100g: Double?
    let servingSizeGrams: Double?
    let imageUrl: URL?
}

enum OpenFoodFactsError: LocalizedError {
    case notFound
    case networkUnavailable
    case rateLimited
    case invalidResponse
    case serverError(Int)
    case insufficientData

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Dieser Code ist in der Datenbank nicht erfasst."
        case .networkUnavailable:
            return "Kein Internet. Versuche es nochmal oder gib das Produkt manuell ein."
        case .rateLimited:
            return "Zu viele Anfragen. Bitte kurz warten."
        case .invalidResponse:
            return "Antwort konnte nicht gelesen werden."
        case .serverError(let code):
            return "Server-Fehler \(code). Bitte später nochmal versuchen."
        case .insufficientData:
            return "Für diesen Code fehlen die Nährwerte in der Datenbank. Bitte Etikett scannen oder manuell eingeben."
        }
    }
}

// MARK: - Raw API DTOs

/// Top-Level Response: `{ status: 0|1, product: {...} }`
private struct OFFResponse: Decodable {
    let status: Int
    let product: OFFRawProduct?
}

/// Nur die Felder, die wir via `?fields=` anfordern. Alle optional, da OFF
/// crowd-sourced ist und Felder häufig fehlen.
private struct OFFRawProduct: Decodable {
    let productName: String?
    let productNameDe: String?
    let brands: String?
    let nutriments: OFFNutriments?
    let servingSize: String?
    let imageFrontSmallUrl: String?

    enum CodingKeys: String, CodingKey {
        case productName        = "product_name"
        case productNameDe      = "product_name_de"
        case brands
        case nutriments
        case servingSize        = "serving_size"
        case imageFrontSmallUrl = "image_front_small_url"
    }
}

/// OFF kennt Dutzende Energie-Felder (kJ, kcal, pro 100 g, pro Portion, etc.).
/// Wir versuchen `energy-kcal_100g` zuerst, fallen dann auf `energy_100g` (kJ)
/// zurück und konvertieren.
private struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let energy100g: Double?
    let proteins100g: Double?
    let fat100g: Double?
    let carbs100g: Double?
    let fiber100g: Double?
    let sugars100g: Double?
    let salt100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energy100g     = "energy_100g"
        case proteins100g   = "proteins_100g"
        case fat100g        = "fat_100g"
        case carbs100g      = "carbohydrates_100g"
        case fiber100g      = "fiber_100g"
        case sugars100g     = "sugars_100g"
        case salt100g       = "salt_100g"
    }
}

enum OpenFoodFactsService {
    /// Endpoint-Basis. Wir nutzen die globale `world.openfoodfacts.org` und nicht
    /// `de.openfoodfacts.org`, weil die globale alle Produkte indexiert und wir
    /// das Sprach-Field-Routing über `product_name_de` selbst machen.
    private static let baseURL = "https://world.openfoodfacts.org/api/v2/product"

    /// Felder-Filter — schlankt die Response von ~50 KB auf ~2 KB.
    private static let fields = "product_name,product_name_de,brands,nutriments,serving_size,image_front_small_url"

    /// Fetcht ein Produkt für den gegebenen Barcode. Liefert ein gemapptes
    /// `OFFNutrientResult` oder wirft typed errors.
    static func fetch(barcode: String) async throws -> OFFNutrientResult {
        // OFF erwartet einen freundlichen User-Agent — sie blockieren generische
        // Bot-UAs. Wir identifizieren uns gemäss OFF-API-Etiquette.
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let userAgent = "Kcal-Kun/\(appVersion) (martinschulz.privat@gmail.com)"

        guard let url = URL(string: "\(baseURL)/\(barcode).json?fields=\(fields)") else {
            throw OpenFoodFactsError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            let nsError = error as NSError
            if nsError.code == NSURLErrorNotConnectedToInternet
                || nsError.code == NSURLErrorTimedOut
                || nsError.code == NSURLErrorNetworkConnectionLost {
                throw OpenFoodFactsError.networkUnavailable
            }
            throw OpenFoodFactsError.invalidResponse
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpenFoodFactsError.invalidResponse
        }
        switch http.statusCode {
        case 200:
            break
        case 404:
            throw OpenFoodFactsError.notFound
        case 429:
            throw OpenFoodFactsError.rateLimited
        case 500...599:
            throw OpenFoodFactsError.serverError(http.statusCode)
        default:
            throw OpenFoodFactsError.invalidResponse
        }

        // DoS-Schutz: Typische OFF-Response ist <5 KB. 200 KB ist ein generöses
        // Limit, das alle Edge-Cases abdeckt (Produkte mit vielen Übersetzungen),
        // aber Memory-Exhaustion-Angriffe verhindert.
        guard data.count < 200_000 else {
            throw OpenFoodFactsError.invalidResponse
        }

        let decoded: OFFResponse
        do {
            decoded = try JSONDecoder().decode(OFFResponse.self, from: data)
        } catch {
            throw OpenFoodFactsError.invalidResponse
        }

        // status == 0 bedeutet "Produkt existiert nicht in OFF"
        guard decoded.status == 1, let product = decoded.product else {
            throw OpenFoodFactsError.notFound
        }

        return try mapToResult(barcode: barcode, raw: product)
    }

    // MARK: - Mapping

    /// Mappt das OFF-Roh-DTO auf unsere interne Struktur und prüft, ob
    /// genügend Daten vorhanden sind (zumindest kcal + ein Makro).
    private static func mapToResult(barcode: String, raw: OFFRawProduct) throws -> OFFNutrientResult {
        // Name: bevorzugt deutsch, sonst international, sonst Brand als Fallback.
        let rawName = raw.productNameDe?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? raw.productName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? raw.brands?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        guard let name = rawName, !name.isEmpty else {
            throw OpenFoodFactsError.insufficientData
        }

        // kcal: `energy-kcal_100g` ist die saubere Variante. Fallback `energy_100g`
        // ist in kJ → / 4.184. OFF liefert manchmal beides, manchmal nur eins.
        let nutr = raw.nutriments
        let kcal: Double? = {
            if let kcal = nutr?.energyKcal100g, kcal > 0 { return kcal }
            if let kj = nutr?.energy100g, kj > 0 { return kj / 4.184 }
            return nil
        }()

        guard let kcalValue = kcal else {
            throw OpenFoodFactsError.insufficientData
        }

        // Serving size aus String parsen — OFF liefert "25 g", "1 portion (30g)", etc.
        // Wir extrahieren einfach die erste Zahl.
        let serving: Double? = raw.servingSize.flatMap { parseGrams(from: $0) }

        return OFFNutrientResult(
            barcode: barcode,
            name: name,
            brand: raw.brands?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            kcalPer100g:    kcalValue,
            proteinPer100g: nutr?.proteins100g ?? 0,
            fatPer100g:     nutr?.fat100g ?? 0,
            carbsPer100g:   nutr?.carbs100g ?? 0,
            fiberPer100g:   nutr?.fiber100g,
            sugarPer100g:   nutr?.sugars100g,
            saltPer100g:    nutr?.salt100g,
            servingSizeGrams: serving,
            imageUrl: raw.imageFrontSmallUrl.flatMap { URL(string: $0) }
        )
    }

    /// Holt die erste Zahl aus z. B. "25 g" oder "1 portion (30g)" und gibt sie
    /// als Gramm-Wert zurück.
    private static func parseGrams(from text: String) -> Double? {
        let pattern = #"(\d+[\.,]?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else {
            return nil
        }
        let numStr = nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: ".")
        return Double(numStr)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
