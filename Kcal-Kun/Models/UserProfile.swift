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

@Model
final class UserProfile {
    var heightCm: Double = 175.0
    var weightKg: Double = 75.0
    var bmr: Double = 1800.0
    var kcalDelta: Double = 300.0   // Abweichung vom Grundumsatz (immer positiv)
    var goalType: GoalType = GoalType.deficit
    var photoData: Data?

    init(
        heightCm: Double = 175.0,
        weightKg: Double = 75.0,
        bmr: Double = 1800.0,
        kcalDelta: Double = 300.0,
        goalType: GoalType = .deficit,
        photoData: Data? = nil
    ) {
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.bmr = bmr
        self.kcalDelta = kcalDelta
        self.goalType = goalType
        self.photoData = photoData
    }
}
