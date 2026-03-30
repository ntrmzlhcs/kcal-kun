# Architecture

## Übersicht

Kcal-Kun ist eine Single-Target iOS App ohne externe Dependencies (kein SPM, kein CocoaPods im MVP). Das Architekturmuster ist **MVVM**:

- **Views** enthalten ausschliesslich Layout-Code
- **ViewModels** (`@Observable`) besitzen State und Business Logic
- **SwiftData Models** sind die Single Source of Truth für alle persistenten Daten
- **Services** kapseln externe API-Calls (Gemini, BLV)

---

## Layer-Diagramm

```
┌─────────────────────────────────────────────────┐
│                    UI Layer                      │
│  DiaryView  ScannerView  LibraryView  DetailView │
└────────────────────┬────────────────────────────┘
                     │ @Observable ViewModels
┌────────────────────▼────────────────────────────┐
│                ViewModel Layer                   │
│  DiaryViewModel  ScannerViewModel  LibraryVM     │
└──────┬─────────────────────┬────────────────────┘
       │ SwiftData @Query     │ async/await
┌──────▼──────┐   ┌──────────▼──────────────────┐
│  SwiftData  │   │         Service Layer         │
│  (on-device)│   │  GeminiService  BLVApiService │
│  Product    │   │  DataSeeder                   │
│  DiaryEntry │   └──────────┬────────────────────┘
└─────────────┘              │ HTTPS
                   ┌─────────▼────────────────────┐
                   │       External APIs           │
                   │  Gemini API  naehrwertdaten.ch│
                   └──────────────────────────────┘
```

---

## Module-Aufbau

### Views/

| Datei | Beschreibung |
|---|---|
| `DiaryView.swift` | Tages-Tagebuch, nach Mahlzeit-Slots gruppiert, Datum-Navigation |
| `ScannerView.swift` | Kamera-Sheet, Lade-Zustand während Gemini-Call, Bestätigungsformular |
| `LibraryView.swift` | Durchsuchbare Liste aller gespeicherten Produkte |
| `ProductDetailView.swift` | Editierbarer Produkt-Steckbrief mit Source-Badge |
| `PortionCalculatorView.swift` | Eingebettet in Add-Entry-Sheet: Live-Vorschau der Nährwerte |
| `Components/` | Wiederverwendbare UI-Elemente (MacroSummaryRow, MealSlotHeader, …) |

### ViewModels/

| Datei | Verantwortlichkeit |
|---|---|
| `DiaryViewModel.swift` | Datums-Navigation, Mahlzeit-Gruppierung, Tages-Totals |
| `ScannerViewModel.swift` | Orchestriert: Foto-Capture → Gemini-Call → Parsed Result → User Confirmation |
| `LibraryViewModel.swift` | Live-Filterung der `@Query`-Resultate nach Suchbegriff |

### Services/

| Datei | Verantwortlichkeit |
|---|---|
| `GeminiService.swift` | Nimmt `UIImage`, sendet Multipart-Request an Gemini, gibt `NutritionLabel` zurück |
| `BLVApiService.swift` | Sucht Produkte auf naehrwertdaten.ch, gibt `[NutritionLabel]` zurück |
| `DataSeeder.swift` | Lädt `PreloadedFoods.json` beim ersten App-Start in SwiftData |

### Models/ (SwiftData)

Vollständige Schema-Dokumentation: [DATA_MODEL.md](DATA_MODEL.md)

---

## Datenfluss: Neues Produkt scannen

```
1. Nutzer tippt Kamera-Button in ScannerView
2. ScannerViewModel.capturePhoto() → UIImage
3. GeminiService.extractNutrition(from: image) → async
4. Gemini antwortet mit JSON → NutritionLabel struct
5. ScannerView zeigt vorausgefülltes Bestätigungsformular
6. Nutzer gibt Produktnamen ein, korrigiert ggf. Werte
7. ScannerViewModel.saveProduct() → Product in SwiftData
8. LibraryView aktualisiert sich automatisch via @Query
```

---

## Datenfluss: Tagebuch-Eintrag hinzufügen

```
1. Nutzer öffnet DiaryView → aktueller Tag
2. Tippt "+ Hinzufügen" in einem Mahlzeit-Slot
3. Add-Entry-Sheet öffnet sich
4. LibraryViewModel filtert Produkte live nach Tipp-Eingabe
5. Nutzer wählt Produkt, gibt Gramm oder Stückzahl ein
6. PortionCalculatorView zeigt Live-Vorschau: kcal = (kcalPer100g / 100) × grams
7. DiaryViewModel.addEntry() → DiaryEntry in SwiftData gespeichert
8. Tages-Totals werden neu berechnet und angezeigt
```

---

## Offline-Architektur

- Alle Daten leben lokal in SwiftData — kein Cloud-Sync, kein Backend
- **Gemini API** ist die einzige Netzwerk-Abhängigkeit
- Bei fehlendem Netz zeigt die App: *"Kein Internet. Werte manuell eingeben."* — Scanner funktioniert weiterhin mit manuellem Formular
- **BLV API** ist optionale Ergänzung; fehlt sie, ändert sich nichts am Kern-Workflow

---

## Sicherheit

| Aspekt | Massnahme |
|---|---|
| API-Key | Build-Zeit-Injection via `Secrets.xcconfig`, nie hardcoded, nie im Repo |
| Nutzer-Daten | Kein Account, keine Cloud-Sync, keine Telemetrie |
| Netzwerk | Einzige ausgehende Daten: Foto der Lebensmittelverpackung an Gemini (kein persönlicher Bezug) |
| Lokaler Speicher | SwiftData-Datenbank liegt im App-Container, nicht zugänglich für andere Apps |
