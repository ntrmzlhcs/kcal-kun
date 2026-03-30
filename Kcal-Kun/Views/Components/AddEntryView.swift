import SwiftUI
import SwiftData

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Product.name) private var allProducts: [Product]

    let selectedDate: Date
    let initialSlot: MealSlot

    @State private var searchText = ""
    @State private var selectedProduct: Product? = nil
    @State private var gramsText = ""
    @State private var selectedSlot: MealSlot

    init(selectedDate: Date, initialSlot: MealSlot) {
        self.selectedDate = selectedDate
        self.initialSlot = initialSlot
        _selectedSlot = State(initialValue: initialSlot)
    }

    private var filteredProducts: [Product] {
        if searchText.isEmpty { return allProducts }
        return allProducts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var grams: Double? {
        let normalized = gramsText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private var preview: (kcal: Double, protein: Double, fat: Double, carbs: Double)? {
        guard let product = selectedProduct, let g = grams, g > 0 else { return nil }
        let f = g / 100.0
        return (
            kcal:    product.kcalPer100g    * f,
            protein: product.proteinPer100g * f,
            fat:     product.fatPer100g     * f,
            carbs:   product.carbsPer100g   * f
        )
    }

    private var canAdd: Bool {
        selectedProduct != nil && grams != nil && (grams ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filteredProducts) { product in
                        Button {
                            selectedProduct = product
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.name)
                                        .foregroundStyle(.primary)
                                    Text("\(Int(product.kcalPer100g)) kcal / 100g")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedProduct?.id == product.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Produkt wählen")
                }

                if selectedProduct != nil {
                    Section {
                        HStack {
                            TextField("Gramm", text: $gramsText)
                                .keyboardType(.decimalPad)
                            Text("g")
                                .foregroundStyle(.secondary)
                        }
                        if let p = preview {
                            Text("\(Int(p.kcal)) kcal · \(formatMacro(p.protein))g P · \(formatMacro(p.fat))g F · \(formatMacro(p.carbs))g KH")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Menge")
                    }

                    Section {
                        Picker("Mahlzeit", selection: $selectedSlot) {
                            ForEach(MealSlot.allCases) { slot in
                                Label(slot.rawValue, systemImage: slot.systemImage)
                                    .tag(slot)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Mahlzeit")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Produkt suchen")
            .navigationTitle("Eintrag hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        addEntry()
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }

    private func addEntry() {
        guard let product = selectedProduct, let g = grams, g > 0 else { return }
        let entry = DiaryEntry(
            date: selectedDate,
            mealSlot: selectedSlot,
            product: product,
            grams: g
        )
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }

    private func formatMacro(_ value: Double) -> String {
        value < 10
            ? String(format: "%.1f", value)
            : String(Int(value.rounded()))
    }
}
