import SwiftUI

enum BubblePlacement {
    case center
    case leftOfMascot
    case rightOfMascot
}

enum AccessoryKind {
    case wave
    case target
    case pkf
    case plus
    case star
    case magnifier
    case sparkles
    case bars
    case confetti
    case scale
    case lightbulb
    case barcode
    case shield
}

enum PrimaryTint {
    case dark
    case terra
}

struct CoachmarkStep {
    let tab: AppTab
    let target: CoachmarkTarget?
    let spotCornerRadius: CGFloat
    let placement: BubblePlacement
    let mood: MascotMood
    let tone: MascotTone
    let tilt: Double
    let accessory: AccessoryKind
    let title: String
    let body: String
    let primaryCTA: String
    let primaryTint: PrimaryTint
    let showsBack: Bool
}

/// Coachmark-Tour Steps. Reihenfolge & Texte nach Design-Spec. Anzahl der Steps
/// wird via `{stepCount}`-Placeholder in den Body-Strings dynamisch ersetzt
/// (siehe CoachmarkBubble).
let COACH_STEPS: [CoachmarkStep] = [
    // Step 1 — Willkommen (Center, kein Spot)
    .init(tab: .diary,   target: nil,                spotCornerRadius:  0, placement: .center,
          mood: .happy,  tone: .cream, tilt: -3,  accessory: .wave,
          title: "Willkommen bei Kcal-Kun",
          body:  "Ich zeige dir in {stepCount} kurzen Schritten, wie alles funktioniert.",
          primaryCTA: "Los geht's", primaryTint: .dark, showsBack: false),

    // Step 2 — Kcal-Ring
    .init(tab: .diary,   target: .kcalRing,          spotCornerRadius: 28, placement: .rightOfMascot,
          mood: .think,  tone: .terra, tilt:  6,  accessory: .target,
          title: "Dein Tagesziel",
          body:  "Der grosse Ring zeigt, wie viele Kalorien du heute schon zu dir genommen hast — und wie viel noch übrig ist.",
          primaryCTA: "Weiter", primaryTint: .dark, showsBack: true),

    // Step 3 — Makros
    .init(tab: .diary,   target: .macroChips,        spotCornerRadius: 16, placement: .leftOfMascot,
          mood: .wow,    tone: .beige, tilt: -8,  accessory: .pkf,
          title: "Protein, Kohlenhydrate, Fett",
          body:  "Die drei farbigen Ringe zeigen deine Makronährstoff-Aufnahme im Vergleich zu deinem gewählten Ernährungsstil.",
          primaryCTA: "Weiter", primaryTint: .dark, showsBack: true),

    // Step 4 — Plus-Button Frühstück
    .init(tab: .diary,   target: .breakfastPlus,     spotCornerRadius: 25, placement: .rightOfMascot,
          mood: .happy,  tone: .cream, tilt:  8,  accessory: .plus,
          title: "Mahlzeit hinzufügen",
          body:  "Jede Mahlzeit hat ein Plus-Symbol. Tippe drauf, um aus der Bibliothek auszuwählen oder schnell etwas Neues zu erfassen.",
          primaryCTA: "Weiter", primaryTint: .dark, showsBack: true),

    // Step 5 — Bibliothek-Favoriten
    .init(tab: .library, target: .libraryFavorites,  spotCornerRadius: 18, placement: .leftOfMascot,
          mood: .smug,   tone: .terra, tilt: -4,  accessory: .star,
          title: "Deine Bibliothek",
          body:  "Alles, was du loggst, landet hier — plus 1'200 vorgeladene Schweizer Lebensmittel. Markiere Favoriten für schnellen Zugriff.",
          primaryCTA: "Weiter", primaryTint: .dark, showsBack: true),

    // Step 6 — Barcode-Scanner (schnellster Logging-Weg)
    .init(tab: .scanner, target: .scannerBarcodeBtn, spotCornerRadius: 28, placement: .rightOfMascot,
          mood: .smug,   tone: .cream, tilt:  4,  accessory: .barcode,
          title: "Barcode scannen",
          body:  "Der schnellste Weg: halte die Kamera auf den Strichcode einer Verpackung — Kcal-Kun zieht die Nährwerte sofort aus Open Food Facts.",
          primaryCTA: "Weiter", primaryTint: .dark, showsBack: true),

    // Step 7 — Etikett-Scanner
    .init(tab: .scanner, target: .scannerLabelBtn,   spotCornerRadius: 28, placement: .rightOfMascot,
          mood: .scan,   tone: .cream, tilt: -10, accessory: .magnifier,
          title: "Etikett scannen",
          body:  "Halte die Kamera auf eine Nährwert-Tabelle und Kcal-Kun erfasst Kalorien, Protein, Fett und Co. automatisch.",
          primaryCTA: "Weiter", primaryTint: .dark, showsBack: true),

    // Step 7 — Gericht-Analyse
    .init(tab: .scanner, target: .scannerDishBtn,    spotCornerRadius: 24, placement: .leftOfMascot,
          mood: .wow,    tone: .beige, tilt:  4,  accessory: .sparkles,
          title: "KI-Analyse aus Foto",
          body:  "Kein Etikett? Fotografiere die Mahlzeit — Kcal-Kun schätzt Nährwerte per KI. (Abweichung ±20–35%.)",
          primaryCTA: "Weiter", primaryTint: .dark, showsBack: true),

    // Step 8 — Wochenverlauf
    .init(tab: .stats,   target: .statsWeeklyChart,  spotCornerRadius: 22, placement: .leftOfMascot,
          mood: .think,  tone: .cream, tilt:  7,  accessory: .bars,
          title: "Wochenverlauf",
          body:  "Über die Tage erkennst du Muster: zu welchen Tagen kommst du dem Ziel nahe, wo gibt's Ausreisser?",
          primaryCTA: "Weiter", primaryTint: .dark, showsBack: true),

    // Step 9 — Gewichtsverlauf
    .init(tab: .stats,   target: .statsWeightChart,  spotCornerRadius: 22, placement: .rightOfMascot,
          mood: .think,  tone: .terra, tilt: -5,  accessory: .scale,
          title: "Gewichtsverlauf",
          body:  "Dein Gewicht kommt aus der Health-App. Als 7-Tage-Durchschnitt geglättet siehst du den Trend ohne tägliche Schwankungen.",
          primaryCTA: "Weiter", primaryTint: .dark, showsBack: true),

    // Step 10 — KI-Analyse
    .init(tab: .stats,   target: .statsAIAnalysis,   spotCornerRadius: 22, placement: .leftOfMascot,
          mood: .wow,    tone: .beige, tilt:  6,  accessory: .lightbulb,
          title: "KI-Ernährungsanalyse",
          body:  "Eine persönliche Auswertung der letzten 30 Tage — Stärken, Schwächen und konkrete Mahlzeit-Vorschläge.",
          primaryCTA: "Weiter", primaryTint: .dark, showsBack: true),

    // Step 12 — Profil-Icon (smooth-transition Stepping-Stone vor Backup-Step)
    // Spotlight auf den Avatar oben links — User sieht WO das Profil sitzt,
    // bevor das Sheet sich öffnet.
    .init(tab: .diary,   target: .profileButton,     spotCornerRadius: 22, placement: .rightOfMascot,
          mood: .happy,  tone: .cream, tilt:  3,  accessory: .target,
          title: "Dein Profil",
          body:  "Oben links findest du dein Profil: Tagesziel anpassen, Avatar wechseln — und der Backup-Bereich, den ich dir gleich zeige.",
          primaryCTA: "Profil öffnen", primaryTint: .dark, showsBack: true),

    // Step 13 — Backup (öffnet automatisch den Profile-Sheet via DiaryView's
    // Notification-Handler. Im Sheet rendert ProfileView ein eingebettetes
    // CoachmarkOverlay mit dem gleichen Look wie alle anderen Steps — gleiches
    // dim-Layer + Spotlight um die Backup-Row + Bubble darunter. cornerRadius
    // 16 matched zur Backup-Row's RoundedRectangle.)
    .init(tab: .diary,   target: .profileBackupBtn,  spotCornerRadius: 16, placement: .rightOfMascot,
          mood: .smug,   tone: .beige, tilt: -2,  accessory: .shield,
          title: "Sicher deine Daten",
          body:  "Im Profil → „Daten sichern\" exportierst du jederzeit ein Backup (Tagebuch + Bibliothek + Profil). Speichere es in iCloud Drive oder per AirDrop — perfekt vor dem Wechsel des iPhones.",
          primaryCTA: "Weiter", primaryTint: .dark, showsBack: true),

    // Step 13 — Finale (Center, Konfetti)
    .init(tab: .diary,   target: nil,                spotCornerRadius:  0, placement: .center,
          mood: .smug,   tone: .terra, tilt:  0,  accessory: .confetti,
          title: "Du bist startklar!",
          body:  "Die Tour findest du jederzeit wieder im Profil unter „Hilfe\".",
          primaryCTA: "Tagebuch öffnen", primaryTint: .terra, showsBack: true),
]
