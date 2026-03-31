import SwiftUI
import SwiftData

struct ManualProductEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var carbs = ""
    @State private var fiber = ""
    @State private var sugar = ""
    @State private var salt = ""
    @State private var showOptional = false
    @FocusState private var nameFocused: Bool

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        parseDouble(kcal) != nil &&
        parseDouble(protein) != nil &&
        parseDouble(fat) != nil &&
        parseDouble(carbs) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Produkt") {
                    TextField("Name (Pflichtfeld)", text: $name)
                        .focused($nameFocused)
                }

                Section("Nährwerte pro 100 g") {
                    nutritionField("Kalorien (kcal)", value: $kcal)
                    nutritionField("Protein (g)", value: $protein)
                    nutritionField("Fett (g)", value: $fat)
                    nutritionField("Kohlenhydrate (g)", value: $carbs)
                }

                Section {
                    DisclosureGroup("Weitere Nährwerte", isExpanded: $showOptional) {
                        nutritionField("Ballaststoffe (g)", value: $fiber, required: false)
                        nutritionField("Zucker (g)", value: $sugar, required: false)
                        nutritionField("Salz (g)", value: $salt, required: false)
                    }
                }
            }
            .navigationTitle("Produkt erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { saveAndDismiss() }
                        .disabled(!canSave)
                }
            }
            .onAppear { nameFocused = true }
        }
    }

    @ViewBuilder
    private func nutritionField(_ label: String, value: Binding<String>, required: Bool = true) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(required ? "Pflichtfeld" : "optional", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .foregroundStyle(
                    required && parseDouble(value.wrappedValue) == nil && !value.wrappedValue.isEmpty
                    ? Color.red : Color.primary
                )
        }
    }

    private func saveAndDismiss() {
        guard let kcalVal = parseDouble(kcal),
              let proteinVal = parseDouble(protein),
              let fatVal = parseDouble(fat),
              let carbsVal = parseDouble(carbs) else { return }

        let product = Product(
            name: name.trimmingCharacters(in: .whitespaces),
            kcalPer100g: kcalVal,
            proteinPer100g: proteinVal,
            fatPer100g: fatVal,
            carbsPer100g: carbsVal,
            fiberPer100g: parseDouble(fiber),
            sugarPer100g: parseDouble(sugar),
            saltPer100g: parseDouble(salt),
            source: .manual
        )
        modelContext.insert(product)
        try? modelContext.save()
        dismiss()
    }
}

private func parseDouble(_ text: String) -> Double? {
    let normalized = text.replacingOccurrences(of: ",", with: ".")
    guard !normalized.isEmpty else { return nil }
    return Double(normalized)
}
