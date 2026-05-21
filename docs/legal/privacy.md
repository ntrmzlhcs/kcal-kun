---
title: Datenschutzerklärung — Kcal-Kun
layout: default
---

# Datenschutzerklärung

**Stand:** 2026-05-18
**App:** Kcal-Kun (iOS)
**Anbieter:** Martin Schulz (Privatperson), Pfingstweidstrasse 106a, 8005 Zürich, Schweiz · martinschulz.privat@gmail.com

---

## 1. Überblick

Kcal-Kun ist ein iOS-Kalorientagebuch, das ohne Backend-Server auskommt. Deine Daten bleiben grundsätzlich auf deinem iPhone. Die einzigen Stellen, an denen Daten dein Gerät verlassen, sind drei KI-gestützte Funktionen, die direkt mit deinem **eigenen Google-Gemini-API-Key** mit Google's Servern kommunizieren. Der Anbieter dieser App hat zu keinem Zeitpunkt Zugriff auf deine Daten.

---

## 2. Daten, die das Gerät verlassen

Es gibt vier Funktionen, die Daten an externe Server senden — **alle direkt von deinem iPhone**:

### 2.1 OCR-Scanner (Nährwerttabelle fotografieren)

- **Verarbeitete Daten:** Foto der Nährwerttabelle
- **Empfänger:** Google Gemini API (USA / weltweite Rechenzentren)
- **Zweck:** Extraktion der Nährwerte (kcal, Protein, Fett, KH, etc.)
- **Speicherung bei Google:** Gemäß deinen Google-Cloud-Einstellungen (typischerweise temporäre Verarbeitung ohne dauerhafte Speicherung)

### 2.2 Gericht-Analyse (Mahlzeit fotografieren)

- **Verarbeitete Daten:** Foto des gesamten Gerichts
- **Empfänger:** Google Gemini API
- **Zweck:** KI-Schätzung der Nährwerte basierend auf sichtbaren Komponenten
- **Speicherung bei Google:** wie oben

### 2.3 KI-Ernährungsanalyse (Statistik-Tab)

- **Verarbeitete Daten:**
  - Tagebuch-Einträge der letzten 30 Tage als Text (Produktnamen, kcal, Makros, Datum, Mahlzeit-Slot)
  - Profil-Daten: Größe, Gewicht, Grundumsatz (BMR), Tagesziel-Delta, gewählter Ernährungsstil, Goal-Type (Defizit/Halten/Aufbau), ggf. Körperfett-%
  - Gewichtsverlauf der letzten 30 Tage (aus HealthKit, falls verfügbar und freigegeben)
  - Workout-Kalorien der letzten 30 Tage (aus HealthKit, falls verfügbar und freigegeben)
- **Empfänger:** Google Gemini API
- **Zweck:** Personalisierte Ernährungs-Auswertung mit Mustern und Mahlzeit-Vorschlägen
- **Speicherung bei Google:** wie oben

**Wichtig:** Diese drei Calls erfolgen direkt von deinem iPhone an Google's Server, **authentifiziert mit deinem eigenen Gemini-API-Key**. Der App-Anbieter (Martin Schulz) hat zu keinem Zeitpunkt Zugriff auf deine Bilder, Tagebuch-Daten oder deinen API-Key.

### 2.4 Barcode-Scanner (Open Food Facts)

