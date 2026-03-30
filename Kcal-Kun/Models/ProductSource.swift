import Foundation

enum ProductSource: String, Codable {
    case ocr, blvApi, preloaded, manual

    var displayName: String {
        switch self {
        case .ocr:       "Gescannt"
        case .blvApi:    "BLV"
        case .preloaded: "Vorgeladen"
        case .manual:    "Manuell"
        }
    }
}
