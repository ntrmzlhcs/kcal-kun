import SwiftUI
import SwiftData

struct ScanConfirmationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let vm: ScannerViewModel
    let initialResult: NutritionScanResult

    @State private var name: String
    @State private var kcal: String
    @State private var protein: String
    @State private var fat: String
    @State private var carbs: String
    @State private var fiber: String
    @State private var sugar: String
    @State private var salt: String
    @State private var showOptional = false

    init(vm: ScannerViewModel, result: NutritionScanResult) {
        self.vm = vm
        self.initialResult = result
        _name = State(initialValue: result.productNameGuess ?? "")
        _kcal = State(initialValue: result.kcalPer100g.map { formatDouble($0) } ?? "")
        _protein = State(initialValue: result.proteinPer100g.map { formatDouble($0) } ?? "")
        _fat = State(initialValue: result.fatPer100g.map { formatDouble($0) } ?? "")
        _carbs = State(initialValue: result.carbsPer100g.map { formatDouble($0) } ?? "")
        _fiber = State(initialValue: result.fiberPer100g.map { formatDouble($0) } ?? "")
        _sugar = State(initialValue: result.sugarPer100g.map { formatDouble($0) } ?? "")
        _salt = State(initialValue: result.saltPer100g.map { formatDouble($0) } ?? "")
    }

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
            .navigationTitle("Produkt speichern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveAndDismiss()
                    }
                    .disabled(!canSave)
                }
            }
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
                    ? Color.red
                    : Color.primary
                )
        }
    }

    private func saveAndDismiss() {
        var result = initialResult
        result.kcalPer100g = parseDouble(kcal)
        result.proteinPer100g = parseDouble(protein)
        result.fatPer100g = parseDouble(fat)
        result.carbsPer100g = parseDouble(carbs)
        result.fiberPer100g = parseDouble(fiber)
        result.sugarPer100g = parseDouble(sugar)
        result.saltPer100g = parseDouble(salt)

        vm.saveProduct(
            name: name.trimmingCharacters(in: .whitespaces),
            result: result,
            context: modelContext
        )
        dismiss()
    }
}

private func formatDouble(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0
        ? String(Int(value))
        : String(format: "%.1f", value)
}

private func parseDouble(_ text: String) -> Double? {
    let normalized = text.replacingOccurrences(of: ",", with: ".")
    guard !normalized.isEmpty else { return nil }
    return Double(normalized)
}
