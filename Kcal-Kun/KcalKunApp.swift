import SwiftUI
import SwiftData

@main
struct KcalKunApp: App {
    let modelContainer: ModelContainer
    /// True, wenn der initiale ModelContainer-Aufbau fehlgeschlagen ist und wir
    /// auf einen frischen Store ausweichen mussten. Wird im UI als Banner gezeigt.
    let didRecoverFromCorruptStore: Bool
    @State private var healthKit = HealthKitService()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        let (container, recovered) = Self.buildContainer()
        self.modelContainer = container
        self.didRecoverFromCorruptStore = recovered
    }

    /// Versucht den ModelContainer in mehreren Stufen aufzubauen, statt direkt
    /// zu crashen. Strategie:
    /// 1. Normaler Init mit dem Default-Store.
    /// 2. Falls Fail (z. B. Schema-Migration-Konflikt): den Store-Ordner
    ///    umbenennen (als „corrupt-Backup" behalten — nicht löschen, damit der
    ///    User mit Support seine Daten recovern könnte) und mit frischem Store
    ///    neu initialisieren.
    /// 3. Falls auch das fehlschlägt: In-Memory-Container, damit die App
    ///    überhaupt startet — der User kann dann ein Backup wiederherstellen.
    private static func buildContainer() -> (ModelContainer, Bool) {
        let schema = Schema([Product.self, DiaryEntry.self, UserProfile.self])

        // Stufe 1 — normaler Init
        do {
            let container = try ModelContainer(for: schema)
            return (container, false)
        } catch {
            Log.app.error("ModelContainer Stufe 1 fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }

        // Stufe 2 — alten Store umbenennen und mit frischem Store retry
        moveCorruptStoreAside()
        do {
            let container = try ModelContainer(for: schema)
            Log.app.warning("ModelContainer Stufe 2 erfolgreich nach Store-Reset")
            return (container, true)
        } catch {
            Log.app.error("ModelContainer Stufe 2 fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }

        // Stufe 3 — In-Memory-Container, damit die App überhaupt startet.
        // Der User kann dann ein Backup laden, ohne dass alles crashed.
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: config)
            Log.app.fault("ModelContainer im Notfall-Modus (in-memory) gestartet")
            return (container, true)
        } catch {
            // Wenn selbst ein In-Memory-Container scheitert, ist die Swift-Runtime
            // grundsätzlich kaputt — hier ist ein Crash wirklich unvermeidlich.
            Log.app.critical("ModelContainer komplett unmöglich: \(error.localizedDescription, privacy: .public)")
            fatalError("ModelContainer konnte auch im Notfall-Modus nicht erstellt werden: \(error)")
        }
    }

    /// Benennt den SwiftData-Default-Store (typisch
    /// `Application Support/default.store`) in einen Backup-Pfad um, sodass
    /// ein frischer Container neu initialisiert werden kann. Der alte Store
    /// wird NICHT gelöscht — der User behält die Möglichkeit, die Daten
    /// manuell zu recovern.
    private static func moveCorruptStoreAside() {
        let fm = FileManager.default
        guard let appSupport = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return
        }
        // SwiftData legt 3 Files an: default.store, .store-shm, .store-wal
        let candidates = ["default.store", "default.store-shm", "default.store-wal"]
        let timestamp = Int(Date().timeIntervalSince1970)
        for name in candidates {
            let src = appSupport.appendingPathComponent(name)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = appSupport.appendingPathComponent("corrupt-\(timestamp)-\(name)")
            try? fm.moveItem(at: src, to: dst)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainTabView()
                        .task {
                            await DataSeeder.seedIfNeeded(context: modelContainer.mainContext)
                            await healthKit.requestAuthorizationAndFetch()
                            // Einmaliges Cleanup von BLV-Duplikat-Stubs aus alten
                            // Backup-Restore-Pfaden (siehe ProductCleanupService).
                            ProductCleanupService.cleanupBLVStubs(context: modelContainer.mainContext)
                        }
                } else {
                    OnboardingView()
                        .task {
                            await DataSeeder.seedIfNeeded(context: modelContainer.mainContext)
                        }
                }
            }
            // App ist DE-only für DACH-Launch — Locale erzwingen, damit DatePicker
            // und system-Komponenten konsistent Deutsch (CH) zeigen, unabhängig
            // von der System-Sprache des Geräts.
            .environment(\.locale, Locale(identifier: "de_CH"))
            // Dynamic Type: User-Präferenz respektieren, aber bei extremen
            // Accessibility-Größen das Layout nicht sprengen. `.accessibility3`
            // ist Apple's empfohlener Cap für nicht-text-zentrierte Apps —
            // grosser Text bleibt lesbar, Layout bleibt intakt.
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            // Recovery-Hinweis: wenn der Store-Aufbau fehlgeschlagen ist und auf
            // einen frischen Store ausgewichen wurde, zeigen wir genau einmal
            // einen Alert beim App-Start, damit der User Bescheid weiss.
            .modifier(StoreRecoveryAlertModifier(showAlert: didRecoverFromCorruptStore))
        }
        .modelContainer(modelContainer)
        .environment(healthKit)
    }
}

/// Zeigt beim ersten Aufruf nach Store-Recovery einen Alert mit Erklärung +
/// Hinweis auf Backup-Restore. Wird in der gleichen Session nicht mehrfach
/// präsentiert (lokaler @State).
private struct StoreRecoveryAlertModifier: ViewModifier {
    let showAlert: Bool
    @State private var presented = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                if showAlert && !presented {
                    presented = true
                }
            }
            .alert("Deine Daten konnten nicht geladen werden", isPresented: $presented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Beim Start wurde ein Problem mit der lokalen Datenbank erkannt. Kcal-Kun ist mit einem frischen Speicher gestartet. Falls du ein Backup (JSON) hast, kannst du es im Profil → Backup wiederherstellen.")
            }
    }
}
