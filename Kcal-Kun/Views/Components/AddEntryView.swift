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

    // MARK: - Filtered lists

    private var isSearching: Bool { !searchText.isEmpty }

    private var favorites: [Product] {
        let base = allProducts.filter { $0.isFavorite }
        guard isSearching else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var myProducts: [Product] {
        let base = allProducts.filter { $0.source == .ocr || $0.source == .manual }
        guard isSearching else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var databaseProducts: [Product] {
        guard isSearching else { return [] }
        return allProducts.filter {
            $0.source == .preloaded && $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Gram parsing

    private var grams: Double? {
        let normalized = gramsText.replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private var canAdd: Bool {
        selectedProduct != nil && (grams ?? 0) > 0
    }

    // MARK: - Body

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
        List {
            if !favorites.isEmpty {
                Section("Favoriten") {
                    ForEach(favorites) { product in
                        productRow(product)
                    }
                }
            }

            if !myProducts.isEmpty {
                Section("Meine Produkte") {
                    ForEach(myProducts) { product in
                        productRow(product)
                    }
                }
            }

            if isSearching {
                if !databaseProducts.isEmpty {
                    Section("Datenbank") {
                        ForEach(databaseProducts) { product in
                            productRow(product)
                        }
                    }
                }
            } else if favorites.isEmpty && myProducts.isEmpty {
                Section {
                    Text("Suche in der Datenbank, um generische Lebensmittel zu finden (z. B. «Brokkoli», «Lachs»).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Suchen (Brokkoli, Lachs, ...)")
        .navigationTitle("Produkt wählen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
        }
    }

    private func productRow(_ product: Product) -> some View {
        HStack {
            Button {
                selectedProduct = product
                gramsText = ""
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Text("\(Int(product.kcalPer100g)) kcal / 100g")
                        if product.source == .ocr {
                            Text("· Gescannt").foregroundStyle(.blue)
                        } else if product.source == .manual {
                            Text("· Manuell").foregroundStyle(.purple)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                product.isFavorite.toggle()
            } label: {
                Image(systemName: product.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(product.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
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
