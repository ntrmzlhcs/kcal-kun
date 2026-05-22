import Foundation
import SwiftData

@MainActor
struct DataSeeder {
    // Neue Key-Version erzwingt Re-Seed mit BLV-Datenbank v7
    private static let seededKey = "hasSeededBLVv7"

    static func seedIfNeeded(context: ModelContext) async {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        do {
            try reseedBLV(context: context)
            UserDefaults.standard.set(true, forKey: seededKey)
        } catch {
            Log.data.error("DataSeeder: Fehler beim Seeden: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func reseedBLV(context: ModelContext) throws {
        // Bestehende Preloaded-Einträge löschen (alte 30er-Liste)
        let all = try context.fetch(FetchDescriptor<Product>())
        for product in all where product.source == .preloaded {
            context.delete(product)
        }

        guard let url = Bundle.main.url(forResource: "BLVFoods", withExtension: "json") else {
            throw DataSeederError.fileNotFound
        }
        let items = try JSONDecoder().decode([ProductSeed].self, from: Data(contentsOf: url))
        for item in items {
            context.insert(Product(
                name: item.name,
                kcalPer100g: item.kcalPer100g,
                proteinPer100g: item.proteinPer100g,
                fatPer100g: item.fatPer100g,
                carbsPer100g: item.carbsPer100g,
                fiberPer100g: item.fiberPer100g,
                sugarPer100g: item.sugarPer100g,
                saltPer100g: item.saltPer100g,
                source: .preloaded
            ))
        }
        try context.save()
        Log.data.info("DataSeeder: \(items.count, privacy: .public) BLV-Produkte geladen.")
    }
}

enum DataSeederError: LocalizedError {
    case fileNotFound
    var errorDescription: String? { "BLVFoods.json wurde im App-Bundle nicht gefunden." }
}

private struct ProductSeed: Decodable {
    let name: String
    let kcalPer100g: Double
    let proteinPer100g: Double
    let fatPer100g: Double
    let carbsPer100g: Double
    let fiberPer100g: Double?
    let sugarPer100g: Double?
    let saltPer100g: Double?
}
