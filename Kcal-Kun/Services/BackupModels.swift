import Foundation

// MARK: - Root

struct BackupSnapshot: Codable {
    let schemaVersion: Int
    let appVersion: String
    let exportedAt: Date
    let deviceName: String
    let profile: UserProfileDTO?
    let products: [ProductDTO]
    let favoriteBLVProducts: [BLVFavoriteRef]
    let entries: [DiaryEntryDTO]
}

// MARK: - UserProfile

struct UserProfileDTO: Codable {
    let heightCm: Double
    let weightKg: Double
    let bmr: Double
    let kcalDelta: Double
    let goalType: String      // raw value
    let dietStyle: String     // raw value
    let bodyFatPercent: Double?
    let photoBase64: String?

    init(from p: UserProfile) {
        self.heightCm       = p.heightCm
        self.weightKg       = p.weightKg
        self.bmr            = p.bmr
        self.kcalDelta      = p.kcalDelta
        self.goalType       = p.goalType.rawValue
        self.dietStyle      = p.dietStyle.rawValue
        self.bodyFatPercent = p.bodyFatPercent
        self.photoBase64    = p.photoData?.base64EncodedString()
    }

    func applyTo(_ p: UserProfile) {
        p.heightCm       = heightCm
        p.weightKg       = weightKg
        p.bmr            = bmr
        p.kcalDelta      = kcalDelta
        p.goalType       = GoalType(rawValue: goalType) ?? .deficit
        p.dietStyle      = DietStyle(rawValue: dietStyle) ?? .balanced
        p.bodyFatPercent = bodyFatPercent
        if let b64 = photoBase64, let data = Data(base64Encoded: b64) {
            p.photoData = data
        } else {
            p.photoData = nil
        }
    }
}

// MARK: - Product

struct ProductDTO: Codable {
    let id: UUID
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
    let source: String        // raw value: "ocr" / "manual" / "dish" / "barcode" / …
    let isFavorite: Bool
    let createdAt: Date
    /// EAN/UPC-Barcode für Produkte aus Open Food Facts oder vom User mit
    /// Barcode-Fallback-Flow erfasst. Optional → Backwards-compatible: alte
    /// Backups ohne dieses Feld restorieren ohne Crash (default nil).
    let barcode: String?

    init(from p: Product) {
        self.id               = p.id
        self.name             = p.name
        self.brand            = p.brand
        self.kcalPer100g      = p.kcalPer100g
        self.proteinPer100g   = p.proteinPer100g
        self.fatPer100g       = p.fatPer100g
        self.carbsPer100g     = p.carbsPer100g
        self.fiberPer100g     = p.fiberPer100g
        self.sugarPer100g     = p.sugarPer100g
        self.saltPer100g      = p.saltPer100g
        self.servingSizeGrams = p.servingSizeGrams
        self.source           = p.source.rawValue
        self.isFavorite       = p.isFavorite
        self.createdAt        = p.createdAt
        self.barcode          = p.barcode
    }

    func applyTo(_ p: Product) {
        p.name             = name
        p.brand            = brand
        p.kcalPer100g      = kcalPer100g
        p.proteinPer100g   = proteinPer100g
        p.fatPer100g       = fatPer100g
        p.carbsPer100g     = carbsPer100g
        p.fiberPer100g     = fiberPer100g
        p.sugarPer100g     = sugarPer100g
        p.saltPer100g      = saltPer100g
        p.servingSizeGrams = servingSizeGrams
        // source bleibt — wir wollen ocr→ocr / manual→manual nicht ändern wenn schon korrekt
        if let s = ProductSource(rawValue: source) { p.source = s }
        p.isFavorite       = isFavorite
        p.barcode          = barcode
        // createdAt nicht überschreiben — das Original-Datum hat Priorität
    }

