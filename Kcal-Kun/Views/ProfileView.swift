import SwiftUI
import SwiftData

@MainActor
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitService.self) private var healthKit
    // Optional, weil ProfileView auch ausserhalb des MainTabView-Kontexts (z. B.
    // in Previews) gerendert werden könnte. Bei aktiver Tour + Step 12 zeigen
    // wir eine eingebettete Banner-Card + Pulse-Highlight auf Backup-Row.
    @Environment(CoachmarkController.self) private var coachmarkController
    @Environment(\.coachmarkDemoMode) private var coachmarkDemo

    @Query private var profiles: [UserProfile]

    @State private var heightText = ""
    @State private var weightText = ""
    @State private var bmrText = ""
    @State private var kcalDeltaText = ""
    @State private var goalType: GoalType = .deficit
    @State private var dietStyle: DietStyle = .balanced
    @State private var photoData: Data? = nil
    @State private var bodyFatText = ""
    @State private var loaded = false
    @State private var showAvatarPicker = false
    @State private var healthKitWeight: Double? = nil
    @State private var showBackupExport = false
    @State private var showBackupRestore = false
    @State private var triggerCoachmarkOnDismiss = false
    @State private var showAboutApp = false
    @State private var showAPIKeySetup = false
    /// Tracking: wurde dieses Sheet durch die Coachmark-Tour geöffnet?
    /// Bleibt true bis das Sheet wirklich dismissed (onDisappear) — auch wenn
    /// die Tour weiter zum nächsten Step geht. So bleibt die NavigationBar
    /// versteckt während der Sheet-Dismiss-Animation und der „Abbrechen"-
    /// Button blitzt nicht kurz auf.
    @State private var sheetOpenedByTour = false

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("selectedMascotTone") private var savedMascotTone = "cream"

    private var profile: UserProfile? { profiles.first }

    private var mascotToneFromStorage: MascotTone {
        switch savedMascotTone {
        case "terra": return .terra
        case "beige": return .beige
        default:      return .cream
        }
    }

    private var canSave: Bool {
        parseDouble(heightText) != nil &&
        parseDouble(weightText) != nil &&
        parseDouble(bmrText) != nil &&
        (goalType == .maintenance || parseDouble(kcalDeltaText) != nil)
    }

    /// True wenn die Coachmark-Tour aktiv ist UND aktuell beim Backup-Step
    /// steht (Step 12). Steuert das eingebettete CoachmarkOverlay im
    /// Profile-Sheet (dim layer + spotlight + bubble — gleicher Look wie alle
    /// anderen Tour-Steps).
    private var isCoachmarkBackupStep: Bool {
        coachmarkController.isActive
            && coachmarkController.currentStep < COACH_STEPS.count
            && COACH_STEPS[coachmarkController.currentStep].target == .profileBackupBtn
    }

    /// Demo-Werte für die Coachmark-Tour. Das Profil zeigt während der Tour
    /// NICHT die echten User-Daten — generisches Beispiel-Profil, damit die
    /// Tour deterministisch ist und kein User-Profil exponiert wird.
    private func loadDemoProfileData() {
        heightText      = "175"
        weightText      = "72"
        bodyFatText     = "18"
        bmrText         = "1700"
        kcalDeltaText   = "300"
        goalType        = .deficit
        dietStyle       = .balanced
        photoData       = nil           // Mascot-Default statt echtem Foto
        healthKitWeight = 72.4
        loaded          = true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            avatarSection
                            bodyDataSection
                            caloriesSection
                            dietStyleSection
                            saveSection
                            helpSection
                            aiSetupSection
                            dataSection
                                .id("backupSection")
                            appSection
                            onboardingResetSection
                            Spacer().frame(height: 24)
                        }
                        .padding(.top, 12)
                    }
                    // Tour-Step 12: nach Sheet-Open zum Backup-Button scrollen.
                    // 0.4s Delay deckt die Sheet-Animation ab; ohne Delay greift
                    // ScrollViewProxy auf eine View, die noch nicht ihr Final-
                    // Layout hat.
                    .onChange(of: isCoachmarkBackupStep) { _, active in
                        guard active else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation(.easeInOut(duration: 0.45)) {
                                proxy.scrollTo("backupSection", anchor: .center)
                            }
                        }
                    }
                    .onAppear {
                        // Falls Sheet bereits in Tour-Mode startet (Hot-Reload,
                        // Re-Mount): gleicher Scroll-Trigger.
                        if isCoachmarkBackupStep {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                withAnimation(.easeInOut(duration: 0.45)) {
                                    proxy.scrollTo("backupSection", anchor: .center)
                                }
                            }
                        }
                    }
                }

                // Eingebettetes Coachmark-Overlay für Step 12 (Backup).
                // SwiftUI-Sheets überdecken das normale CoachmarkOverlay auf
                // MainTabView; deshalb mounten wir es hier nochmal mit demselben
                // Controller. Selber Look, gleicher State.
                if isCoachmarkBackupStep {
                    CoachmarkOverlay(controller: coachmarkController)
                        .transition(.opacity)
                        .zIndex(100)
                        .ignoresSafeArea()
                }
            }
            // Übergang animieren — sonst verschwindet das Overlay synchron mit
            // dem Step-Change und wirkt ruckelig. .easeInOut deckt die ~0.3s
            // bis das Sheet schliesst und gibt ein smoother Fade-Out.
            .animation(.easeInOut(duration: 0.3), value: isCoachmarkBackupStep)
            // Spotlight-Tracking innerhalb des Sheets: misst die Position der
            // Backup-Row und schreibt sie in den geteilten spotlightRect.
            .onPreferenceChange(CoachmarkAnchorKey.self) { frames in
                guard isCoachmarkBackupStep,
                      let frame = frames[.profileBackupBtn] else { return }
                let padded = frame.insetBy(dx: -8, dy: -8)
                withAnimation(.easeInOut(duration: 0.35)) {
                    coachmarkController.spotlightRect = padded
                }
            }
            .onChange(of: isCoachmarkBackupStep) { _, isActive in
                // Beim Verlassen des Backup-Steps Spotlight zurücksetzen, sonst
                // bleibt MainTabView's spotlightRect auf einer alten Profile-
                // Sheet-Position kleben (z.B. wenn das Sheet wegschwenkt).
                if !isActive {
                    coachmarkController.spotlightRect = .zero
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // NavigationBar versteckt solange das Sheet via Tour geöffnet ist
            // — auch während der Dismiss-Animation. Sonst würde beim Step-
            // Wechsel der „Abbrechen"-Button kurz aufblitzen (weil
            // isCoachmarkBackupStep synchron false wird, aber das Sheet erst
            // ~0.3-0.7s später wirklich schliesst). `sheetOpenedByTour` bleibt
            // true bis onDisappear.
            .toolbar(sheetOpenedByTour ? .hidden : .visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Profil")
                        .font(.display(18))
                        .foregroundStyle(Color.inkPrimary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Color.warmBrown)
                }
            }
            .sheet(isPresented: $showAvatarPicker) {
                AvatarPickerSheetContent(savedMascotTone: $savedMascotTone, photoData: $photoData)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showBackupExport) {
                BackupExportView()
            }
            .sheet(isPresented: $showBackupRestore) {
                BackupRestoreView()
            }
            .sheet(isPresented: $showAboutApp) {
                AboutAppView()
            }
            .sheet(isPresented: $showAPIKeySetup) {
                APIKeySetupView(
                    mode: .sheet,
                    onDone: { showAPIKeySetup = false }
                )
            }
            .onDisappear {
                // Tour-Sheet-Flag zurücksetzen — sheetOpenedByTour wird beim
                // nächsten Tour-Run via onAppear neu gesetzt. So bleibt die
                // NavBar bei manuellem Re-Open korrekt sichtbar.
                sheetOpenedByTour = false
                if triggerCoachmarkOnDismiss {
                    triggerCoachmarkOnDismiss = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        NotificationCenter.default.post(name: .startCoachmarkTour, object: nil)
                    }
                }
            }
            .onAppear {
                // Tour-Sheet-Tracking: wenn das Sheet via Tour aufgerufen wird,
                // diesen Flag setzen. Steuert die NavBar-Sichtbarkeit für die
                // gesamte Lebensdauer des Sheets (auch während Dismiss-Anim).
                if isCoachmarkBackupStep {
                    sheetOpenedByTour = true
                }
                guard !loaded else { return }
                // Während der Coachmark-Tour (Backup-Step) zeigen wir Demo-
                // Daten statt der echten User-Profil-Werte. Schützt die
                // Privatsphäre und macht die Tour auf jedem Gerät identisch.
                if coachmarkDemo {
                    loadDemoProfileData()
                    return
                }
                guard let p = profile else { loaded = true; return }
                heightText    = formatDouble(p.heightCm)
                weightText    = formatDouble(p.weightKg)
                bmrText       = formatDouble(p.bmr)
                kcalDeltaText = formatDouble(p.kcalDelta)
                goalType      = p.goalType
                dietStyle     = p.dietStyle
                photoData     = p.photoData
                bodyFatText   = p.bodyFatPercent.map { formatDouble($0) } ?? ""
                loaded        = true
            }
            .task {
                // HealthKit-Fetch im Demo-Mode überspringen — sonst würde das
                // echte Gewicht über die Demo-Werte gelegt.
                guard !coachmarkDemo else { return }
                if let avg = await healthKit.fetchLatestWeightAverage() {
                    healthKitWeight = avg
                    weightText = formatDouble(avg)
                }
            }
        }
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        Button { showAvatarPicker = true } label: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let data = photoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.beige)
                                .frame(width: 100, height: 100)
                            MascotView(size: 68, mood: .happy, tone: mascotToneFromStorage)
                        }
                    }
                }
                .overlay(Circle().stroke(Color.inkDivider, lineWidth: 1))

                ZStack {
                    Circle()
                        .fill(Color.terra)
                        .frame(width: 28, height: 28)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profilbild ändern")
    }

    // MARK: - Body Data

    private var bodyDataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Körperdaten")
                .padding(.horizontal, 18)

            VStack(spacing: 0) {
                profileRow("Grösse") {
                    HStack(spacing: 4) {
                        TextField("cm", text: $heightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .foregroundStyle(Color.terra)
                        Text("cm")
                            .foregroundStyle(Color.inkSecondary)
                            .font(.system(size: 13))
                    }
                }
                Divider().padding(.leading, 14)
                profileRow("Gewicht") {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            TextField("kg", text: $weightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                                .foregroundStyle(Color.terra)
                            Text("kg")
                                .foregroundStyle(Color.inkSecondary)
                                .font(.system(size: 13))
                        }
                        if healthKitWeight != nil {
                            Text("Ø 7 Messungen · HealthKit")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.inkTertiary)
                        }
                    }
                }
                Divider().padding(.leading, 14)
                profileRow("Körperfett") {
                    HStack(spacing: 4) {
                        TextField("optional", text: $bodyFatText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .foregroundStyle(Color.terra)
                        Text("%")
                            .foregroundStyle(Color.inkSecondary)
                            .font(.system(size: 13))
                    }
                }
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
            .padding(.horizontal, 18)
        }
    }

    // MARK: - Calories

    private var caloriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Kalorien")
                .padding(.horizontal, 18)

            VStack(spacing: 0) {
                profileRow("Grundumsatz") {
                    HStack(spacing: 4) {
                        TextField("kcal", text: $bmrText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .foregroundStyle(Color.terra)
                        Text("kcal")
                            .foregroundStyle(Color.inkSecondary)
                            .font(.system(size: 13))
                    }
                }
                Divider().padding(.leading, 14)

                HStack {
                    Text("Ziel")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.inkSecondary)
                    Spacer()
                    Picker("Ziel", selection: $goalType) {
                        Text("Defizit").tag(GoalType.deficit)
                        Text("Halten").tag(GoalType.maintenance)
                        Text("Aufbau").tag(GoalType.surplus)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .onChange(of: goalType) { _, newVal in
                    if newVal == .maintenance { kcalDeltaText = "0" }
                }

                if goalType != .maintenance {
                    Divider().padding(.leading, 14)
                    profileRow(goalType == .deficit ? "Defizit" : "Überschuss") {
                        HStack(spacing: 4) {
                            TextField("kcal", text: $kcalDeltaText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                                .foregroundStyle(Color.terra)
                            Text("kcal")
                                .foregroundStyle(Color.inkSecondary)
                                .font(.system(size: 13))
                        }
                    }
                }

                Divider().padding(.leading, 14)

                if let bmr = parseDouble(bmrText) {
                    let delta = parseDouble(kcalDeltaText) ?? 0
                    let target: Double = switch goalType {
                    case .deficit:     bmr - delta
                    case .maintenance: bmr
                    case .surplus:     bmr + delta
                    }
                    HStack {
                        Text("Tagesziel")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.inkSecondary)
                        Spacer()
                        Text("\(Int(target)) kcal")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.terra)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
            .padding(.horizontal, 18)
        }
    }

    // MARK: - Diet Style

    private var dietStyleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Ernährungsstil")
                .padding(.horizontal, 18)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(DietStyle.allCases, id: \.self) { style in
                    profileDietCard(style)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    @ViewBuilder
    private func profileDietCard(_ style: DietStyle) -> some View {
        let selected = dietStyle == style
        Button {
            withAnimation(.spring(response: 0.2)) { dietStyle = style }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: style.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(selected ? Color.terra : Color.inkTertiary)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.warmBrown)
                    }
                }
                Text(style.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                Text(style.description)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(style.splitLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(selected ? Color.terra : Color.inkTertiary)
                    .padding(.top, 2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(selected ? Color.beige : Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Color.warmBrown : Color(hex: 0x7C5E3C).opacity(0.10), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private var saveSection: some View {
        Button {
            save()
        } label: {
            Text("Speichern")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? Color.terra : Color.inkDivider)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: canSave ? Color.terra.opacity(0.32) : .clear, radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.horizontal, 18)
        .animation(.spring(response: 0.25), value: canSave)
    }

    // MARK: - Hilfe (Coachmark-Tour)

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Hilfe")
                .padding(.horizontal, 18)
            Button {
                triggerCoachmarkOnDismiss = true
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.terra.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.terra)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tour ansehen")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("\(COACH_STEPS.count)-Schritt-Rundgang durch die App")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.inkTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.inkDivider, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
        }
    }

    // MARK: - KI-Setup (Gemini-API-Key)

    private var aiSetupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "KI-Setup")
                .padding(.horizontal, 18)
            Button {
                showAPIKeySetup = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill((APIKeyService.hasKey ? Color.forest : Color.warmBrown).opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "key.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(APIKeyService.hasKey ? Color.forest : Color.warmBrown)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gemini-API-Key")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        if APIKeyService.hasKey, let key = APIKeyService.getKey() {
                            Text("Gespeichert: \(APIKeyService.masked(key))")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.forest)
                        } else {
                            Text("Noch nicht eingerichtet — antippen")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.warmBrown)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.inkTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.inkDivider, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
        }
    }

    // MARK: - Daten (Backup)

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Daten")
                .padding(.horizontal, 18)

            VStack(spacing: 0) {
                dataRow(
                    icon: "square.and.arrow.up",
                    label: "Backup exportieren",
                    sublabel: "Profil, Produkte, Tagebuch als Datei",
                    tint: Color.terra
                ) { showBackupExport = true }

                Divider().padding(.leading, 14)

                dataRow(
                    icon: "square.and.arrow.down",
                    label: "Backup wiederherstellen",
                    sublabel: "Daten aus einer .json-Datei zusammenführen",
                    tint: Color.warmBrown
                ) { showBackupRestore = true }
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.inkDivider, lineWidth: 1))
            // WICHTIG: Coachmark-Target VOR .padding setzen, damit die
            // GeometryReader das sichtbare Card-Frame misst und NICHT den
            // äusseren Padding-Wrapper (sonst wäre der Spotlight 36pt zu
            // breit — die Padding-Zonen lägen ausserhalb der Card).
            .coachmarkTarget(.profileBackupBtn)
            .padding(.horizontal, 18)
        }
    }

    @ViewBuilder
    private func dataRow(icon: String, label: String, sublabel: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Text(sublabel)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - App (Über die App / Legal)

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "App")
                .padding(.horizontal, 18)
            Button {
                showAboutApp = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.warmBrown.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.warmBrown)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Über die App")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("Version, Datenschutz, Impressum, AGB")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.inkTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.inkDivider, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
        }
    }

    // MARK: - Onboarding Reset

    private var onboardingResetSection: some View {
        Button {
            dismiss()
            hasCompletedOnboarding = false
        } label: {
            Label("Onboarding neu starten", systemImage: "arrow.counterclockwise")
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.cardBackground)
                .foregroundStyle(Color.warmBrown)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(hex: 0x7C5E3C).opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
    }

    // MARK: - Row helper

    @ViewBuilder
    private func profileRow<Content: View>(_ label: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func save() {
        // Tour-Modus: nicht in den echten ModelContext schreiben — sonst
        // würden die Demo-Werte das echte User-Profil überschreiben.
        if coachmarkDemo {
            Log.ui.info("ProfileView: Save während Coachmark-Tour ignoriert (Demo-Werte)")
            dismiss()
            return
        }
        guard let h = parseDouble(heightText),
              let w = parseDouble(weightText),
              let b = parseDouble(bmrText) else { return }
        let d = goalType == .maintenance ? 0 : (parseDouble(kcalDeltaText) ?? 0)

        let p = profile ?? {
            let newProfile = UserProfile()
            modelContext.insert(newProfile)
            return newProfile
        }()
        p.heightCm       = h
        p.weightKg       = w
        p.bmr            = b
        p.kcalDelta      = d
        p.goalType       = goalType
        p.dietStyle      = dietStyle
        p.photoData      = photoData
        p.bodyFatPercent = parseDouble(bodyFatText)
        modelContext.saveOrLog("ProfileView: Profil aktualisiert")
        dismiss()
    }
}

