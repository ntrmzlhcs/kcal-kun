import Foundation
import SwiftData
import UIKit

@MainActor
enum BackupService {

    // MARK: - Export

    static func export(context: ModelContext) throws -> Data {
        let products = try context.fetch(FetchDescriptor<Product>())
        let entries  = try context.fetch(FetchDescriptor<DiaryEntry>())
        let profile  = try context.fetch(FetchDescriptor<UserProfile>()).first

        // Eigene Produkte (ocr/manual/dish) komplett sichern
        let customProducts = products.filter {
            $0.source == .ocr || $0.source == .manual || $0.source == .dish
        }
        // BLV/Preloaded mit Favorit-Status nur als Referenz
        let blvFavorites = products.filter {
            ($0.source == .blvApi || $0.source == .preloaded) && $0.isFavorite
        }

        let snapshot = BackupSnapshot(
            schemaVersion: 1,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            exportedAt: Date(),
            deviceName: UIDevice.current.name,
            profile: profile.map { UserProfileDTO(from: $0) },
            products: customProducts.map { ProductDTO(from: $0) },
            favoriteBLVProducts: blvFavorites.map { BLVFavoriteRef(id: $0.id, name: $0.name) },
            entries: entries.map { DiaryEntryDTO(from: $0) }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    static func suggestedFileName() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmm"
        f.locale = Locale(identifier: "de_CH")
        return "KcalKun-Backup_\(f.string(from: Date())).json"
    }

    // MARK: - Preview (decode only)

    static func preview(data: Data) throws -> BackupSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snap: BackupSnapshot
        do {
            snap = try decoder.decode(BackupSnapshot.self, from: data)
        } catch {
            throw BackupError.invalidFormat
        }
        guard snap.schemaVersion == 1 else {
            throw BackupError.unsupportedVersion(snap.schemaVersion)
        }
        return snap
    }

    // MARK: - Apply (additive Merge)

    struct ImportSummary {
        let productsAdded: Int
        let productsUpdated: Int
        let entriesAdded: Int
        let entriesSkipped: Int
        let profileApplied: Bool
        let blvFavoritesMarked: Int
    }

    static func apply(_ snapshot: BackupSnapshot, context: ModelContext) throws -> ImportSummary {
        // 1. Profile — entweder erstellen oder existierenden updaten
        var profileApplied = false
        if let dto = snapshot.profile {
            let existing = try context.fetch(FetchDescriptor<UserProfile>()).first
            let target: UserProfile
            if let existing { target = existing } else {
                let p = UserProfile()
                context.insert(p)
                target = p
            }
            dto.applyTo(target)
            profileApplied = true
        }

        // 2. Custom Products (merge by UUID)
        let allProductsBefore = try context.fetch(FetchDescriptor<Product>())
        var byId = Dictionary(uniqueKeysWithValues: allProductsBefore.map { ($0.id, $0) })

        var productsAdded = 0
        var productsUpdated = 0
        for dto in snapshot.products {
            if let existing = byId[dto.id] {
                dto.applyTo(existing)
                productsUpdated += 1
            } else {
                let newProduct = dto.toModel()
                context.insert(newProduct)
                byId[newProduct.id] = newProduct
                productsAdded += 1
            }
        }

        // 3. BLV-Favoriten markieren
        var blvFavMarked = 0
        for ref in snapshot.favoriteBLVProducts {
            if let p = byId[ref.id] {
                if !p.isFavorite { p.isFavorite = true; blvFavMarked += 1 }
            } else if let p = allProductsBefore.first(where: {
                $0.name == ref.name && ($0.source == .blvApi || $0.source == .preloaded)
            }) {
                if !p.isFavorite { p.isFavorite = true; blvFavMarked += 1 }
            }
        }

        // 4. DiaryEntries (merge by UUID — additiv)
        let allEntries = try context.fetch(FetchDescriptor<DiaryEntry>())
        let entryIds = Set(allEntries.map(\.id))
        let productLookup = byId
        // allProductsNow inkl. neu eingefügter Custom-Products aus dem Backup —
        // ermöglicht den Name-Match-Fallback in DiaryEntryDTO.toModel
        let allProductsNow = Array(byId.values)

        var entriesAdded = 0
        var entriesSkipped = 0
        for dto in snapshot.entries {
            if entryIds.contains(dto.id) {
                entriesSkipped += 1
                continue
            }
            let entry = dto.toModel(productLookup: productLookup, allProducts: allProductsNow)
            context.insert(entry)
            entriesAdded += 1
        }

        try context.save()

        // Falls das Backup BLV-Duplikat-Stubs aus früheren Versionen enthält,
        // räum sie jetzt auf (mit force=true, da der AppStorage-Flag schon gesetzt
        // sein könnte). Hängt allfällige neu-eingespielte Stubs auf BLV-Originale um.
        ProductCleanupService.cleanupBLVStubs(context: context, force: true)

        return ImportSummary(
            productsAdded: productsAdded,
            productsUpdated: productsUpdated,
            entriesAdded: entriesAdded,
            entriesSkipped: entriesSkipped,
            profileApplied: profileApplied,
            blvFavoritesMarked: blvFavMarked
        )
    }
}

// MARK: - Fehler

enum BackupError: LocalizedError {
    case unsupportedVersion(Int)
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v):
            return "Backup-Version \(v) wird nicht unterstützt. Bitte App aktualisieren."
        case .invalidFormat:
            return "Datei ist kein gültiges Kcal-Kun-Backup."
        }
    }
}
