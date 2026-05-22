import SwiftUI

/// Konstanten für die Coachmark-Tour. Während die Tour aktiv ist, rendern die
/// betroffenen Views diese Demo-Daten anstelle echter User-Daten — so demonstriert
/// die Tour zuverlässig die Features, egal ob die App leer ist oder voller Daten.
enum CoachmarkDemoData {

    // MARK: - HeroKcalCard / MacroChips (Step 2, 3)

    static let dailyConsumed: Double = 1420
    static let dailyTarget:   Double = 2100
    static let workoutKcal:   Double = 180
    static let dailyProtein:  Double = 75
    static let dailyFat:      Double = 42
    static let dailyCarbs:    Double = 180
    static let dailyFiber:    Double = 25

    // MARK: - Diary Meal-Entries (Step 2, 3, 4 — Diary-Tab sichtbar)

    /// Lightweight Demo-Eintrag für die Meal-Slots in DiaryView. Kein SwiftData-Objekt,
    /// nur Anzeige-Daten — vermeidet Context-Konflikte mit echten DiaryEntries.
    struct DemoDiaryEntry: Identifiable {
        let id = UUID()
        let mealSlot: MealSlot
        let productName: String
        let grams: Double
        let unit: String
        let kcal: Double
        let protein: Double
        let fat: Double
        let carbs: Double
        let fiber: Double
    }

    /// Demo-Frühstück: klassisches deutsches Müsli-Frühstück.
    /// Andere Slots bleiben im Demo bewusst leer → demonstriert nebenbei den
    /// „Schläft noch"-Empty-State und vermeidet, dass echte User-Daten durchschimmern.
    static let demoDiaryEntries: [DemoDiaryEntry] = [
        .init(mealSlot: .breakfast, productName: "Haferflocken",
              grams: 50,  unit: "g",
              kcal: 185, protein: 6.5, fat: 3.0, carbs: 30, fiber: 5),
        .init(mealSlot: .breakfast, productName: "Magerquark",
              grams: 150, unit: "g",
              kcal: 105, protein: 19,  fat: 0.5, carbs: 6,  fiber: 0),
        .init(mealSlot: .breakfast, productName: "Banane",
              grams: 120, unit: "g",
              kcal: 107, protein: 1.3, fat: 0.4, carbs: 27, fiber: 3),
        .init(mealSlot: .breakfast, productName: "Honig",
              grams: 10,  unit: "g",
              kcal: 32,  protein: 0,   fat: 0,   carbs: 8,  fiber: 0),
    ]

    // MARK: - Library Favoriten (Step 5)

    struct DemoFavorite: Identifiable {
        let id = UUID()
        let name: String
        let kcalPer100g: Int
        let proteinPer100g: Double
    }
    static let demoFavorites: [DemoFavorite] = [
        .init(name: "Apfel",        kcalPer100g: 52,  proteinPer100g: 0.3),
        .init(name: "Vollkornbrot", kcalPer100g: 247, proteinPer100g: 8.5),
        .init(name: "Magerquark",   kcalPer100g: 70,  proteinPer100g: 12.5),
    ]

    // MARK: - Library „Meine Produkte" (Step 5)

    /// Demo-Items für die zweite Library-Section. Mix aus drei `source`-Typen, damit
    /// gleichzeitig das Source-Tag-Feature demonstriert wird.
    struct DemoMyProduct: Identifiable {
        let id = UUID()
        let name: String
        let kcalPer100g: Int
        let proteinPer100g: Double
        let source: ProductSource
    }

    static let demoMyProducts: [DemoMyProduct] = [
        .init(name: "Vollkornbrot Migros",  kcalPer100g: 247, proteinPer100g: 8.5,  source: .ocr),
        .init(name: "Eigene Müslimischung", kcalPer100g: 380, proteinPer100g: 11.0, source: .manual),
        .init(name: "Spaghetti Carbonara",  kcalPer100g: 145, proteinPer100g: 6.0,  source: .dish),
    ]

    // MARK: - WeeklyKcalChart (Step 8)

    /// 7-Tage-Verlauf (älteste Position = vor 6 Tagen, letzte Position = heute).
    static let weeklyKcals: [Double] = [1850, 2100, 1620, 2230, 1980, 1750, 1420]

    /// Fallback-Tagesziel falls kein Profil vorhanden — sorgt dafür, dass die
    /// RuleMark im Wochenchart sinnvoll relativ zu den Balken sitzt.
    static let fallbackDailyTarget: Double = 2000

    // MARK: - Weight Chart (Step 9)

    /// 30 Tage Demo-Gewicht: gleichmässiger Abwärtstrend von 75.5 → 74.0 kg
    /// mit kleinen täglichen Schwankungen — wirkt wie echte HealthKit-Daten.
    /// Format matched mit `HealthKitService.fetchRollingAverageWeights` → `[Date: Double]`.
    static var demoRollingWeights: [Date: Double] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var result: [Date: Double] = [:]
        for offset in 0..<30 {
            guard let date = cal.date(byAdding: .day, value: -(29 - offset), to: today) else { continue }
            let progress = Double(offset) / 29.0       // 0 (vor 30 Tagen) → 1 (heute)
            let baseWeight = 75.5 - 1.5 * progress      // 75.5 → 74.0
            let jitter = sin(Double(offset) * 0.6) * 0.15
            result[date] = baseWeight + jitter
        }
        return result
    }

    // MARK: - KI-Analyse JSON (Step 10)

    /// JSON-Format matched mit dem internen AnalysisResult-Schema von StatsView's
    /// NutritionAnalysisCard (sections mit title/highlight/body und optional meals).
    static let demoAnalysisJSON: String = """
    {
      "sections": [
        {
          "id": "overview",
          "title": "Übersicht",
          "highlight": "Defizit gut eingehalten",
          "body": "In den letzten 30 Tagen warst du im Schnitt 320 kcal unter deinem Tagesziel — das entspricht ~1 kg Gewichtsverlust pro Monat, solider Fortschritt."
        },
        {
          "id": "macros",
          "title": "Makros",
          "highlight": "Protein knapp unter Ziel",
          "body": "Du erreichst dein Protein-Ziel an 22 von 30 Tagen. Vorschlag: morgens Magerquark oder mittags Hähnchen ergänzen, um die Protein-Synthese im Defizit zu unterstützen."
        },
        {
          "id": "patterns",
          "title": "Muster",
          "body": "Am Wochenende isst du im Schnitt 280 kcal mehr — meist abends. Wenn du diese Tage etwas reduzieren willst, könnte ein leichteres Abendessen helfen."
        },
        {
          "id": "suggestions",
          "title": "Mahlzeit-Ideen",
          "meals": [
            {"name": "Haferflocken mit Magerquark", "portions": "1 Portion", "macros": "350 kcal · 25g P"},
            {"name": "Hähnchensalat mit Quinoa", "portions": "1 Portion", "macros": "480 kcal · 38g P"},
            {"name": "Lachs mit Süsskartoffel", "portions": "1 Portion", "macros": "520 kcal · 32g P"}
          ]
        }
      ]
    }
    """
}

// MARK: - EnvironmentKey

private struct CoachmarkDemoModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// Signalisiert, dass die Coachmark-Tour gerade aktiv ist und Tour-relevante
    /// Views ihre Demo-Daten anstelle echter Daten rendern sollen.
    var coachmarkDemoMode: Bool {
        get { self[CoachmarkDemoModeKey.self] }
        set { self[CoachmarkDemoModeKey.self] = newValue }
    }
}
