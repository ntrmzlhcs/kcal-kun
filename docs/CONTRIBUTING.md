# Contributing & Conventions

*Dieses Dokument beschreibt persönliche Entwicklungsstandards für ein Solo-Projekt. Kein Team — aber klare Regeln verhindern Stil-Drift zwischen Entwicklungs-Sessions.*

---

## Code Style

| Regel | Details |
|---|---|
| `@Observable` | ViewModels verwenden das `@Observable`-Makro (Swift 5.9+), nicht `ObservableObject` |
| `async/await` | Überall konsequent — keine Completion-Handler |
| Kein Force-Unwrap | `!` ist verboten ausserhalb von `#Preview`-Blöcken. Stattdessen `guard let` oder `if let` |
| Eine Datei = ein Typ | Dateiname entspricht dem Typ-Namen (z. B. `GeminiService.swift` für `struct GeminiService`) |
| Keine externen Packages | Im MVP ausschliesslich Apple-Frameworks + direkte REST-Calls — keine SPM-Dependencies |
| Keine Kommentare für Offensichtliches | Kommentare nur wo die Logik nicht selbst-erklärend ist |

---

## SwiftUI Conventions

- Jede View-Datei enthält:
  1. Die `View`-Struct
  2. Ein `#Preview`-Makro am Ende
  3. Optional: private Sub-View-Extension in derselben Datei

- Wiederverwendbare UI-Komponenten gehören in `Components/`
  - Beispiele: `MacroSummaryRow`, `MealSlotHeader`, `SourceBadge`, `NutrientRow`

- Sheet-Dismiss: `@Environment(\.dismiss) private var dismiss` — keine custom Bindings

- Formulare: `.keyboardType(.decimalPad)` für Zahlenfelder, `.submitLabel(.done)` für letztes Feld

---

## SwiftData Conventions

- Alle `@Model`-Klassen liegen in `Models/`
- Keine `ModelContext`-Zugriffe direkt in Views — das geht über ViewModels oder Services
- Schema-Änderungen sofort in [DATA_MODEL.md](DATA_MODEL.md) dokumentieren, bevor Code geändert wird

---

## Git Workflow

```
main
├── feature/scanner-view
├── feature/blv-api
├── feature/diary-logging
└── ...
```

| Regel | Details |
|---|---|
| `main` ist immer buildbar | Kein Merge von nicht-kompilierendem Code |
| Feature-Branches | `feature/<beschreibung>` — in Kleinbuchstaben mit Bindestrichen |
| Commit-Messages | Imperativ, Präsens: *"Add GeminiService with response parsing"* |
| Atomare Commits | Ein Commit = eine abgeschlossene logische Einheit |
| `Secrets.xcconfig` | **Niemals committen** — steht in `.gitignore` |

---

## Entscheidungs-Log

Wichtige Architektur-Entscheidungen werden hier festgehalten, damit der Kontext nicht verloren geht.

| Datum | Entscheidung | Begründung |
|---|---|---|
| 2026-03 | Keine SPM-Packages im MVP | Minimale Dependency-Oberfläche für ein Einzel-Nutzer-Projekt |
| 2026-03 | Kcal/Makros auf DiaryEntry denormalisieren | Historische Einträge sollen korrekt bleiben wenn Produkt-Werte editiert werden |
| 2026-03 | Gemini Flash statt Pro | Free Tier ausreichend; bessere Latenz; kein Qualitätsverlust bei Tabellen-Extraktion |
| 2026-03 | SwiftData ohne CloudKit | Maximaler Datenschutz; Komplexität des Sync nicht nötig für Eigengebrauch |

---

## PreloadedFoods.json erweitern

1. Nährwerte auf [naehrwertdaten.ch](https://naehrwertdaten.ch) nachschlagen (BLV-Daten als Quelle verwenden)
2. Eintrag in `PreloadedFoods.json` hinzufügen — alle Werte pro 100g, `"source": "preloaded"`
3. App auf dem Simulator neu installieren (App löschen → Build & Run) damit `DataSeeder` neu ausgeführt wird
4. Auf echtem Gerät: App deinstallieren → neu installieren via Xcode

---

## Neue Datenquellen integrieren

Neue Services folgen dem gleichen Muster wie `GeminiService` und `BLVApiService`:

1. `struct XYZService` in `Services/` anlegen
2. Alle Methoden `async throws`
3. Fehler als eigener `enum XYZError: LocalizedError` typisieren
4. Service wird vom zugehörigen ViewModel instanziiert und gehalten
5. In [ARCHITECTURE.md](ARCHITECTURE.md) dokumentieren
