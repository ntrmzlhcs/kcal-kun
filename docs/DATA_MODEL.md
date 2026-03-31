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

| Property | Typ | Default | Beschreibung |
|---|---|---|---|
| `id` | `UUID` | auto | `@Attribute(.unique)` |
| `name` | `String` | — | Anzeigename |
| `brand` | `String?` | nil | Markenname |
| `kcalPer100g` | `Double` | — | Kalorien pro 100g |
| `proteinPer100g` | `Double` | — | Protein pro 100g |
| `fatPer100g` | `Double` | — | Fett pro 100g |
| `carbsPer100g` | `Double` | — | Kohlenhydrate pro 100g |
| `fiberPer100g` | `Double?` | nil | Ballaststoffe pro 100g |
| `sugarPer100g` | `Double?` | nil | Davon Zucker pro 100g |
| `saltPer100g` | `Double?` | nil | Salz pro 100g |
| `servingSizeGrams` | `Double?` | nil | Portionsgrösse (z. B. 1 Ei = 60g) |
| `source` | `ProductSource` | — | Herkunft (siehe Enum) |
| `isFavorite` | `Bool` | `false` | Vom Nutzer als Favorit markiert |
| `createdAt` | `Date` | `Date()` | Automatisch gesetzt |
| `imageData` | `Data?` | nil | Thumbnail des Etikett-Fotos |
| `entries` | `[DiaryEntry]` | `[]` | Inverse Relationship (cascade delete) |

---

## DiaryEntry

Ein einzelner Logg-Eintrag: Produkt + Menge + berechnete Nährwerte (denormalisiert).

| Property | Typ | Beschreibung |
|---|---|---|
| `id` | `UUID` | Auto-generiert |
| `date` | `Date` | Tag des Eintrags |
| `mealSlot` | `MealSlot` | Frühstück / Mittag / Abend / Snacks |
| `product` | `Product` | Beziehung zum Produkt |
| `grams` | `Double` | Konsumierte Menge in Gramm |
| `kcal` | `Double` | Berechnet bei Save: `kcalPer100g * grams / 100` |
| `protein` | `Double` | Berechnet bei Save |
| `fat` | `Double` | Berechnet bei Save |
| `carbs` | `Double` | Berechnet bei Save |
| `fiber` | `Double` | Berechnet bei Save (`fiberPer100g ?? 0`) |

### Warum Denormalisierung?

Nährwerte werden beim Speichern einmalig berechnet — nicht on-the-fly aus `Product` abgeleitet. Grund: Wenn der Nutzer Produktwerte später korrigiert, bleiben historische Einträge unverändert.

---

## Supporting Enums

```swift
enum MealSlot: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Frühstück"
    case lunch     = "Mittag"
    case dinner    = "Abend"
    case snacks    = "Snacks"
}

enum ProductSource: String, Codable {
    case ocr        // Via Kamera + Gemini OCR gescannt
    case blvApi     // Reserviert (aktuell ungenutzt)
    case preloaded  // BLVFoods.json — generische Lebensmittel, nicht löschbar
    case manual     // Manuell eingegeben
}
```

> **Hinweis:** SwiftData `#Predicate` unterstützt keine direkten Enum-Vergleiche (weder `== .preloaded` noch `.rawValue`). Enum-Filterung immer in-memory nach dem Fetch.

---

## Datenbank-Bundle: BLVFoods.json

- **Datei:** `Kcal-Kun/Resources/BLVFoods.json`
- **Inhalt:** 1190 generische Schweizer Lebensmittel
- **Quelle:** Schweizer Nährwertdatenbank v7.0 (naehrwertdaten.ch, BLV, Stand 01.07.2025)
- **Felder:** name, kcalPer100g, proteinPer100g, fatPer100g, carbsPer100g, fiberPer100g?, sugarPer100g?, saltPer100g?
- **Laden:** `DataSeeder` (Key: `hasSeededBLVv7`) — löscht alte `.preloaded`-Einträge, lädt neue

---

## Schema-Migrationen

| Version | Änderung | Datum |
|---|---|---|
| v1 | Initiales Schema: Product, DiaryEntry | 2026-03 |
| v1.1 | `DiaryEntry.fiber` hinzugefügt | 2026-03 |
| v1.2 | `Product.isFavorite: Bool = false` hinzugefügt (Lightweight Migration) | 2026-03 |

> SwiftData Lightweight Migration erfordert Default-Wert **direkt auf der Property-Deklaration** (`var isFavorite: Bool = false`), nicht nur im `init`.
