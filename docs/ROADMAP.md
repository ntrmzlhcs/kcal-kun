# Development Roadmap

## Status-Legende

- `[ ]` Noch nicht begonnen
- `[~]` In Arbeit
- `[x]` Abgeschlossen

---

## Phase 1 — Foundation ✅

*Ziel: Lauffähiges Xcode-Projekt mit SwiftData-Stack und navigierbarer Tab-Bar.*

- [x] Xcode-Projekt erstellen (SwiftUI Lifecycle, iOS 18.0, Bundle ID setzen)
- [x] `Secrets.xcconfig` anlegen und in `.gitignore` eintragen
- [x] SwiftData `ModelContainer` konfigurieren (`Product`, `DiaryEntry`)
- [x] `DataSeeder` implementieren — lädt JSON bei erstem App-Start in SwiftData
- [x] Tab-Bar-Scaffold: Tabs **Tagebuch**, **Bibliothek**, **Scanner**, **Statistik**
- [x] `LibraryView`: Liste mit Favoriten + Meine Produkte, Suche, Swipe-to-Delete
- [x] Git-Repository initialisieren, `.xcodeproj` committed (kein xcodegen auto-run)

---

## Phase 2 — OCR Scanner ✅

*Ziel: Vollständiger Scan-Workflow von Foto bis gespeichertem Produkt.*

- [x] `ScannerView`: 3-State-UI (Idle / Loading / Error), Kamera-Sheet
- [x] `CameraPickerView`: `UIViewControllerRepresentable` mit `UIImagePickerController`
- [x] `GeminiService`: Multipart HTTP-Request (JPEG base64 + Prompt → JSON)
- [x] Response-Parsing: `NutritionScanResult` Decodable-Struct
- [x] `ScanConfirmationView`: vorausgefülltes, editierbares Formular (Name, Kcal, Makros)
- [x] Speichern: bestätigtes Produkt als `Product` (source: `.ocr`) in SwiftData
- [x] Fehler-States: Netz, kein Etikett erkannt, Server-Fehler
- [x] Bild auf max. 1024px skalieren vor dem API-Call
- [x] Modell: `gemini-2.5-flash`

---

## Phase 3 — Diary & Logging ✅

*Ziel: Vollständige Tagebuch-Funktionalität mit Tages-Totals.*

- [x] `DiaryView`: Datum-Navigation (Heute / Vor/Zurück-Pfeile) — DateNavigator ausserhalb der List
- [x] Vier Mahlzeit-Sektionen: Frühstück, Mittag, Abend, Snacks
- [x] Mehrere Einträge pro Mahlzeit-Slot möglich
- [x] `AddEntryView`: Zwei-Phasen-UX (Produkt wählen → Gramm eingeben mit Autofokus)
- [x] Live-Vorschau der Nährwerte beim Gramm-Eingeben
- [x] `DiaryEntry` in SwiftData speichern (Kcal/Makros bei Save-Zeit denormalisiert)
- [x] Tages-Zusammenfassung oben: Gesamt-Kcal als KcalSummaryCard
- [x] Swipe-to-Delete auf Tagebuch-Einträgen

---

## Phase 4 — Produktbibliothek & Nährwertdatenbank ✅

*Ziel: Vollständige Produktverwaltung + Schweizer Nährwertdatenbank.*

- [x] BLV-Datenbank als Bundle: `BLVFoods.json` (1190 generische Lebensmittel, naehrwertdaten.ch v7.0)
- [x] `DataSeeder` lädt BLV-Daten beim ersten Start, löscht alte 30er-Liste
- [x] `AddEntryView` Produktsuche: Favoriten / Meine Produkte / Datenbank (erscheint nur beim Suchen)
- [x] Favoriten-System: Stern-Button auf jedem Produkt, persistent in SwiftData
- [x] Source-Badge: Gescannt (blau) / Manuell (lila) in Produkt-Zeilen
- [x] `LibraryView`: Favoriten-Section + Meine Produkte-Section mit Swipe-to-Delete
- [x] BLV-Produkte nicht löschbar (nur via erneutes Seeden wiederherstellbar)
- [ ] `ProductDetailView`: Produkt-Werte nachträglich editieren
- [ ] Manueller Produkt-Eintrag ohne Scan (Formular direkt ausfüllen)

---

## Phase 5 — Statistik & UX Polish ✅ (teilweise)

*Ziel: App fühlt sich fertig und angenehm an.*

- [x] App Icon: `App_Icon_Draft.icon` via Xcode Icon Composer, gesetzt in General → App Icons
- [x] `StatsView` (4. Tab): Makro-Donut-Chart (Protein/KH/Fett/Ballaststoffe) mit DateNavigator
- [ ] Haptisches Feedback bei Speicher-Aktionen
- [ ] Keyboard-Avoidance in allen Formularen
- [ ] Accessibility Labels
- [ ] Testen unter verschiedenen Lichtbedingungen (Kamera-Performance)

---

## Phase 6 — Zukünftige Erweiterungen

*Kein festes Datum — nice-to-have nach MVP-Abschluss.*

- [ ] **Apple Health Integration** — Nährstoffdaten in HealthKit schreiben
- [ ] **Home Screen Widget** — Tagesbilanz auf dem Homescreen
- [ ] **iCloud Backup** — CloudKit-Sync mit SwiftData
- [ ] **Barcode-Scanner** — EAN-Code via AVFoundation → Open Food Facts API
- [ ] **Ziel-Kalorien** — Tages-Kalorienziel setzen und Fortschrittsanzeige
- [ ] **ProductDetailView** — Produkt-Werte nachträglich editieren

---

## Known Constraints & Risks

| Risiko | Massnahme |
|---|---|
| Gemini-Modellname kann sich ändern | `static let modelName` Konstante in `GeminiService` |
| SwiftData `#Predicate` unterstützt keine Enum-Vergleiche | In-Memory-Filterung mit `filter { $0.source == .preloaded }` |
| SwiftData Lightweight Migration bei neuen Feldern | Default-Wert direkt auf Property-Deklaration (nicht nur in `init`) |
| Sideloading-Zertifikat läuft nach 7 Tagen ab | Alle 7 Tage via Xcode neu deployen |
| `project.pbxproj` direkt editieren überschreibt Icon-Referenz | Nach jeder pbxproj-Änderung `grep App_Icon_Draft` prüfen, sofort committen |
