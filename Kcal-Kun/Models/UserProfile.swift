import Foundation
import SwiftData

enum GoalType: String, Codable {
    case deficit  // Kaloriendefizit
    case surplus  // Massephase / Überschuss

    var displayName: String {
        switch self {
        case .deficit: "Kaloriendefizit"
        case .surplus: "Massephase"
        }
    }
}

enum DietStyle: String, Codable, CaseIterable {
    case balanced, highProtein, lowCarb, ketogenic, lowFat, mediterranean

    var label: String {
        switch self {
        case .balanced:      return "Ausgewogen"
        case .highProtein:   return "High Protein"
        case .lowCarb:       return "Low Carb"
        case .ketogenic:     return "Ketogen"
        case .lowFat:        return "Low Fat"
        case .mediterranean: return "Mediterran"
        }
    }

    var description: String {
        switch self {
        case .balanced:      return "Klassische Aufteilung nach DGE"
        case .highProtein:   return "Mehr Protein für Muskelaufbau"
        case .lowCarb:       return "Wenig Kohlenhydrate, mehr Fett"
        case .ketogenic:     return "Ketose: extrem wenig Kohlenhydrate"
        case .lowFat:        return "Herzgesund, kohlenhydratreich"
        case .mediterranean: return "Olivenöl, Fisch, Gemüse"
        }
    }

    var icon: String {
        switch self {
        case .balanced:      return "chart.pie.fill"
        case .highProtein:   return "dumbbell.fill"
        case .lowCarb:       return "leaf.fill"
        case .ketogenic:     return "bolt.fill"
        case .lowFat:        return "heart.fill"
        case .mediterranean: return "sun.max.fill"
        }
    }

    var proteinPct: Double {
        switch self {
        case .balanced:      return 0.30
        case .highProtein:   return 0.40
        case .lowCarb:       return 0.30
        case .ketogenic:     return 0.20
        case .lowFat:        return 0.20
        case .mediterranean: return 0.20
        }
    }

    var carbPct: Double {
        switch self {
        case .balanced:      return 0.40
        case .highProtein:   return 0.35
        case .lowCarb:       return 0.20
        case .ketogenic:     return 0.05
        case .lowFat:        return 0.60
        case .mediterranean: return 0.50
        }
    }

    var fatPct: Double { 1.0 - proteinPct - carbPct }

    var splitLabel: String {
        let p = Int((proteinPct * 100).rounded())
        let c = Int((carbPct * 100).rounded())
        let f = 100 - p - c  // always sums to 100
        return "P \(p)% · KH \(c)% · F \(f)%"
    }
}

@Model
final class UserProfile {
    var heightCm: Double = 175.0
    var weightKg: Double = 75.0
    var bmr: Double = 1800.0
    var kcalDelta: Double = 300.0   // Abweichung vom Grundumsatz (immer positiv)
    var goalType: GoalType = GoalType.deficit
    var dietStyle: DietStyle = DietStyle.balanced
    var photoData: Data?
    var bodyFatPercent: Double? = nil

    init(
        heightCm: Double = 175.0,
        weightKg: Double = 75.0,
        bmr: Double = 1800.0,
        kcalDelta: Double = 300.0,
        goalType: GoalType = .deficit,
        dietStyle: DietStyle = .balanced,
        photoData: Data? = nil,
        bodyFatPercent: Double? = nil
    ) {
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.bmr = bmr
        self.kcalDelta = kcalDelta
        self.goalType = goalType
        self.dietStyle = dietStyle
        self.photoData = photoData
        self.bodyFatPercent = bodyFatPercent
    }

    func proteinGoal(kcal: Double) -> Double { kcal * dietStyle.proteinPct / 4 }
    func carbGoal(kcal: Double) -> Double    { kcal * dietStyle.carbPct / 4 }
    func fatGoal(kcal: Double) -> Double     { kcal * dietStyle.fatPct / 9 }
}
