import SwiftUI
import SwiftData

/// Phasen des Barcode-Scan-Flows. Eine Phase entspricht einem sichtbaren Sheet
/// oder einem Loading-State im Scanner-Tab / im Quick-Add-Sheet.
enum BarcodeScanPhase: Equatable {
    case idle               // Scanner geschlossen
    case scanning           // Live-Camera-View offen
    case looking            // Lokale Suche → OFF-Call läuft (Mini-Loading-Toast)
    case foundResult        // BarcodeResultView mit gefülltem OFFNutrientResult
    case foundLocal         // Lokales Product gefunden → direkt selektierbar
    case notFound           // Sheet mit OCR/Manuell-Fallback
    case error(String)      // Generischer Fehler (Netzwerk, Parse, etc.)
}

/// Identifiable-Wrapper für die Phasen, die in einem regulären Sheet (nicht
/// FullScreenCover und nicht Alert) präsentiert werden sollen. Wird in
/// `.sheet(item:)` als Single-Source-of-Truth verwendet — eliminiert die
/// Race-Condition zwischen mehreren separaten `.sheet(isPresented:)`-Modifiern.
struct BarcodePhaseSheetItem: Identifiable, Equatable {
    let phase: BarcodeScanPhase
    var id: String { String(describing: phase) }

    /// Liefert ein Sheet-Item, wenn die Phase via Sheet darzustellen ist —
    /// sonst nil (für .idle / .scanning / .error).
    static func from(_ phase: BarcodeScanPhase) -> BarcodePhaseSheetItem? {
        switch phase {
        case .looking, .foundResult, .foundLocal, .notFound:
            return BarcodePhaseSheetItem(phase: phase)
        default:
            return nil
        }
    }
}

/// Wo wurde der Scanner aufgerufen? Bestimmt die UX nach erfolgreichem Scan:
/// - `.scannerTab` → nur "Zur Bibliothek hinzufügen" (kein DiaryEntry)
/// - `.quickAdd`   → Gramm-Eingabe + "Loggen" → Product + DiaryEntry
enum BarcodeScanContext: Equatable {
    case scannerTab
    case quickAdd(date: Date, slot: MealSlot)
}

@Observable
@MainActor
final class BarcodeScannerViewModel {
    var phase: BarcodeScanPhase = .idle
    var context: BarcodeScanContext = .scannerTab

    /// Aktueller Scan — gesetzt nach erfolgreichem AVFoundation-Detect.
    var lastScannedCode: String? = nil

    /// Gefüllt nach erfolgreichem OFF-Call.
    var offResult: OFFNutrientResult? = nil

    /// Gefüllt, wenn der EAN lokal in der Bibliothek gefunden wurde
    /// (z. B. weil der User ihn früher schon einmal gescannt hat).
    var localMatch: Product? = nil

    // MARK: - Public API

    /// Wird vom `BarcodeScannerView` aufgerufen, sobald AVFoundation einen Code
    /// erkannt hat. Schliesst die Live-Camera und startet den Lookup-Flow.
    func handleScannedCode(_ code: String, allProducts: [Product]) async {
        // Reset previous results
        offResult = nil
        localMatch = nil
        lastScannedCode = code

        // 1. Lokaler Lookup (offline-first, kein API-Call, keine Duplikate)
        if let local = allProducts.first(where: { $0.barcode == code }) {
            localMatch = local
            phase = .foundLocal
            return
        }

        // 2. OFF-Lookup
        phase = .looking
        do {
            let result = try await OpenFoodFactsService.fetch(barcode: code)
            offResult = result
            phase = .foundResult
        } catch OpenFoodFactsError.notFound, OpenFoodFactsError.insufficientData {
            phase = .notFound
        } catch let e as OpenFoodFactsError {
            phase = .error(e.errorDescription ?? "Unbekannter Fehler")
        } catch {
            phase = .error("Unbekannter Fehler. Bitte nochmal versuchen.")
        }
    }

    /// Vom UI aus, um den Scanner zu öffnen.
    func startScanning(context: BarcodeScanContext) {
        self.context = context
        reset(keepingContext: true)
        phase = .scanning
    }

    /// Setzt alles zurück, optional unter Beibehalt des Contexts (für Re-Scans
    /// im gleichen Quick-Add-Flow).
    func reset(keepingContext: Bool = false) {
        phase = .idle
        offResult = nil
        localMatch = nil
        lastScannedCode = nil
        if !keepingContext { context = .scannerTab }
    }
}
