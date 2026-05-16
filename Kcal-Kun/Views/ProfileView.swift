import SwiftUI
import SwiftData

@MainActor
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitService.self) private var healthKit

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
        parseDouble(kcalDeltaText) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        avatarSection
                        bodyDataSection
                        caloriesSection
                        dietStyleSection
                        saveSection
                        onboardingResetSection
                        Spacer().frame(height: 24)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
            .onAppear {
                guard !loaded, let p = profile else { loaded = true; return }
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
                            Text("Ø 5 Messungen · HealthKit")
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
                        Text("Massephase").tag(GoalType.surplus)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

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
                Divider().padding(.leading, 14)

                if let bmr = parseDouble(bmrText), let delta = parseDouble(kcalDeltaText) {
                    let target = goalType == .deficit ? bmr - delta : bmr + delta
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
        guard let h = parseDouble(heightText),
              let w = parseDouble(weightText),
              let b = parseDouble(bmrText),
              let d = parseDouble(kcalDeltaText) else { return }

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
        try? modelContext.save()
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
