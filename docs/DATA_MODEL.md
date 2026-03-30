# Data Model

## Übersicht

SwiftData ist die einzige Persistenzschicht. Alle Modelle verwenden das `@Model`-Makro. Kein CloudKit-Sync im MVP.

```
ModelContainer
├── Product          (Produktbibliothek)
└── DiaryEntry       (Tagebucheinträge)
```

---

## Product

Repräsentiert ein Lebensmittel in der persönlichen Bibliothek. Einmal gespeichert, beliebig oft im Tagebuch wiederverwendbar.

| Property | Typ | Pflichtfeld | Beschreibung |
|---|---|---|---|
| `id` | `UUID` | Ja | Auto-generiert; `@Attribute(.unique)` |
| `name` | `String` | Ja | Vom Nutzer gewählter Anzeigename (z. B. "Mein Lieblingsjoghurt") |
| `brand` | `String?` | Nein | Markenname; wird von BLV API befüllt wenn verfügbar |
| `kcalPer100g` | `Double` | Ja | Kalorien pro 100g |
| `proteinPer100g` | `Double` | Ja | Protein pro 100g |
| `fatPer100g` | `Double` | Ja | Fett pro 100g |
| `carbsPer100g` | `Double` | Ja | Kohlenhydrate pro 100g |
| `fiberPer100g` | `Double?` | Nein | Ballaststoffe pro 100g |
| `sugarPer100g` | `Double?` | Nein | Davon Zucker pro 100g |
| `saltPer100g` | `Double?` | Nein | Salz pro 100g |
| `servingSizeGrams` | `Double?` | Nein | Portionsgrösse in Gramm (z. B. 1 Ei = 60g) — aktiviert Stückzahl-Eingabe |
| `source` | `ProductSource` | Ja | Herkunft des Eintrags (siehe Enum unten) |
| `createdAt` | `Date` | Ja | Automatisch gesetzt beim Anlegen |
| `imageData` | `Data?` | Nein | Thumbnail des Etikett-Fotos (optional gespeichert) |
| `entries` | `[DiaryEntry]` | — | Inverse Relationship zu DiaryEntry |

---

## DiaryEntry

Ein einzelner Logg-Eintrag im Tagebuch: Produkt + Menge + berechnete Nährwerte.

| Property | Typ | Pflichtfeld | Beschreibung |
|---|---|---|---|
| `id` | `UUID` | Ja | Auto-generiert |
| `date` | `Date` | Ja | Tag des Eintrags (Zeit-Komponente wird für Gruppierung ignoriert) |
| `mealSlot` | `MealSlot` | Ja | Mahlzeit-Slot (Frühstück, Mittag, Abend, Snacks) |
| `product` | `Product` | Ja | Beziehung zum Produkt |
| `grams` | `Double` | Ja | Tatsächlich konsumierte Menge in Gramm |
| `kcal` | `Double` | Ja | Berechnet beim Speichern: `(product.kcalPer100g / 100) * grams` |
| `protein` | `Double` | Ja | Berechnet beim Speichern (gleiches Muster) |
| `fat` | `Double` | Ja | Berechnet beim Speichern |
| `carbs` | `Double` | Ja | Berechnet beim Speichern |

### Warum Denormalisierung?

Kcal, Protein, Fett und KH werden beim Speichern einmalig berechnet und direkt auf `DiaryEntry` geschrieben — nicht on-the-fly aus `Product` abgeleitet. Das hat einen wichtigen Grund: **Wenn der Nutzer die Werte eines Produkts später korrigiert, bleiben historische Tagebuch-Einträge unverändert.** Das entspricht dem erwarteten Verhalten eines Lebensmittel-Tagebuchs.

---

## Supporting Enums

```swift
enum MealSlot: String, Codable, CaseIterable {
    case breakfast = "Frühstück"
    case lunch     = "Mittag"
    case dinner    = "Abend"
    case snacks    = "Snacks"
}

enum ProductSource: String, Codable {
    case ocr        // Via Kamera + Gemini OCR gescannt
    case blvApi     // Von naehrwertdaten.ch importiert
    case preloaded  // In PreloadedFoods.json vorinstalliert
    case manual     // Manuell vom Nutzer eingegeben
}
```

---

## Wichtige Queries

```swift
// Alle Produkte alphabetisch
@Query(sort: \Product.name) var products: [Product]

// Produkte nach Suchbegriff filtern (LibraryViewModel)
@Query(filter: #Predicate<Product> { $0.name.localizedStandardContains(searchText) },
       sort: \Product.name)
var filteredProducts: [Product]

// Tagebuch-Einträge für einen bestimmten Tag
let startOfDay = Calendar.current.startOfDay(for: date)
let endOfDay   = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
@Query(filter: #Predicate<DiaryEntry> { $0.date >= startOfDay && $0.date < endOfDay })
var entriesForDay: [DiaryEntry]

// Tages-Totals (in-memory nach Query)
let totalKcal = entriesForDay.reduce(0) { $0 + $1.kcal }
```

---

## Preloaded Data

- **Datei:** `PreloadedFoods.json` (in der App gebundelt)
- **Inhalt:** ~30 häufige Schweizer Frischprodukte ohne Etikett
- **Quellen:** BLV-Nährwertdatenbank (naehrwertdaten.ch)
- **Laden:** `DataSeeder` schreibt die Daten beim ersten App-Start in SwiftData
- **Beispiel-Einträge:** Brokkoli, Apfel (Granny Smith), Ei (Grösse M), Olivenöl, Vollmilch, Hühnerbrust, Lachs, Basmati-Reis (gekocht), Weissbrot, Butter

```json
[
  {
    "name": "Brokkoli",
    "kcalPer100g": 34,
    "proteinPer100g": 2.8,
    "fatPer100g": 0.4,
    "carbsPer100g": 4.0,
    "fiberPer100g": 2.6,
    "source": "preloaded"
  }
]
```

---

## Schema-Versionierung

- **Aktuelle Version:** `v1`
- **Framework:** SwiftData `VersionedSchema` + `SchemaMigrationPlan`
- Vor jeder Breaking Change (Feld umbenennen, Typ ändern, Beziehung anpassen) muss ein `MigrationStage` definiert werden

```swift
// Beispiel wenn v2 nötig wird:
enum KcalKunSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Product.self, DiaryEntry.self] }
}
```

Migrationen werden hier dokumentiert sobald sie anfallen.

| Version | Änderung | Datum |
|---|---|---|
| v1 | Initiales Schema | 2026-03 |
