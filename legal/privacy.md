---
title: Datenschutzerklärung — Kcal-Kun
layout: default
---

# Datenschutzerklärung

**Stand:** 2026-05-18
**App:** Kcal-Kun (iOS)
**Anbieter:** Martin Schulz (Privatperson), 8005 Zürich, kcal.kun.ch@gmail.com

---

## 1. Überblick

Kcal-Kun ist ein iOS-Kalorientagebuch, das ohne Backend-Server auskommt. Deine Daten bleiben grundsätzlich auf deinem iPhone. Die einzigen Stellen, an denen Daten dein Gerät verlassen, sind drei KI-gestützte Funktionen, die direkt mit deinem **eigenen Google-Gemini-API-Key** mit Google's Servern kommunizieren. Der Anbieter dieser App hat zu keinem Zeitpunkt Zugriff auf deine Daten.

---

## 2. Daten, die das Gerät verlassen

Es gibt drei Funktionen, die Daten an Google Gemini senden — **alle direkt von deinem iPhone, mit deinem persönlichen API-Key**:

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

**Wichtig:** Alle drei Calls erfolgen direkt von deinem iPhone an Google's Server, **authentifiziert mit deinem eigenen Gemini-API-Key**. Der App-Anbieter (Martin Schulz) hat zu keinem Zeitpunkt Zugriff auf deine Bilder, Tagebuch-Daten oder deinen API-Key.

---

## 3. Daten, die das Gerät NICHT verlassen

- **Tagebuch-Einträge, Produkte, Bibliothek, Profil, Avatar** — werden lokal in SwiftData auf deinem iPhone gespeichert.
- **HealthKit-Daten** (Workout-Kalorien, Gewichtsmessungen) — bleiben in der HealthKit-Sandbox auf dem iPhone. Diese werden nur dann an Google gesendet, wenn du die KI-Ernährungsanalyse aktiv nutzt (siehe 2.3).
- **API-Key** — sicher im iOS Keychain auf dem Gerät gespeichert.
- **Backup-Dateien (JSON-Export)** — nur dort, wo du sie selbst hinspeicherst (iCloud Drive, Mail, AirDrop, etc.). Die Backup-Funktion sendet die Daten nicht an den Anbieter.

---

## 4. Drittanbieter

### 4.1 Google LLC (Gemini API)

Wenn du die KI-Funktionen nutzt, baust du eine direkte Verbindung mit Google's Servern auf, authentifiziert über deinen eigenen API-Key. Google verarbeitet deine Daten gemäß deren eigener Datenschutzrichtlinie und den Bedingungen deines Google-Cloud-Accounts.

- **Google Privacy Policy:** [policies.google.com/privacy](https://policies.google.com/privacy)
- **Gemini API Terms:** [ai.google.dev/terms](https://ai.google.dev/terms)

Datenübermittlung in die USA: Google verfügt über entsprechende DSGVO-Konformitätsmechanismen (Standardvertragsklauseln, Data Privacy Framework).

### 4.2 Apple Inc.

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

Für Fragen zum Datenschutz: **kcal.kun.ch@gmail.com**

---

## 9. Änderungen dieser Datenschutzerklärung

Diese Datenschutzerklärung kann angepasst werden, wenn sich die App-Funktionen oder rechtlichen Anforderungen ändern. Die jeweils aktuelle Version ist in der App unter „Über die App → Datenschutz" abrufbar.