private struct AvatarPickerSheetContent: View {
    @Binding var savedMascotTone: String
    @Binding var photoData: Data?
    @Environment(\.dismiss) private var dismiss
    @State private var showImagePicker = false

    private let tones: [(id: String, tone: MascotTone, label: String)] = [
        ("cream", .cream, "Klassisch"),
        ("terra", .terra, "Terra"),
        ("beige", .beige, "Beige"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Avatar wählen")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
                .padding(.top, 20)
                .padding(.horizontal, 20)

            HStack(spacing: 10) {
                ForEach(tones, id: \.id) { option in
                    let selected = savedMascotTone == option.id && photoData == nil
                    Button {
                        savedMascotTone = option.id
                        photoData = nil
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            MascotView(size: 64, mood: .happy, tone: option.tone)
                                .padding(.top, 10)
                            Text(option.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(selected ? Color.warmBrown : Color.inkSecondary)
                                .padding(.bottom, 10)
                        }
                        .frame(maxWidth: .infinity)
                        .background(selected ? Color.beige : Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(selected ? Color.warmBrown : Color(hex: 0x7C5E3C).opacity(0.10), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Button {
                showImagePicker = true
            } label: {
                HStack(spacing: 14) {
                    if let data = photoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.terra, lineWidth: 2))
                    } else {
                        ZStack {
                            Circle().fill(Color.beige).frame(width: 44, height: 44)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.warmBrown)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(photoData != nil ? "Foto ändern" : "Eigenes Foto hochladen")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("Aus Fotobibliothek wählen")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.inkTertiary)
                }
                .padding(14)
                .background(photoData != nil ? Color.beige : Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(photoData != nil ? Color.warmBrown : Color(hex: 0x7C5E3C).opacity(0.10), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.appBackground)
        .fullScreenCover(isPresented: $showImagePicker) {
            ImagePickerWithCrop { data in
                photoData = data
                dismiss()
            }
            .ignoresSafeArea()
        }
    }
}

private func parseDouble(_ text: String) -> Double? {
    let normalized = text.replacingOccurrences(of: ",", with: ".")
    guard !normalized.isEmpty else { return nil }
    return Double(normalized)
}

private func formatDouble(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0
        ? String(Int(value))
        : String(format: "%.1f", value)
}
