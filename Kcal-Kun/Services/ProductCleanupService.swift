import Foundation
import SwiftData

/// One-shot Cleanup für duplizierte BLV-Produkte, die durch alte Backup-Restore-
/// Pfade als `.manual`-Stubs in der Library landeten. Läuft genau einmal beim
/// App-Start (AppStorage-Flag).
@MainActor
enum ProductCleanupService {
    /// Bumpen wenn weitere Cleanup-Iterationen nötig werden (V2, V3, …).
    private static let cleanupKey = "hasCleanedDuplicateBLVStubsV1"

    /// Findet `.manual`/`.ocr`/`.dish`-Stubs, die EXAKT einem BLV-/Preloaded-Produkt
    /// gleichen Namens entsprechen, hängt deren DiaryEntries auf das BLV-Original um
    /// und löscht die Stubs.
    ///
    /// - Parameter force: Wenn `true`, wird der AppStorage-Flag ignoriert und der
    ///   Cleanup ausgeführt — z.B. nach einem Backup-Restore, der theoretisch
    ///   neue Stubs eingebracht haben könnte.
    static func cleanupBLVStubs(context: ModelContext, force: Bool = false) {
        let defaults = UserDefaults.standard
        if !force {
            guard !defaults.bool(forKey: cleanupKey) else { return }
        }

        do {
            let all = try context.fetch(FetchDescriptor<Product>())

            // BLV-/Preloaded-Produkte by name → Original
            // (Bei Dupes innerhalb der BLV-DB nehmen wir das erste — sollte
            //  normalerweise nicht vorkommen, defensive aber.)
            var blvByName: [String: Product] = [:]
            for product in all where product.source == .preloaded || product.source == .blvApi {
                if blvByName[product.name] == nil {
                    blvByName[product.name] = product
                }
            }

            // Stubs identifizieren — eigene Produkte (.manual/.ocr/.dish) deren
            // Name exakt einem BLV-Produkt entspricht
            let stubs = all.filter {
                ($0.source == .manual || $0.source == .ocr || $0.source == .dish)
                && blvByName[$0.name] != nil
            }

            guard !stubs.isEmpty else {
                defaults.set(true, forKey: cleanupKey)
                Log.data.info("ProductCleanup: keine Duplikate, Flag gesetzt")
                return
            }

            let stubIds = Set(stubs.map(\.id))

            // DiaryEntries auf BLV-Originale umhängen
            let entries = try context.fetch(FetchDescriptor<DiaryEntry>())
            var relinkedCount = 0
            for entry in entries {
                guard let p = entry.product,
                      stubIds.contains(p.id),
                      let blvOriginal = blvByName[p.name] else { continue }
                entry.product = blvOriginal
                relinkedCount += 1
            }

            // Stubs löschen
            for stub in stubs {
                context.delete(stub)
            }

            try context.save()
            Log.data.info("ProductCleanup: re-linked \(relinkedCount, privacy: .public) entries, \(stubs.count, privacy: .public) Stubs gelöscht")
            defaults.set(true, forKey: cleanupKey)
        } catch {
            Log.data.error("ProductCleanup Fehler: \(error.localizedDescription, privacy: .public)")
        }
    }
}
