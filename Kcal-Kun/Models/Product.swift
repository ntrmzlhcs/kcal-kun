import Foundation
import SwiftData

@Model
final class Product {
    @Attribute(.unique) var id: UUID
    var name: String
    var brand: String?
    var kcalPer100g: Double
    var proteinPer100g: Double
    var fatPer100g: Double
    var carbsPer100g: Double
    var fiberPer100g: Double?
    var sugarPer100g: Double?
    var saltPer100g: Double?
    var servingSizeGrams: Double?
    var source: ProductSource
    var isFavorite: Bool = false
    var createdAt: Date
    var imageData: Data?
    /// EAN-13/UPC-Barcode für Produkte aus Open Food Facts oder vom User
    /// nachträglich erfasst (über OCR/Manuell-Fallback nach Not-Found-Scan).
    /// Ermöglicht beim erneuten Scannen denselben Eintrag wiederzuverwenden.
    var barcode: String?

    @Relationship(deleteRule: .nullify, inverse: \DiaryEntry.product)
    var entries: [DiaryEntry] = []

    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        kcalPer100g: Double,
        proteinPer100g: Double,
        fatPer100g: Double,
        carbsPer100g: Double,
        fiberPer100g: Double? = nil,
        sugarPer100g: Double? = nil,
        saltPer100g: Double? = nil,
        servingSizeGrams: Double? = nil,
        source: ProductSource,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        imageData: Data? = nil,
        barcode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g
        self.fatPer100g = fatPer100g
        self.carbsPer100g = carbsPer100g
        self.fiberPer100g = fiberPer100g
        self.sugarPer100g = sugarPer100g
        self.saltPer100g = saltPer100g
        self.servingSizeGrams = servingSizeGrams
        self.source = source
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.imageData = imageData
        self.barcode = barcode
    }
}
