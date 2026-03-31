# Architecture

## Übersicht

Kcal-Kun ist eine Single-Target iOS App ohne externe Dependencies. Das Architekturmuster ist **MVVM-light**: einfache Views nutzen `@Query` direkt, komplexere Views (Scanner) haben ein eigenes `@Observable` ViewModel.

---

## Layer-Diagramm

```
┌─────────────────────────────────────────────────────────┐
│                        UI Layer                          │
│  DiaryView  LibraryView  ScannerView  StatsView          │
│  AddEntryView  ScanConfirmationView  CameraPickerView    │
└────────────────────────┬────────────────────────────────┘
                         │ @Observable ViewModel (nur Scanner)
┌────────────────────────▼────────────────────────────────┐
│                   ViewModel Layer                        │
│  ScannerViewModel  (DiaryView/LibraryView: @Query direkt)│
└──────┬──────────────────────┬───────────────────────────┘
       │ SwiftData @Query      │ async/await
┌──────▼──────┐   ┌───────────▼─────────────────────────┐
│  SwiftData  │   │           Service Layer               │
│  (on-device)│   │  GeminiService   DataSeeder           │
│  Product    │   └──────────┬──────────────────────────┘
│  DiaryEntry │              │ HTTPS (nur Gemini)
└─────────────┘   ┌──────────▼──────────────────────────┐
                  │         External APIs                 │
                  │  Gemini API (gemini-2.5-flash)        │
                  └─────────────────────────────────────┘
```

*BLV-Daten sind als `BLVFoods.json` gebundelt — kein Live-API-Call nötig.*

---

## Dateistruktur

```
Kcal-Kun/
├── KcalKunApp.swift          ← ModelContainer + DataSeeder.seedIfNeeded
├── MainTabView.swift         ← 4 Tabs: Tagebuch / Bibliothek / Scanner / Statistik
├── Models/
│   ├── Product.swift         ← @Model, isFavorite, source, Nährwerte per 100g
│   ├── DiaryEntry.swift      ← @Model, denormalisierte Nährwerte inkl. fiber
│   ├── MealSlot.swift        ← Enum: Frühstück / Mittag / Abend / Snacks
│   └── ProductSource.swift   ← Enum: ocr / blvApi / preloaded / manual
├── Views/
│   ├── DiaryView.swift       ← DateNavigator (ausserhalb List) + 4 MealSlot-Sections
│   ├── LibraryView.swift     ← Favoriten + Meine Produkte, Swipe-to-Delete
│   ├── StatsView.swift       ← Makro-Donut-Chart (SectorMark), DateNavigator
│   └── Components/
│       ├── AddEntryView.swift       ← 2-Phasen: Produktwahl → Gramm (autofokus)
│       ├── CameraPickerView.swift   ← UIViewControllerRepresentable
│       └── ScanConfirmationView.swift
├── ViewModels/
│   └── ScannerViewModel.swift  ← @Observable @MainActor
├── Services/
│   ├── GeminiService.swift   ← JPEG → Gemini REST → NutritionScanResult
│   └── DataSeeder.swift      ← BLVFoods.json → SwiftData (key: hasSeededBLVv7)
└── Resources/
    ├── BLVFoods.json         ← 1190 generische CH-Lebensmittel (BLV v7.0)
    └── Assets.xcassets/
```

---

## Wichtige Design-Entscheidungen

### DateNavigator muss ausserhalb von List stehen
List-Rows fangen Gesten ab — Buttons in List-Rows funktionieren nicht zuverlässig. `DateNavigator` immer in einem `VStack` **über** der `List` platzieren.

### SwiftData #Predicate und Enums
`#Predicate` unterstützt weder `$0.source == .preloaded` noch `$0.source.rawValue == "preloaded"`. Enum-Filterung immer nach dem Fetch in-memory (`filter { $0.source == .preloaded }`).

### BLV-Datenbank als Bundle statt Live-API
Die naehrwertdaten.ch-Datenbank enthält generische Lebensmittel (kein Markenprodukte). Als gebündeltes JSON geladen statt Live-API — konsistent mit Offline-First-Philosophie.

### isFavorite Lightweight Migration
Neue Bool-Properties in SwiftData brauchen den Default-Wert **auf der Property-Deklaration** (`var isFavorite: Bool = false`), nicht nur im `init`.

---

## Datenfluss: Produkt scannen

```
1. ScannerView → Kamera-Button → CameraPickerView (UIImagePickerController)
2. ScannerViewModel.processImage(UIImage)
   → skalieren auf max. 1024px
   → JPEG-Data erstellen
3. GeminiService.extractNutrition(from: jpegData) async throws
   → POST generativelanguage.googleapis.com (multipart)
   → JSON parsen → NutritionScanResult
4. ScannerView zeigt ScanConfirmationView (Sheet)
5. Nutzer bestätigt → ScanConfirmationView erstellt Product (source: .ocr)
6. modelContext.insert(product) → LibraryView aktualisiert via @Query
```

---

## Datenfluss: Tagebuch-Eintrag hinzufügen

```
1. DiaryView → "+" Button im MealSlot → AddEntryView (Sheet)
2. Phase 1: Produktsuche
   - Favoriten (isFavorite == true)
   - Meine Produkte (source: .ocr oder .manual)
   - Datenbank (source: .preloaded) — nur sichtbar wenn Suchtext vorhanden
3. Phase 2: Gramm eingeben (autofokus, decimalPad)
   - Live-Vorschau: kcal/P/F/KH für eingegebene Menge
4. "Hinzufügen" → DiaryEntry(product, grams) → modelContext.insert
   → Nährwerte denormalisiert berechnet und gespeichert
```

---

## Offline-Architektur

- Alle Daten lokal in SwiftData — kein Cloud-Sync, kein Backend
- **Einzige Netzwerkabhängigkeit:** Gemini API (OCR-Scan)
- BLV-Lebensmitteldatenbank ist vollständig offline im App-Bundle
- Bei fehlendem Netz: Scanner zeigt Fehler-State mit "Manuell eingeben"-Option

---

## Sicherheit

| Aspekt | Massnahme |
|---|---|
| API-Key | `Secrets.xcconfig` (gitignored), Build-Zeit-Injection via `$(GEMINI_API_KEY)` |
| Nutzerdaten | Kein Account, keine Cloud, keine Telemetrie |
| Netzwerk | Nur Foto der Lebensmittelverpackung geht an Gemini — kein persönlicher Bezug |