    func toModel() -> Product {
        Product(
            id: id,
            name: name,
            brand: brand,
            kcalPer100g: kcalPer100g,
            proteinPer100g: proteinPer100g,
            fatPer100g: fatPer100g,
            carbsPer100g: carbsPer100g,
            fiberPer100g: fiberPer100g,
            sugarPer100g: sugarPer100g,
            saltPer100g: saltPer100g,
            servingSizeGrams: servingSizeGrams,
            source: ProductSource(rawValue: source) ?? .manual,
            isFavorite: isFavorite,
            createdAt: createdAt,
            imageData: nil,
            barcode: barcode
        )
    }
}

// MARK: - BLV-Favorit-Referenz

struct BLVFavoriteRef: Codable {
    let id: UUID
    let name: String
}

// MARK: - DiaryEntry

struct DiaryEntryDTO: Codable {
    let id: UUID
    let date: Date
    let mealSlot: String           // MealSlot.rawValue ("Frühstück" / ...)
    let productId: UUID?
    let productName: String
    let grams: Double
    let unit: String
    let kcal: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let fiber: Double

    init(from e: DiaryEntry) {
        self.id          = e.id
        self.date        = e.date
        self.mealSlot    = e.mealSlot.rawValue
        self.productId   = e.product?.id
        self.productName = e.productName
        self.grams       = e.grams
        self.unit        = e.unit
        self.kcal        = e.kcal
        self.protein     = e.protein
        self.fat         = e.fat
        self.carbs       = e.carbs
        self.fiber       = e.fiber
    }

    /// Restore-Pfad: erzeugt eine neue Entry-Instanz. Versucht das Produkt zuerst
    /// per UUID, dann per Name (BLV oder eigene) zu finden — verhindert dass BLV-
    /// Produkte als `.manual`-Duplikate angelegt werden, wenn die BLV-DB zwischen
    /// Backup und Restore neu geseedet wurde (= neue UUIDs).
    func toModel(productLookup: [UUID: Product], allProducts: [Product]) -> DiaryEntry {
        let resolvedProduct: Product = {
            // Pfad 1: Direkter UUID-Match (best case)
            if let pid = productId, let p = productLookup[pid] { return p }

            // Pfad 2: Name-Match auf BLV-/Preloaded-Produkt (häufigster Fall nach Re-Seed)
            if !productName.isEmpty,
               let blvMatch = allProducts.first(where: {
                   $0.name == productName
                   && ($0.source == .preloaded || $0.source == .blvApi)
               }) {
                return blvMatch
            }

            // Pfad 3: Name-Match auf eigene Produkte (verhindert Duplikate bei
            // wiederholtem Restore desselben Backups)
            if !productName.isEmpty,
               let customMatch = allProducts.first(where: {
                   $0.name == productName
                   && ($0.source == .ocr || $0.source == .manual || $0.source == .dish)
               }) {
                return customMatch
            }

            // Pfad 4 (letzter Ausweg): Stub aus Denorm-Feldern erzeugen
            let factor = grams > 0 ? 100.0 / grams : 1
            return Product(
                name: productName.isEmpty ? "(unbekannt)" : productName,
                kcalPer100g: kcal * factor,
                proteinPer100g: protein * factor,
                fatPer100g: fat * factor,
                carbsPer100g: carbs * factor,
                fiberPer100g: fiber > 0 ? fiber * factor : nil,
                source: .manual,
                createdAt: date
            )
        }()
        let entry = DiaryEntry(
            id: id,
            date: date,
            mealSlot: MealSlot(rawValue: mealSlot) ?? .snacks,
            product: resolvedProduct,
            grams: grams,
            unit: unit
        )
        // Denormalisierte Werte direkt aus dem Backup übernehmen (nicht neu rechnen),
        // damit historische Werte exakt erhalten bleiben
        entry.productName = productName
        entry.kcal        = kcal
        entry.protein     = protein
        entry.fat         = fat
        entry.carbs       = carbs
        entry.fiber       = fiber
        return entry
    }
}