- **Verarbeitete Daten:** Der gescannte EAN-/UPC-Barcode (z. B. `7613034626844`) — ein numerischer Strichcode auf der Produktverpackung.
- **Empfänger:** Open Food Facts (gemeinnütziger Verein, Sitz in Frankreich)
- **Zweck:** Abfrage der Nährwerte des Produkts aus der offenen Lebensmittel-Datenbank.
- **Speicherung bei Open Food Facts:** Anonyme Server-Logs (IP-Adresse, Zeitstempel, abgefragter Barcode) — gemäss [Open-Food-Facts-Datenschutzerklärung](https://world.openfoodfacts.org/cgi/privacy.pl). Keine Account-Daten, keine personenbezogenen Daten, kein User-Identifier.

**Wichtig:** An Open Food Facts wird **ausschliesslich** der Barcode-String übermittelt — keine Tagebuch-Daten, keine HealthKit-Werte, keine personenbezogenen Informationen.

---

## 3. Daten, die das Gerät NICHT verlassen

- **Tagebuch-Einträge, Produkte, Bibliothek, Profil, Avatar** — werden lokal in SwiftData auf deinem iPhone gespeichert.
- **HealthKit-Daten** (Workout-Kalorien, Gewichtsmessungen) — bleiben in der HealthKit-Sandbox auf dem iPhone. Diese werden nur dann an Google gesendet, wenn du die KI-Ernährungsanalyse aktiv nutzt (siehe 2.3).
- **API-Key** — sicher im iOS Keychain auf dem Gerät gespeichert.
- **Backup-Dateien (JSON-Export)** — nur dort, wo du sie selbst hinspeicherst (iCloud Drive, Mail, AirDrop, etc.). Die Backup-Funktion sendet die Daten nicht an den Anbieter.

---

## 4. Drittanbieter

### 4.1 Google LLC (Gemini API)

Wenn du die KI-Funktionen nutzt, baut die App eine direkte Verbindung mit Google's Servern auf, authentifiziert über deinen eigenen API-Key.

**Wichtiger Hinweis — Free Tier vs. Paid Tier:**

- **Google AI Studio Free Tier (kostenlos):** Laut Google's eigenen Nutzungsbedingungen werden eingereichte Daten (Texte, Fotos, Ernährungsdaten) **gespeichert, durch menschliche Reviewer geprüft und zur Verbesserung sowie zum Training von Google-Produkten verwendet**. Da Kcal-Kun Gesundheitsdaten verarbeitet, raten wir **dringend vom Free Tier ab**.
- **Google AI Studio Paid Tier (Pay-as-you-go, mit Abrechnungskonto):** Daten werden laut Google **nicht zum Training verwendet** und vertraulich behandelt. Die Kosten sind für die typische Nutzung sehr gering (wenige Cent pro Monat).

Da die Datenübermittlung direkt über deinen persönlichen API-Key erfolgt, **liegt die Wahl des Datenschutz-Niveaus und die Verantwortung dafür vollständig bei dir**. Die App kann das Tier-Level deines Keys nicht erkennen oder beeinflussen.

**HealthKit-Daten:** Die Übermittlung von HealthKit-Daten (Gewicht, Workouts) an Google erfolgt **ausschließlich**, wenn du die KI-Ernährungsanalyse im Statistik-Tab **aktiv per Knopfdruck startest**. Ohne diese Aktion bleibt HealthKit lokal auf deinem Gerät.

- **Google Privacy Policy:** [policies.google.com/privacy](https://policies.google.com/privacy)
- **Gemini API Terms:** [ai.google.dev/terms](https://ai.google.dev/terms)

Datenübermittlung in die USA: Google verfügt über entsprechende DSGVO-Konformitätsmechanismen (Standardvertragsklauseln, Data Privacy Framework).

### 4.2 Open Food Facts (gemeinnütziger Verein, Frankreich)

Wenn du den Barcode-Scanner nutzt, baut die App eine direkte Verbindung mit den Servern von Open Food Facts auf, um den gescannten Code abzufragen.

- **Lizenz der Daten:** Open Database License (ODbL) — frei kommerziell nutzbar.
- **Übertragen wird:** ausschliesslich der numerische Strichcode (z. B. EAN-13) — keine personenbezogenen Daten, kein User-Identifier, kein API-Key.
- **Daten-Standort:** Server in Frankreich (EU/EWR — DSGVO-konform).
- **Privacy Policy:** [world.openfoodfacts.org/cgi/privacy.pl](https://world.openfoodfacts.org/cgi/privacy.pl)
- **Über Open Food Facts:** [world.openfoodfacts.org](https://world.openfoodfacts.org)

Open Food Facts ist ein crowd-sourced Projekt, das Lebensmittel-Daten von Freiwilligen erfasst und unter offener Lizenz zugänglich macht.

### 4.3 Apple Inc.

Der App-Kauf (einmalig CHF 4.90) wird über Apple's App Store abgewickelt. Apple verarbeitet die Zahlung gemäß deren Datenschutzrichtlinie.

- **Apple Privacy Policy:** [apple.com/privacy](https://www.apple.com/privacy/)

---

## 5. Speicherdauer

- **Lokal auf deinem Gerät:** Die Daten bleiben so lange gespeichert, bis du sie selbst löschst oder die App deinstallierst.
- **Bei Google:** Server-seitige Speicherung gemäß deinen eigenen Google-Cloud-Einstellungen.
- **Beim App-Anbieter:** Gar nichts. Wir betreiben keinen Server, der deine Daten verarbeitet oder speichert.

---

## 6. Deine Rechte nach DSGVO und CH-Datenschutzgesetz

- **Auskunft:** Du kannst jederzeit Einsicht in alle deine Daten nehmen — sie sind alle auf deinem Gerät direkt sichtbar (Tagebuch, Profil, Bibliothek).
- **Löschung:** App-Deinstallation entfernt alle lokalen Daten. Backup-Dateien (JSON) musst du selbst löschen (z.B. aus iCloud Drive).
- **Berichtigung:** Jederzeit direkt in der App möglich.
- **Datenportabilität:** Über die Backup-Export-Funktion erhältst du alle deine Daten als JSON-Datei.
- **Widerspruch / Einschränkung der Verarbeitung:** Da der Anbieter keine deiner Daten verarbeitet, ist dies gegenüber dem Anbieter gegenstandslos. Bei Google: über deinen Google-Cloud-Account.
- **Beschwerderecht:** Bei der für dich zuständigen Datenschutzbehörde (in der Schweiz: EDÖB; in DE: jeweilige Landesdatenschutzbehörde).

---

## 7. Cookies, Tracking, Werbung

Kcal-Kun verwendet **keine** Cookies, **keine** Tracking-Tools, **keine** Werbe-IDs und **keine** Analytics-SDKs. Keine deiner Aktionen in der App werden für Marketing-Zwecke ausgewertet.

---

## 8. Kontakt

Für Fragen zum Datenschutz: **martinschulz.privat@gmail.com**

---

## 9. Änderungen dieser Datenschutzerklärung

Diese Datenschutzerklärung kann angepasst werden, wenn sich die App-Funktionen oder rechtlichen Anforderungen ändern. Die jeweils aktuelle Version ist in der App unter „Über die App → Datenschutz" abrufbar.
