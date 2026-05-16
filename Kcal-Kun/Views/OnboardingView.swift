import SwiftUI
import SwiftData

private enum AvatarMode { case mascot, photo }

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("selectedMascotTone") private var savedMascotTone = "cream"

    // Navigation
    @State private var step = 0

    // Step 1 — Ziel
    @State private var selectedGoal: GoalType = .deficit
    @State private var kcalGoal: Double = 2000
    @State private var kcalDelta: Double = 300
    @State private var activity = "moderate"

    // Step 2 — Ernährungsstil
    @State private var selectedDietStyle: DietStyle = .balanced

    // Step 3 — Avatar
    @State private var avatarMode: AvatarMode = .mascot
    @State private var mascotTone = "cream"
    @State private var selectedPhotoData: Data? = nil
    @State private var showImagePicker = false

    private let totalSteps = 5

    private let activities: [(id: String, label: String, desc: String)] = [
        ("low",      "Wenig aktiv",  "Bürojob, kaum Sport"),
        ("moderate", "Moderat",      "Spazieren, 1–3× Sport / Woche"),
        ("high",     "Sehr aktiv",   "Tägliches Training"),
    ]

    private let goals: [(type: GoalType, icon: String, label: String, desc: String)] = [
        (.deficit, "arrow.down.circle.fill", "Abnehmen",       "Kalorien reduzieren"),
        (.deficit, "equal.circle.fill",      "Gewicht halten", "Kalorien ausbalancieren"),
        (.surplus, "arrow.up.circle.fill",   "Aufbau",         "Kalorien erhöhen"),
    ]

    private let mascotTones: [(id: String, tone: MascotTone, label: String)] = [
        ("cream", .cream, "Klassisch"),
        ("terra", .terra, "Terra"),
        ("beige", .beige, "Beige"),
    ]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 54)

                // Progress dots
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? Color.terra : Color.inkDivider)
                            .frame(width: i == step ? 22 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: step)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 20)

                // Step content
                Group {
                    switch step {
                    case 0: stepWelcome
                    case 1: stepGoal
                    case 2: stepDiet
                    case 3: stepAvatar
                    default: stepReady
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.4), value: step)

                Spacer()

                // Navigation buttons
                HStack(spacing: 10) {
                    if step > 0 {
                        Button {
                            withAnimation { step -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 56, height: 56)
                                .background(Color.cardBackground)
                                .foregroundStyle(Color.inkSecondary)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color(hex: 0x7C5E3C).opacity(0.18), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        withAnimation {
                            if step < totalSteps - 1 {
                                step += 1
                            } else {
                                finishOnboarding()
                            }
                        }
                    } label: {
                        Text(ctaLabel)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.terra)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.terra.opacity(0.32), radius: 18, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
            }
        }
        .fullScreenCover(isPresented: $showImagePicker) {
            ImagePickerWithCrop { data in
                selectedPhotoData = data
                avatarMode = .photo
            }
            .ignoresSafeArea()
        }
    }

    private var ctaLabel: String {
        switch step {
        case 0: return "Los geht's"
        case totalSteps - 1: return "Tagebuch öffnen"
        default: return "Weiter"
        }
    }

    // MARK: — Step 0: Willkommen

    private var stepWelcome: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.terra.opacity(0.18), Color.terra.opacity(0)],
                        center: .center, startRadius: 0, endRadius: 100
                    ))
                    .frame(width: 220, height: 220)
                MascotView(size: 140, mood: .happy, tone: .cream)
            }
            .padding(.bottom, 22)

            Group {
                Text("Hallo, ich bin ")
                    .font(.display(42))
                + Text("Kcal-Kun")
                    .font(.displayItalic(42))
                    .foregroundStyle(Color.terra)
                + Text(".")
                    .font(.display(42))
            }
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, 28)
            .padding(.bottom, 14)

            Text("Ich helfe dir, deine Kalorien und Makros zu tracken. KI liest deine Etiketten — deine Daten bleiben lokal, ohne Account, ohne Cloud.")
                .font(.system(size: 16))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: — Step 1: Dein Ziel

    private var stepGoal: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "Schritt 2 von 4")
                    .padding(.bottom, 4)

                Group {
                    Text("Dein ")
                        .font(.display(36))
                    + Text("Ziel")
                        .font(.displayItalic(36))
                        .foregroundStyle(Color.terra)
                    + Text(".")
                        .font(.display(36))
                }
                .lineSpacing(4)
                .padding(.bottom, 6)

                Text("Was möchtest du erreichen?")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.bottom, 18)

                // Goal type selection
                VStack(spacing: 8) {
                    ForEach(goals, id: \.label) { opt in
                        goalCard(opt: opt, isSelected: goalSelectionKey == opt.label)
                    }
                }
                .padding(.bottom, 20)

                // Kcal slider card
                SectionLabel(text: "Grundumsatz")
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Int(kcalGoal).formatted())
                            .font(.display(78))
                            .foregroundStyle(Color.inkPrimary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.2), value: kcalGoal)
                        Text("kcal")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    Slider(value: $kcalGoal, in: 1400...3500, step: 50)
                        .tint(Color.terra)
                        .padding(.top, 6)
                    HStack {
                        Text("1'400")
                        Spacer()
                        Text("3'500")
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.top, 2)
                }
                .padding(20)
                .heroCardStyle()
                .padding(.bottom, 20)

                // Delta slider (Defizit / Überschuss)
                if !isMaintenanceGoal {
                    SectionLabel(text: selectedGoal == .deficit ? "Kaloriendefizit" : "Kalorienüberschuss")
                        .padding(.bottom, 8)

                    VStack(spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(selectedGoal == .deficit ? "−" : "+")
                                .font(.display(42))
                                .foregroundStyle(Color.inkTertiary)
                            Text(Int(kcalDelta).formatted())
                                .font(.display(54))
                                .foregroundStyle(selectedGoal == .deficit ? Color.forest : Color.terra)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.2), value: kcalDelta)
                            Text("kcal")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.inkSecondary)
                        }
                        Text("→ Tagesziel: \(Int(derivedTagesziel).formatted()) kcal")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.inkSecondary)
                            .padding(.bottom, 4)
                        Slider(value: $kcalDelta, in: 100...800, step: 50)
                            .tint(selectedGoal == .deficit ? Color.forest : Color.terra)
                        HStack {
                            Text("100")
                            Spacer()
                            Text("800")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.top, 2)
                    }
                    .padding(20)
                    .heroCardStyle()
                    .padding(.bottom, 20)
                    .animation(.spring(response: 0.3), value: isMaintenanceGoal)
                }

                // Apple Watch hint
                HStack(spacing: 10) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.terra)
                    Text("Dein Tagesziel erhöht sich automatisch um aufgezeichnete Aktivitäten (Apple Watch, 10% Abzug der verbrannten Kalorien).")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.beige.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.bottom, 20)

                // Activity level
                SectionLabel(text: "Aktivitätsniveau")
                    .padding(.bottom, 8)

                VStack(spacing: 8) {
                    ForEach(activities, id: \.id) { opt in
                        let selected = activity == opt.id
                        Button {
                            withAnimation(.spring(response: 0.2)) { activity = opt.id }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(opt.label)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.inkPrimary)
                                    Text(opt.desc)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.inkSecondary)
                                }
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.warmBrown)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(selected ? Color.beige : Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(selected ? Color.warmBrown : Color(hex: 0x7C5E3C).opacity(0.10), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
    }

    // Goal card helper
    @ViewBuilder
    private func goalCard(opt: (type: GoalType, icon: String, label: String, desc: String), isSelected: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.2)) {
                goalSelectionKey = opt.label
                selectedGoal = opt.type
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: opt.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.terra : Color.inkTertiary)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(opt.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Text(opt.desc)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.warmBrown)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(isSelected ? Color.beige : Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.warmBrown : Color(hex: 0x7C5E3C).opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // Track which goal card label is selected (handles the two .deficit entries)
    @State private var goalSelectionKey: String = "Abnehmen"

    // MARK: — Step 2: Ernährungsstil

    private var stepDiet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "Schritt 3 von 5")
                    .padding(.bottom, 4)

                Group {
                    Text("Dein ")
                        .font(.display(36))
                    + Text("Stil")
                        .font(.displayItalic(36))
                        .foregroundStyle(Color.terra)
                    + Text(".")
                        .font(.display(36))
                }
                .lineSpacing(4)
                .padding(.bottom, 6)

                Text("Wie ernährst du dich am liebsten?")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.bottom, 18)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(DietStyle.allCases, id: \.self) { style in
                        dietStyleCard(style)
                    }
                }
                .padding(.bottom, 12)

                Text("Splits basieren auf DGE, ISSN, AHA und Mediterran-Diätforschung.")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private func dietStyleCard(_ style: DietStyle) -> some View {
        let selected = selectedDietStyle == style
        Button {
            withAnimation(.spring(response: 0.2)) { selectedDietStyle = style }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: style.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(selected ? Color.terra : Color.inkTertiary)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
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

    // MARK: — Step 3: Dein Avatar

    private var stepAvatar: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(text: "Schritt 3 von 4")
                    .padding(.bottom, 4)

                Group {
                    Text("Dein ")
                        .font(.display(36))
                    + Text("Avatar")
                        .font(.displayItalic(36))
                        .foregroundStyle(Color.terra)
                    + Text(".")
                        .font(.display(36))
                }
                .lineSpacing(4)
                .padding(.bottom, 6)

                Text("Wähle deinen Kcal-Kun oder lade ein Foto hoch.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.bottom, 24)

                // Mascot tone selector
                SectionLabel(text: "Kcal-Kun Maskot")
                    .padding(.bottom, 10)

                HStack(spacing: 10) {
                    ForEach(mascotTones, id: \.id) { option in
                        let selected = avatarMode == .mascot && mascotTone == option.id
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                mascotTone = option.id
                                avatarMode = .mascot
                                selectedPhotoData = nil
                            }
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
                .padding(.bottom, 24)

                // Photo upload
                SectionLabel(text: "Oder: Eigenes Foto")
                    .padding(.bottom, 10)

                Button {
                    showImagePicker = true
                } label: {
                    HStack(spacing: 14) {
                        if let data = selectedPhotoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.terra, lineWidth: 2))
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.beige)
                                    .frame(width: 56, height: 56)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.warmBrown)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedPhotoData != nil ? "Foto gewählt" : "Foto hochladen")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.inkPrimary)
                            Text(selectedPhotoData != nil ? "Tippe zum Ändern" : "Aus Fotobibliothek wählen")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.inkSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.inkTertiary)
                    }
                    .padding(14)
                    .background(avatarMode == .photo ? Color.beige : Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(avatarMode == .photo ? Color.warmBrown : Color(hex: 0x7C5E3C).opacity(0.10), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
    }

    // MARK: — Step 3: Bereit

    private var stepReady: some View {
        VStack(spacing: 0) {
            // Avatar preview
            ZStack {
                Circle()
                    .stroke(Color.forest.opacity(0.4), lineWidth: 14)
                    .frame(width: 160, height: 160)

                if let data = selectedPhotoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    MascotView(size: 90, mood: .smug, tone: toneEnum(mascotTone), tilt: -4)
                }
            }
            .padding(.bottom, 20)

            Group {
                Text("Bereit, ")
                    .font(.display(36))
                + Text("loszulegen")
                    .font(.displayItalic(36))
                    .foregroundStyle(Color.terra)
                + Text(".")
                    .font(.display(36))
            }
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, 28)
            .padding(.bottom, 16)

            // Summary card
            VStack(spacing: 10) {
                summaryRow(icon: "bolt.fill", label: "Grundumsatz", value: "\(Int(kcalGoal).formatted()) kcal")
                if !isMaintenanceGoal {
                    Divider().overlay(Color.inkDivider)
                    summaryRow(
                        icon: selectedGoal == .deficit ? "minus.circle.fill" : "plus.circle.fill",
                        label: selectedGoal == .deficit ? "Defizit" : "Überschuss",
                        value: "\(Int(effectiveDelta).formatted()) kcal"
                    )
                }
                Divider().overlay(Color.inkDivider)
                summaryRow(icon: "flame.fill", label: "Tagesziel", value: "\(Int(derivedTagesziel).formatted()) kcal")
                Divider().overlay(Color.inkDivider)
                summaryRow(icon: "target",      label: "Ziel",             value: goalLabel)
                Divider().overlay(Color.inkDivider)
                summaryRow(icon: selectedDietStyle.icon, label: "Ernährungsstil", value: selectedDietStyle.label)
                Divider().overlay(Color.inkDivider)
                summaryRow(icon: "figure.walk", label: "Aktivität",        value: activityLabel)
            }
            .padding(16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
            .padding(.horizontal, 28)
            .padding(.bottom, 12)

            Text("Grösse, Gewicht, Körperfett und weitere Daten kannst du jederzeit in den Einstellungen anpassen.")
                .font(.system(size: 13))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.terra)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
        }
    }

    private var isMaintenanceGoal: Bool { goalSelectionKey == "Gewicht halten" }

    private var effectiveDelta: Double { isMaintenanceGoal ? 0 : kcalDelta }

    private var derivedTagesziel: Double {
        isMaintenanceGoal ? kcalGoal : (selectedGoal == .deficit ? kcalGoal - kcalDelta : kcalGoal + kcalDelta)
    }

    private var goalLabel: String { goalSelectionKey }

    private var activityLabel: String {
        switch activity {
        case "low":  return "Wenig aktiv"
        case "high": return "Sehr aktiv"
        default:     return "Moderat"
        }
    }

    private func toneEnum(_ id: String) -> MascotTone {
        switch id {
        case "terra": return .terra
        case "beige": return .beige
        default:      return .cream
        }
    }

    // MARK: — Persist & complete

    private func finishOnboarding() {
        let profile = profiles.first ?? {
            let p = UserProfile()
            modelContext.insert(p)
            return p
        }()
        profile.bmr       = kcalGoal
        profile.kcalDelta = effectiveDelta
        profile.goalType  = selectedGoal
        profile.dietStyle = selectedDietStyle
        profile.photoData = selectedPhotoData
        try? modelContext.save()

        savedMascotTone = mascotTone
        hasCompletedOnboarding = true
    }
}
