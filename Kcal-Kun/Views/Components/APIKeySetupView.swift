import SwiftUI

/// Wiederverwendbare Setup-View für den Gemini-API-Key.
/// Wird in drei Kontexten benutzt:
/// - Onboarding-Step (isOnboarding: true → zeigt „Später"-Skip)
/// - Settings-Sheet aus ProfileView (isOnboarding: false → kein Skip)
/// - Lazy-Setup-Sheet aus ScannerView/StatsView wenn API-Key fehlt
struct APIKeySetupView: View {
    enum Mode {
        /// In OnboardingView eingebettet — Skip-Option, kein Sheet-Chrome
        case embedded
        /// Als Sheet — eigene NavigationStack mit Toolbar
        case sheet
    }

    enum ValidationState: Equatable {
        case idle
        case validating
        case success
        case error(String)
    }

    let mode: Mode
    let onDone: () -> Void
    var onSkip: (() -> Void)? = nil

    @State private var keyText: String = ""
    @State private var validationState: ValidationState = .idle
    @State private var showSafari = false
    @State private var showRemoveAlert = false

    private let aiStudioURL = URL(string: "https://aistudio.google.com/app/apikey")!

    var body: some View {
        switch mode {
        case .embedded:
            content
        case .sheet:
            NavigationStack {
                ZStack {
                    Color.appBackground.ignoresSafeArea()
                    ScrollView(showsIndicators: false) { content }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("KI-Setup")
                            .font(.display(18))
                            .foregroundStyle(Color.inkPrimary)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fertig") { onDone() }
                            .foregroundStyle(Color.warmBrown)
                    }
                }
            }
        }
    }

    // MARK: - Content (wiederverwendet in beiden Modes)

    private var content: some View {
        VStack(spacing: 16) {
            header

            instructionsCard
            getKeyButton
            inputCard
            validateButton

            if APIKeyService.hasKey && mode == .sheet {
                removeKeyButton
            }

            if mode == .embedded {
                VStack(spacing: 6) {
                    Button {
                        onSkip?()
                    } label: {
                        Text("Später einrichten")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.inkSecondary)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)

                    // Klarstellung was ohne Key funktioniert — verhindert
                    // Frust und Abbrüche („dann kann ich die App ja gar nicht
                    // nutzen"). Den Key kann der User jederzeit nachreichen
                    // unter Profil → KI-Setup.
                    Text("Ohne Key funktionieren Barcode-Scanner, manuelle Eingabe, Tagebuch und Statistik. Etikett-Scan, Gericht-Analyse und KI-Ernährungsanalyse brauchen den Key — du kannst ihn jederzeit später nachreichen.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkTertiary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                }
            }

            privacyNote
            Spacer().frame(height: 24)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .sheet(isPresented: $showSafari) {
            SafariView(url: aiStudioURL).ignoresSafeArea()
        }
        .alert("Key entfernen?", isPresented: $showRemoveAlert) {
            Button("Entfernen", role: .destructive) {
                APIKeyService.clearKey()
                keyText = ""
                validationState = .idle
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die KI-Features funktionieren danach nicht mehr, bis du einen neuen Key einrichtest.")
        }
        .onAppear {
            if let existing = APIKeyService.getKey() {
                keyText = existing
                validationState = .success
            }
        }
    }

    // MARK: - Sub-Views

    private var header: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                MascotView(size: 88, mood: .scan, tone: .cream, tilt: -4)
                ZStack {
                    Circle().fill(Color.amber)
                        .frame(width: 36, height: 36)
                    Image(systemName: "key.fill")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .offset(x: 16, y: -8)
                .shadow(color: Color.amber.opacity(0.32), radius: 4, y: 2)
            }
            .frame(width: 88, height: 88)
            .padding(.top, 6)

            Text("KI-Setup")
                .font(.display(28))
                .foregroundStyle(Color.inkPrimary)
            Text("Für die KI-Features brauchst du deinen eigenen Google-Gemini-API-Key. Den bekommst du kostenlos — mit einem fairen Tageslimit, das im Alltag locker ausreicht.")
                .font(.system(size: 13))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "So gehst du vor")
            instructionRow(num: "1", text: "Unten auf \"Bei Google AI Studio öffnen\" tippen")
            instructionRow(num: "2", text: "Mit Google-Account einloggen (oder erstellen)")
            instructionRow(num: "3", text: "\"Create API key\" klicken → Key kopieren")
            instructionRow(num: "4", text: "Hier in der App unten einfügen")
        }
        .padding(14)
        .heroCardStyle()
    }

    private func instructionRow(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(Color.terra.opacity(0.15)).frame(width: 22, height: 22)
                Text(num)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.terra)
            }
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private var getKeyButton: some View {
        Button {
            showSafari = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right.square.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Bei Google AI Studio öffnen")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(Color.warmBrown)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.beige.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.warmBrown.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Dein API-Key")
            HStack {
                SecureField("AIza…", text: $keyText)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Color.inkPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: keyText) { _, _ in
                        if case .error = validationState { validationState = .idle }
                        if validationState == .success { validationState = .idle }
                    }
                if !keyText.isEmpty {
                    Button {
                        keyText = ""
                        validationState = .idle
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.inkTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1))

            if case .error(let msg) = validationState {
                Label(msg, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            } else if validationState == .success {
                Label("Key ist gespeichert und gültig", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.forest)
            }

            tierRecommendationBox
        }
    }

    /// Aufklärung: Free Tier nutzt Daten zum KI-Training (kritisch bei Gesundheitsdaten).
    /// Paid Tier (Pay-as-you-go) behandelt Daten vertraulich. Bei Kcal-Kun (Health-Daten)
    /// raten wir DSGVO-konform vom Free Tier ab.
    private var tierRecommendationBox: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.amber)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text("Empfehlung: Paid Tier (Pay-as-you-go)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.warmBrown)
                Text("Mit kostenpflichtigem Google-Abrechnungskonto bleiben deine Daten vertraulich. Im Free Tier nutzt Google deine Daten zum KI-Training — bei Gesundheitsdaten raten wir davon ab. Kosten typisch wenige Cent/Monat.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Color.amber.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Color.amber.opacity(0.25), lineWidth: 1))
        .padding(.top, 4)
    }

    private var borderColor: Color {
        switch validationState {
        case .error: return .red.opacity(0.6)
        case .success: return Color.forest.opacity(0.4)
        default: return Color.inkDivider
        }
    }

    private var validateButton: some View {
        Button { Task { await validate() } } label: {
            HStack(spacing: 8) {
                if validationState == .validating {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: validationState == .success ? "checkmark" : "checkmark.shield.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(validationState == .success ? "Gespeichert ✓" : "Speichern & prüfen")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canValidate ? Color.terra : Color.inkDivider)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: canValidate ? Color.terra.opacity(0.32) : .clear, radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!canValidate || validationState == .validating)
    }

    private var canValidate: Bool {
        !keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var removeKeyButton: some View {
        Button { showRemoveAlert = true } label: {
            Label("Key entfernen", systemImage: "trash")
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.terra.opacity(0.08))
                .foregroundStyle(Color.terra)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.terra.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.forest)
            Text("Dein Key bleibt im iOS Keychain auf diesem Gerät — wir (App-Anbieter) sehen ihn nie. Aufrufe gehen direkt von deinem iPhone an Google.")
                .font(.system(size: 11))
                .foregroundStyle(Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    // MARK: - Validation Logik

    @MainActor
    private func validate() async {
        let trimmed = keyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        validationState = .validating
        let isValid = await APIKeyService.validate(trimmed)
        if isValid {
            if APIKeyService.setKey(trimmed) {
                validationState = .success
                // Bei Onboarding-Mode: nach kurzem Erfolgs-Feedback weiterspringen
                if mode == .embedded {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    onDone()
                }
            } else {
                validationState = .error("Konnte Key nicht im Keychain speichern.")
            }
        } else {
            validationState = .error("Key ungültig oder Netzwerkfehler. Bitte prüfen.")
        }
    }
}
