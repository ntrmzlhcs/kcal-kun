import SwiftUI
import SwiftData

private struct ImagePickerWithCrop: UIViewControllerRepresentable {
    let onPick: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerWithCrop
        init(_ parent: ImagePickerWithCrop) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            if let jpeg = image?.jpegData(compressionQuality: 0.8) {
                parent.onPick(jpeg)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

@MainActor
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [UserProfile]

    @State private var heightText = ""
    @State private var weightText = ""
    @State private var bmrText = ""
    @State private var kcalDeltaText = ""
    @State private var goalType: GoalType = .deficit
    @State private var photoData: Data? = nil
    @State private var loaded = false
    @State private var showImagePicker = false

    private var profile: UserProfile? { profiles.first }

    private var canSave: Bool {
        parseDouble(heightText) != nil &&
        parseDouble(weightText) != nil &&
        parseDouble(bmrText) != nil &&
        parseDouble(kcalDeltaText) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Profilfoto
                Section {
                    HStack {
                        Spacer()
                        Button { showImagePicker = true } label: {
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
                    Picker("Ziel", selection: $goalType) {
                        Text("Kaloriendefizit").tag(GoalType.deficit)
                        Text("Massephase").tag(GoalType.surplus)
                    }
                    HStack {
                        Text(goalType == .deficit ? "Defizit" : "Überschuss")
                        Spacer()
                        TextField("kcal", text: $kcalDeltaText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Tagesziel")
                        Spacer()
                        if let bmr = parseDouble(bmrText), let delta = parseDouble(kcalDeltaText) {
                            let target = goalType == .deficit ? bmr - delta : bmr + delta
                            Text("\(Int(target)) kcal")
                                .foregroundStyle(.secondary)
                        }
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
            .fullScreenCover(isPresented: $showImagePicker) {
                ImagePickerWithCrop { data in
                    photoData = data
                }
                .ignoresSafeArea()
            }
            .onAppear {
                guard !loaded, let p = profile else { loaded = true; return }
                heightText    = formatDouble(p.heightCm)
                weightText    = formatDouble(p.weightKg)
                bmrText       = formatDouble(p.bmr)
                kcalDeltaText = formatDouble(p.kcalDelta)
                goalType      = p.goalType
                photoData      = p.photoData
                loaded         = true
            }
        }
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
        p.heightCm   = h
        p.weightKg   = w
        p.bmr        = b
        p.kcalDelta  = d
        p.goalType   = goalType
        p.photoData  = photoData
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
