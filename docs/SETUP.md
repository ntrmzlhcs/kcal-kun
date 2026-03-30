# Development Setup

Schritt-für-Schritt-Anleitung, um Kcal-Kun auf einem neuen Mac zu kompilieren und auf dem iPhone zu starten.

---

## Prerequisites

| Anforderung | Details |
|---|---|
| Xcode 16+ | SwiftData + Swift 6 Concurrency; ältere Versionen werden nicht unterstützt |
| Physisches iPhone | Simulator hat keine Kamera — für den Scanner wird ein echtes Gerät benötigt |
| iOS 18.0+ | Deployment Target der App |
| Google AI Studio Key | Kostenloses Konto unter [aistudio.google.com](https://aistudio.google.com) |
| Apple ID | Kostenlos; kein bezahlter Developer Account nötig für Sideloading |

---

## 1. Repository klonen

```bash
git clone <repo-url>
cd Kcal-Kun
```

> `Secrets.xcconfig` ist im `.gitignore` und **nicht** im Repository. Dieser Schritt wird separat in Abschnitt 2 beschrieben.

---

## 2. API-Key konfigurieren

### 2.1 Secrets.xcconfig anlegen

Erstelle die Datei `Kcal-Kun/Secrets.xcconfig` (direkt im Xcode-Projektordner, **nicht** ins Repo committen):

```
// Secrets.xcconfig
// WARNUNG: Diese Datei niemals committen — sie steht in .gitignore

GEMINI_API_KEY = dein_api_key_hier
```

Den API-Key erhältst du unter [aistudio.google.com](https://aistudio.google.com) → "Get API Key".

### 2.2 xcconfig in Xcode verlinken

1. Xcode öffnen → Projekt-Navigator → Projektdatei (blaues Icon) auswählen
2. Reiter **Info** → Abschnitt **Configurations**
3. Bei **Debug** und **Release**: Dropdown öffnen → `Secrets` auswählen

### 2.3 Key in Info.plist eintragen

In `Info.plist` einen neuen Eintrag hinzufügen:

| Key | Type | Value |
|---|---|---|
| `GEMINI_API_KEY` | String | `$(GEMINI_API_KEY)` |

### 2.4 Key in Swift lesen

```swift
let apiKey = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String ?? ""
```

---

## 3. Xcode-Projekt konfigurieren

1. **Bundle ID** — `Signing & Capabilities` → Bundle Identifier: `com.deinname.kcalkun`
2. **Signing** — Team: persönliche Apple ID aus dem Dropdown auswählen
3. **Deployment Target** — `General` → Minimum Deployments: **iOS 18.0**
4. **Kamera-Berechtigung** — In `Info.plist` eintragen:

| Key | Value |
|---|---|
| `NSCameraUsageDescription` | `Kcal-Kun verwendet die Kamera, um Nährwerttabellen auf Verpackungen zu scannen.` |

---

## 4. App auf dem iPhone starten

1. iPhone per USB mit dem Mac verbinden
2. In Xcode das iPhone als Run Destination auswählen (oben in der Toolbar)
3. **Cmd+R** — App wird gebaut und installiert
4. Beim ersten Start auf dem iPhone:
   - `Einstellungen → Allgemein → VPN & Geräteverwaltung`
   - Deine Apple ID antippen → **Vertrauen** bestätigen
5. App öffnen

---

## 5. Externe APIs

### Gemini (Google AI Studio)

- **Endpoint:** `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent`
- **Authentifizierung:** API-Key als Query-Parameter `?key=API_KEY`
- **Methode:** `POST`, Content-Type: `application/json`
- Free Tier: 250 Requests/Tag — für Eigengebrauch mehr als ausreichend

### naehrwertdaten.ch (BLV REST-API)

- **Base URL:** `https://naehrwertdaten.ch/api/`
- **Authentifizierung:** Keine — öffentliche Schweizer Bundesdaten
- Wird als Best-Effort-Ergänzung verwendet; App funktioniert auch ohne Verbindung

---

## Troubleshooting

| Problem | Ursache | Lösung |
|---|---|---|
| `"Could not launch"` auf dem iPhone | Entwickler-Zertifikat nicht vertraut | Einstellungen → Allgemein → VPN & Geräteverwaltung → Apple ID → Vertrauen |
| `"API key not found"` / leerer Key | `Secrets.xcconfig` nicht mit Xcode verlinkt | Abschnitt 2.2 erneut durchführen |
| Build-Fehler: SwiftData nicht gefunden | Deployment Target unter iOS 17 | General → Minimum Deployments auf iOS 18.0 setzen |
