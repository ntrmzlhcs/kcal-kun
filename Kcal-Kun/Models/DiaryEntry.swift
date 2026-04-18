import Foundation
import SwiftData

@Model
final class DiaryEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var mealSlot: MealSlot
    var product: Product?
    var productName: String = ""
    var grams: Double
    var unit: String = "g"
    // Denormalisiert bei Save-Zeit — bleibt korrekt wenn Produkt-Werte später editiert werden
    var kcal: Double
    var protein: Double
    var fat: Double
    var carbs: Double
    var fiber: Double

    init(
        id: UUID = UUID(),
        date: Date,
        mealSlot: MealSlot,
        product: Product,
        grams: Double,
        unit: String = "g"
    ) {
        self.id          = id
        self.date        = date
        self.mealSlot    = mealSlot
        self.product     = product
        self.productName = product.name
        self.grams       = grams
        self.unit        = unit
        let factor = grams / 100.0
        self.kcal    = product.kcalPer100g    * factor
        self.protein = product.proteinPer100g * factor
        self.fat     = product.fatPer100g     * factor
        self.carbs   = product.carbsPer100g   * factor
        self.fiber   = (product.fiberPer100g ?? 0) * factor
    }
}
