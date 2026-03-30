import SwiftUI
import SwiftData

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Product.name) private var allProducts: [Product]

    let selectedDate: Date
    let initialSlot: MealSlot

    @State private var selectedProduct: Product? = nil
    @State private var searchText = ""
    @State private var gramsText = ""
    @State private var selectedSlot: MealSlot
    @FocusState private var gramsFocused: Bool

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
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private var canAdd: Bool {
        selectedProduct != nil && (grams ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            if let product = selectedProduct {
                detailsView(product: product)
            } else {
                productPickerView
            }
        }
    }

    // MARK: - Phase 1: Produkt wählen

    private var productPickerView: some View {
        List(filteredProducts) { product in
            Button {
                selectedProduct = product
                gramsText = ""
                gramsFocused = true
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .foregroundStyle(.primary)
                    Text("\(Int(product.kcalPer100g)) kcal / 100g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Produkt suchen")
        .navigationTitle("Produkt wählen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
        }
    }

    // MARK: - Phase 2: Details eingeben

    private func detailsView(product: Product) -> some View {
        Form {
            Section("Produkt") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name)
                            .font(.headline)
                        Text("\(Int(product.kcalPer100g)) kcal / 100g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Ändern") {
                        selectedProduct = nil
                        searchText = ""
                    }
                    .font(.subheadline)
                }
            }

            Section("Menge") {
                HStack {
                    TextField("Gramm", text: $gramsText)
                        .keyboardType(.decimalPad)
                        .focused($gramsFocused)
                    Text("g")
                        .foregroundStyle(.secondary)
                }
                if let g = grams, g > 0 {
                    let f = g / 100.0
                    Text("\(Int((product.kcalPer100g * f).rounded())) kcal · \(fmt(product.proteinPer100g * f))g P · \(fmt(product.fatPer100g * f))g F · \(fmt(product.carbsPer100g * f))g KH")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Mahlzeit") {
                Picker("Mahlzeit", selection: $selectedSlot) {
                    ForEach(MealSlot.allCases) { slot in
                        Label(slot.rawValue, systemImage: slot.systemImage).tag(slot)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Eintrag hinzufügen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Hinzufügen") { addEntry() }
                    .disabled(!canAdd)
            }
        }
        .onAppear { gramsFocused = true }
    }

    // MARK: - Actions

    private func addEntry() {
        guard let product = selectedProduct, let g = grams, g > 0 else { return }
        let entry = DiaryEntry(date: selectedDate, mealSlot: selectedSlot, product: product, grams: g)
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }

    private func fmt(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f", value) : String(Int(value.rounded()))
    }
}
