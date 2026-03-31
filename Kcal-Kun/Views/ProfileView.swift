import SwiftUI
import SwiftData
import PhotosUI
import Photos

@MainActor
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [UserProfile]

    @State private var heightText = ""
    @State private var weightText = ""
    @State private var bmrText = ""
    @State private var targetKcalText = ""
    @State private var goalType: GoalType = .deficit
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    @State private var loaded = false
    @State private var photoAccessLimited = false

    private var profile: UserProfile? { profiles.first }

    private var canSave: Bool {
        parseDouble(heightText) != nil &&
        parseDouble(weightText) != nil &&
        parseDouble(bmrText) != nil &&
        parseDouble(targetKcalText) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Profilfoto
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Group {
                                if let data = photoData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                if photoAccessLimited {
                    Section {
                        HStack {
                            Text("Fotobibliothek-Zugriff eingeschränkt.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Einstellungen") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption)
                        }
                    }
                }

                Section("Körperdaten") {
                    HStack {
                        Text("Grösse")
                        Spacer()
                        TextField("cm", text: $heightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Gewicht")
                        Spacer()
                        TextField("kg", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("Kalorien") {
                    HStack {
                        Text("Grundumsatz")
                        Spacer()
                        TextField("kcal", text: $bmrText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Zielkalorien / Tag")
                        Spacer()
                        TextField("kcal", text: $targetKcalText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    Picker("Ziel", selection: $goalType) {
                        Text("Kaloriendefizit").tag(GoalType.deficit)
                        Text("Massephase").tag(GoalType.surplus)
                    }
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                Task { @MainActor in
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
            .task {
                let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                if status == .notDetermined {
                    let new = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                    photoAccessLimited = (new == .limited)
                } else {
                    photoAccessLimited = (status == .limited)
                }
            }
            .onAppear {
                guard !loaded, let p = profile else { loaded = true; return }
                heightText     = formatDouble(p.heightCm)
                weightText     = formatDouble(p.weightKg)
                bmrText        = formatDouble(p.bmr)
                targetKcalText = formatDouble(p.targetKcal)
                goalType       = p.goalType
                photoData      = p.photoData
                loaded         = true
            }
        }
    }

    private func save() {
        guard let h = parseDouble(heightText),
              let w = parseDouble(weightText),
              let b = parseDouble(bmrText),
              let t = parseDouble(targetKcalText) else { return }

        let p = profile ?? {
            let newProfile = UserProfile()
            modelContext.insert(newProfile)
            return newProfile
        }()
        p.heightCm    = h
        p.weightKg    = w
        p.bmr         = b
        p.targetKcal  = t
        p.goalType    = goalType
        p.photoData   = photoData
        try? modelContext.save()
        dismiss()
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
