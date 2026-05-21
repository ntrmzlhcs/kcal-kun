import SwiftUI

extension Notification.Name {
    static let startCoachmarkTour    = Notification.Name("startCoachmarkTour")
    static let coachmarkStepChanged  = Notification.Name("coachmarkStepChanged")
}

@MainActor
@Observable
final class CoachmarkController {
    var currentStep: Int = 0
    var isActive: Bool = false
    var spotlightRect: CGRect = .zero
    var tabBinding: Binding<AppTab>?

    static let storageKey   = "hasSeenCoachmarkTour"
    static let migratedKey  = "hasMigratedCoachmarkFlagForExistingUser"

    // MARK: - Public Lifecycle

    func start() {
        currentStep = 0
        spotlightRect = .zero
        withAnimation(.easeOut(duration: 0.3)) {
            isActive = true
        }
        applyTab()
    }

    func next() {
        guard currentStep < COACH_STEPS.count - 1 else {
            complete()
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep += 1
        }
        applyTab()
    }

    func back() {
        guard currentStep > 0 else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep -= 1
        }
        applyTab()
    }

    func complete() {
        UserDefaults.standard.set(true, forKey: Self.storageKey)
        withAnimation(.easeOut(duration: 0.3)) {
            isActive = false
        }
    }

    func dismiss() { complete() }

    // MARK: - Tab Steuerung

    private func applyTab() {
        guard currentStep < COACH_STEPS.count else { return }
        tabBinding?.wrappedValue = COACH_STEPS[currentStep].tab
        // Verzögert posten, damit die neue Tab-View Zeit hat zu mounten und ihren
        // .onReceive(.coachmarkStepChanged)-Listener zu registrieren. Ohne Delay
        // wird die Notification gesendet bevor z.B. StatsView lauscht → scrollTo
        // wird nie aufgerufen → Chart bleibt an alter Scroll-Position.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self,
                  self.isActive,
                  self.currentStep < COACH_STEPS.count else { return }
            NotificationCenter.default.post(
                name: .coachmarkStepChanged,
                object: COACH_STEPS[self.currentStep].target
            )
        }
    }

    // MARK: - Auto-Launch

    /// Entscheidet, ob die Tour beim App-Start automatisch laufen soll.
    ///
    /// Logik:
    /// - **Bestehende User** (Onboarding bereits abgeschlossen, Tour-Flag noch nie gesetzt)
    ///   werden silent migriert: Flag bekommt `true`, Tour läuft NICHT automatisch.
    ///   Sie können die Tour manuell aus dem Profil starten.
    /// - **Neue User** (Onboarding gerade abgeschlossen, Flag fehlt UND Migration-Flag fehlt)
    ///   sehen die Tour automatisch nach ~0.6s.
    func maybeAutoLaunch() {
        let defaults = UserDefaults.standard
        let onboardingDone = defaults.bool(forKey: "hasCompletedOnboarding")
        let hasSeenValue   = defaults.object(forKey: Self.storageKey) != nil
        let alreadySeen    = defaults.bool(forKey: Self.storageKey)
        let alreadyMigrated = defaults.bool(forKey: Self.migratedKey)

        // One-shot Migration für bestehende User
        if onboardingDone, !hasSeenValue, !alreadyMigrated {
            defaults.set(true, forKey: Self.storageKey)
            defaults.set(true, forKey: Self.migratedKey)
            return
        }

        guard !alreadySeen else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.start()
        }
    }
}
