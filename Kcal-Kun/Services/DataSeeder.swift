import Foundation
import SwiftData

@MainActor
struct DataSeeder {
    private static let seededKey = "hasSeededPreloadedFoods"

    static func seedIfNeeded(context: ModelContext) async {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        do {
            try seed(context: context)
            UserDefaults.standard.set(true, forKey: seededKey)
        } catch {
            print("[DataSeeder] Fehler beim Seeden: \(error)")
        }
    }

    private static func seed(context: ModelContext) throws {
        guard let url = Bundle.main.url(forResource: "PreloadedFoods", withExtension: "json") else {
            throw DataSeederError.fileNotFound
        }
        let items = try JSONDecoder().decode([ProductSeed].self, from: Data(contentsOf: url))
        for item in items {
            context.insert(Product(
                name: item.name,
                brand: item.brand,
                kcalPer100g: item.kcalPer100g,
                proteinPer100g: item.proteinPer100g,
                fatPer100g: item.fatPer100g,
                carbsPer100g: item.carbsPer100g,
                fiberPer100g: item.fiberPer100g,
                sugarPer100g: item.sugarPer100g,
                saltPer100g: item.saltPer100g,
                servingSizeGrams: item.servingSizeGrams,
                source: .preloaded
            ))
        }
        try context.save()
    }
}

enum DataSeederError: LocalizedError {
    case fileNotFound
    var errorDescription: String? {
        "PreloadedFoods.json wurde im App-Bundle nicht gefunden."
    }
}

private struct ProductSeed: Decodable {
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
}
