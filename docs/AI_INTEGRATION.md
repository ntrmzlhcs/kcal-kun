# AI Integration

## Modell

**`gemini-2.5-flash-preview-09-2025`** via Google AI Studio REST API

| Kriterium | Bewertung |
|---|---|
| Free Tier | 250 Requests/Tag — für Eigengebrauch mehr als ausreichend |
| Latenz | Flash-Modell: deutlich schneller als Pro |
| Multimodal | Versteht Bilder + Text in einem Request |
| Aufgabe | Strukturierte Extraktion aus Nährwerttabellen — Flash reicht vollständig |

---

## GeminiService

### Request-Aufbau

```
POST https://generativelanguage.googleapis.com/v1beta/models/
     gemini-2.5-flash-preview-09-2025:generateContent?key=API_KEY

Content-Type: application/json
```

**Body-Struktur:**

```json
{
  "contents": [
    {
      "parts": [
        {
          "inlineData": {
            "mimeType": "image/jpeg",
            "data": "<base64-encoded JPEG>"
          }
        },
        {
          "text": "<extraction prompt>"
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0,
    "responseMimeType": "application/json"
  }
}
```

**Bild-Vorverarbeitung:** Vor dem Encoding wird das Bild auf maximal 1024px auf der längsten Seite skaliert. Das reduziert Token-Verbrauch und Latenz ohne Qualitätsverlust bei Nährwerttabellen.

---

### Extraction Prompt

Dies ist der Kern der Integration. Der Prompt wird als Konstante in `GeminiService` gespeichert und hier dokumentiert — bei Änderungen beide Stellen aktualisieren.

```
You are a nutrition data extraction assistant.
Analyse the food packaging label in the image and return ONLY a JSON object
with the following structure — no markdown, no explanation, just the JSON:

{
  "kcalPer100g":     <number or null>,
  "proteinPer100g":  <number or null>,
  "fatPer100g":      <number or null>,
  "carbsPer100g":    <number or null>,
  "fiberPer100g":    <number or null>,
  "sugarPer100g":    <number or null>,
  "saltPer100g":     <number or null>,
  "productNameGuess": "<string or null>"
}

Rules:
- All values must be per 100g.
  If the label shows values per serving, convert using the serving size stated.
- Use null for any field not visible on the label.
- If no nutrition table is visible in the image, return:
  {"error": "no_label_detected"}
- Do not include any text outside the JSON object.
```

---

### Estimation Prompt (kein Label vorhanden)

Für Mahlzeiten ohne Etikett (z. B. "Teller hausgemachte Lasagne"). Text-only Request, kein Bild.

```
You are a nutrition estimation assistant.
The user describes a food or meal: "{userDescription}"

Return ONLY a JSON object with estimated nutritional values per 100g:

{
  "kcalPer100g":     <number>,
  "proteinPer100g":  <number>,
  "fatPer100g":      <number>,
  "carbsPer100g":    <number>,
  "fiberPer100g":    <number or null>,
  "sugarPer100g":    <number or null>,
  "saltPer100g":     <number or null>,
  "productNameGuess": "<string>"
}

Base your estimate on typical Swiss/Central European preparation.
No markdown, no explanation — only the JSON.
```

Einträge aus dem Estimation Mode werden mit `source: .ocr` gespeichert und erhalten in der UI den Hinweis *"KI-Schätzung — bitte bei Bedarf prüfen"*.

---

### Response Parsing

```swift
struct GeminiNutritionResponse: Decodable {
    let kcalPer100g:     Double?
    let proteinPer100g:  Double?
    let fatPer100g:      Double?
    let carbsPer100g:    Double?
    let fiberPer100g:    Double?
    let sugarPer100g:    Double?
    let saltPer100g:     Double?
    let productNameGuess: String?
    let error:           String?
}
```

Extraktion aus der Gemini-Response:

```swift
let text = response.candidates.first?.content.parts.first?.text ?? ""
let data = Data(text.utf8)
let result = try JSONDecoder().decode(GeminiNutritionResponse.self, from: data)
```

---

## Fehlerbehandlung

| Szenario | User-facing-Meldung (Deutsch) | Verhalten |
|---|---|---|
| Kein Internet | *"Kein Internet. Werte manuell eingeben."* | Manuelles Formular anzeigen |
| HTTP 429 (Rate Limit) | *"Zu viele Anfragen. Bitte kurz warten."* | 2s warten, max. 2 Retries, dann Fehler |
| HTTP 400 / ungültige Anfrage | *"Fehler beim Senden. Manuell eingeben."* | Formular anzeigen, Fehler loggen |
| Malformed JSON | *"Antwort konnte nicht gelesen werden."* | Partial parse versuchen, sonst Formular |
| `error: "no_label_detected"` | *"Kein Nährwerttisch erkannt. Foto wiederholen oder manuell eingeben."* | Retry-Button + manuelles Formular |
| Timeout (>15s) | *"Zeitüberschreitung. Nochmals versuchen?"* | Retry-Button |

---

## Kosten & Quota

- **Free Tier:** 250 Requests/Tag für Flash-Modelle (aktuell per 2025 — auf Google AI Studio verifizieren)
- **Token-Schätzung:** Ein 1024px-JPEG kostet ca. 250–300 Input-Tokens
- **Realistische Nutzung:** ~10–20 neue Produkte/Tag → Free Tier reicht komfortabel
- **Monitoring:** Google AI Studio Dashboard zeigt tägliche Nutzung
- Kein eingebautes Quota-Tracking in der App nötig für MVP

---

## Datenschutz

- Das Etikett-Foto wird zur Verarbeitung an Google-Server übertragen
- Kein Server-seitiger Storage über den Request hinaus (laut Google AI Studio Terms, Stand 2025)
- **Kein persönlicher Bezug** im Request: nur ein Foto einer Lebensmittelverpackung, keine Nutzer-ID, kein Account
- Nutzer werden beim ersten Scanner-Start via `NSCameraUsageDescription` informiert

---

## Endpoint-Wartung

> Der Modell-Name `gemini-2.5-flash-preview-09-2025` ist ein Preview-Endpoint und kann sich ändern.

- Modell-Name als Konstante in `GeminiService.swift` definieren: `static let modelName = "gemini-2.5-flash-preview-09-2025"`
- Bei Google AI Studio Release Notes auf neue stabile Versionen prüfen
- Endpoint-URL ebenfalls als Konstante, nie hardcoded in Request-Logik
