# Kcal-Kun

Persönliche iOS-App zum Tracken von Kalorien und Makronährstoffen — optimiert für den Schweizer Alltag. Statt mühsamer Suche fotografiert man einfach die Nährwerttabelle auf der Verpackung: Gemini AI extrahiert die Werte, die App speichert das Produkt lokal — danach ist es per Suche sofort wieder abrufbar.

---

## Features

- **OCR-Label-Scanner** — Foto der Verpackung → Gemini extrahiert Kalorien, Protein, Fett, Kohlenhydrate (pro 100g)
- **Persönliche Produktbibliothek** — Produkte einmalig scannen, mit eigenem Namen speichern, jederzeit wiederverwenden
- **Tagebuch-Ansicht** — Mahlzeiten nach Frühstück / Mittag / Abend / Snacks loggen
- **Portions-Rechner** — Gramm oder Stückzahlen eingeben → Nährwerte werden live berechnet
- **100% offline** — Alle Daten lokal via SwiftData, kein Account erforderlich

---

## Tech Stack

| Bereich | Technologie |
|---|---|
| Sprache | Swift |
| UI | SwiftUI |
| Datenbank | SwiftData |
| KI | Gemini 2.5 Flash (Google AI Studio) |
| Deployment | Sideloading via Xcode, persönliche Apple ID |

---

## Project Status

**Phase 1 – Foundation** — Projektstruktur und Dokumentation

Vollständige Roadmap: [docs/ROADMAP.md](docs/ROADMAP.md)

---

## Quick Start

**Prerequisites:**
- Xcode 16+
- Physisches iPhone (Simulator hat keine Kamera)
- Google AI Studio API-Key ([aistudio.google.com](https://aistudio.google.com))
- Apple ID (kostenlos, kein Developer Account nötig)

**Setup:**

1. Repository klonen: `git clone <repo-url>`
2. `Secrets.xcconfig` mit dem Gemini API-Key anlegen (liegt nicht im Repo)
3. Xcode öffnen, Device auswählen, `Cmd+R`

Ausführliche Anleitung: [docs/SETUP.md](docs/SETUP.md)

---

## Documentation

| Dokument | Inhalt |
|---|---|
| [docs/SETUP.md](docs/SETUP.md) | Entwicklungsumgebung, API-Keys, Sideloading |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | MVVM-Aufbau, Schichten, Datenflüsse |
| [docs/DATA_MODEL.md](docs/DATA_MODEL.md) | SwiftData-Modelle, Felder, Beziehungen |
| [docs/AI_INTEGRATION.md](docs/AI_INTEGRATION.md) | Gemini-Service, Prompt, Fehlerbehandlung |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Entwicklungsphasen mit Checkboxen |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | Code-Konventionen, Git-Workflow |

---

## License

Privates Projekt — ausschliesslich für den persönlichen Eigengebrauch.
