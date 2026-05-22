import Foundation
import SwiftData
import os

/// Zentraler Logger für die App. Alle Module nutzen die statische Property
/// `Log.<kategorie>` (z. B. `Log.app`, `Log.network`, `Log.data`) für strukturiertes
/// `os.Logger`-Logging. Vorteile gegenüber `print()`:
/// - In Release-Builds optimiert (kein Performance-Overhead)
/// - Kategorisiert (filterbar in Console.app)
/// - Wird von Apple's Crash-Reports gesammelt
/// - Privacy-aware (sensible Werte werden mit `privacy: .private` markiert)
enum Log {
    private static let subsystem = "com.martin.kcal-kun"

    /// App-Lifecycle, Init, allgemeine Events
    static let app     = Logger(subsystem: subsystem, category: "App")
    /// SwiftData / Backup-Restore / Daten-Persistenz
    static let data    = Logger(subsystem: subsystem, category: "Data")
    /// Netzwerk-Calls (Gemini, OpenFoodFacts)
    static let network = Logger(subsystem: subsystem, category: "Network")
    /// HealthKit
    static let health  = Logger(subsystem: subsystem, category: "Health")
    /// UI-Layer (Sheet-Probleme, Coachmark)
    static let ui      = Logger(subsystem: subsystem, category: "UI")
}

extension ModelContext {
    /// Save-Wrapper, der Fehler nicht stillschweigend verschluckt — sondern
    /// strukturiert loggt. Gibt `true` zurück bei Erfolg, `false` bei Fehler.
    /// Die meisten Call-Sites brauchen den Boolean nicht — der Logger erfasst
    /// den Fehler bereits.
    ///
    /// Usage: `modelContext.saveOrLog("Diary-Eintrag hinzugefügt")`
    /// statt: `try? modelContext.save()`
    @discardableResult
    func saveOrLog(_ context: String = "save") -> Bool {
        do {
            try self.save()
            return true
        } catch {
            // Beschreibung des Save-Versuchs (z. B. „Diary-Eintrag hinzugefügt")
            // bleibt public — der Fehler-Description ebenfalls, da er typisch
            // keine sensiblen Daten enthält (Schema-Konflikt, Disk-Voll-Status).
            Log.data.error("SwiftData save failed [\(context, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
