# Development Roadmap

## Status-Legende

- `[ ]` Noch nicht begonnen
- `[~]` In Arbeit
- `[x]` Abgeschlossen

---

## Phase 1 — Foundation

*Ziel: Lauffähiges Xcode-Projekt mit SwiftData-Stack und navigierbarer Tab-Bar.*

- [ ] Xcode-Projekt erstellen (SwiftUI Lifecycle, iOS 18.0, Bundle ID setzen)
- [ ] `Secrets.xcconfig` anlegen und in `.gitignore` eintragen
- [ ] SwiftData `ModelContainer` konfigurieren (`Product`, `DiaryEntry`)
- [ ] `PreloadedFoods.json` erstellen (~30 Schweizer Frischprodukte)
- [ ] `DataSeeder` implementieren — lädt JSON bei erstem App-Start in SwiftData
- [ ] Tab-Bar-Scaffold: Tabs **Tagebuch**, **Bibliothek**, **Scanner**
- [ ] `LibraryView` (Skeleton): Liste aller Produkte via `@Query`, nach Name sortiert
- [ ] Git-Repository initialisieren, ersten Commit erstellen

---

## Phase 2 — OCR Scanner

*Ziel: Vollständiger Scan-Workflow von Foto bis gespeichertem Produkt.*

- [ ] `ScannerView`: Kamera-Sheet mit `UIImagePickerController` oder `PhotosPicker`
- [ ] `GeminiService`: HTTP-Request aufbauen (base64 JPEG + Prompt → JSON-Response)
- [ ] Response-Parsing: `GeminiNutritionResponse` Decodable-Struct
- [ ] Bestätigungsformular: vorausgefüllte, editierbare Felder (Name, Kcal, Protein, Fett, KH)
- [ ] Speichern: bestätigtes Produkt als `Product` in SwiftData anlegen
- [ ] Fehler-States implementieren:
  - [ ] Kein Internet → Hinweis "Werte manuell eingeben"
  - [ ] Kein Nährwerttisch erkannt → Hinweis + Retry-Button
  - [ ] Malformed JSON → Fallback auf manuelle Eingabe
- [ ] Bild auf max. 1024px skalieren vor dem API-Call

---

## Phase 3 — Diary & Logging

*Ziel: Vollständige Tagebuch-Funktionalität mit Tages-Totals.*

- [ ] `DiaryView`: Datum-Navigation (Heute / Vor/Zurück-Pfeile)
- [ ] Vier Mahlzeit-Sektionen: Frühstück, Mittag, Abend, Snacks
- [ ] "Eintrag hinzufügen"-Sheet: Produkt-Suche + Gramm/Stück-Eingabe
- [ ] `PortionCalculatorView`: Live-Vorschau von Kcal/Makros beim Tippen
- [ ] `DiaryEntry` in SwiftData speichern (Kcal/Makros bei Save-Zeit berechnen)
- [ ] Tages-Zusammenfassung (oben oder unten): Gesamt-Kcal, Protein, Fett, KH
- [ ] Swipe-to-Delete auf Tagebuch-Einträgen

---

## Phase 4 — Library & BLV API

*Ziel: Vollständige Produktverwaltung + Schweizer Nährwertdatenbank.*

- [ ] Produkt-Suche in `LibraryView` mit Live-Filterung (`@Query` + `#Predicate`)
- [ ] `ProductDetailView`: Produkt-Werte editieren
- [ ] Produkt löschen (mit Bestätigungs-Dialog; Warnung wenn Tagebuch-Einträge vorhanden)
- [ ] `BLVApiService`: Suche auf naehrwertdaten.ch nach Produktname
- [ ] Import-Flow: BLV-Suchergebnis in persönliche Bibliothek übernehmen
- [ ] Source-Badge auf Produktkarte: OCR / BLV / Vorgeladen / Manuell
- [ ] Manueller Produkt-Eintrag ohne Scan (Formular direkt ausfüllen)

---

## Phase 5 — UX Polish

*Ziel: App fühlt sich fertig und angenehm an.*

- [ ] App Icon und Launch Screen
- [ ] Haptisches Feedback bei Speicher-Aktionen (`UIImpactFeedbackGenerator`)
- [ ] Empty States: Illustrationen/Texte für leeres Tagebuch und leere Bibliothek
- [ ] Keyboard-Avoidance in allen Formularen
- [ ] Accessibility Labels für alle interaktiven Elemente
- [ ] Lokalisierung: Primärsprache Deutsch (Schweiz `de_CH`), sekundär Englisch
- [ ] Testen unter verschiedenen Lichtbedingungen (Kamera-Performance)

---

## Phase 6 — Zukünftige Erweiterungen

*Kein festes Datum — nice-to-have nach MVP-Abschluss.*

- [ ] **Apple Health Integration** — Nährstoffdaten in HealthKit schreiben
- [ ] **Home Screen Widget** — Tagesbilanz (Kcal verbraucht / Ziel) auf dem Homescreen
- [ ] **iCloud Backup** — CloudKit-Sync mit SwiftData für Gerätewechsel
- [ ] **Barcode-Scanner** — Alternativer Input via EAN-Code (Open Food Facts API)
- [ ] **Ziel-Kalorien** — Tages-Kalorienziel setzen und Fortschrittsanzeige

---

## Known Constraints & Risks

| Risiko | Massnahme |
|---|---|
| Gemini Preview-Endpoint kann sich ändern | Endpoint-URL als Konstante in `GeminiService` — bei Modell-Updates einmalig anpassen |
| naehrwertdaten.ch ohne SLA | Nur als Best-Effort behandeln; App funktioniert vollständig ohne diese API |
| SwiftData-Schema-Änderungen nach Phase 1 | Vor jeder Breaking Change `VersionedSchema` + `SchemaMigrationPlan` definieren |
| Sideloading-Zertifikat läuft nach 7 Tagen ab | Alle 7 Tage via Xcode neu deployen (kostenlose Apple ID) |
