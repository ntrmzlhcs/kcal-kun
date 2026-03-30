import Foundation

enum MealSlot: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Frühstück"
    case lunch     = "Mittag"
    case dinner    = "Abend"
    case snacks    = "Snacks"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch:     "sun.max"
        case .dinner:    "moon"
        case .snacks:    "fork.knife"
        }
    }
}
