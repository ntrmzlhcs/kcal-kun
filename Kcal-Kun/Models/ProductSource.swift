import Foundation

enum ProductSource: String, Codable {
    case ocr, blvApi, preloaded, manual, dish, meal, barcode

    var displayName: String {
        switch self {
        case .ocr:       "Gescannt"
        case .blvApi:    "BLV"
        case .preloaded: "Vorgeladen"
        case .manual:    "Manuell"
        case .dish:      "Gericht"
        case .meal:      "Lebensmittel"
        case .barcode:   "Open Food Facts"
        }
    }
}
