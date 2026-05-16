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
    @State private var useMl = false
    @State private var selectedSlot: MealSlot
    @State private var showManualEntry = false
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
        let base = allProducts.filter { $0.source == .ocr || $0.source == .manual || $0.source == .dish }
        guard isSearching else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var databaseProducts: [Product] {
        guard isSearching else { return [] }
        return allProducts.filter {
            $0.source == .preloaded && $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

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
        ZStack {
            Color.appBackground.ignoresSafeArea()
            List {
                if !favorites.isEmpty {
                    Section {
                        ForEach(favorites) { product in
                            productRow(product)
                        }
                    } header: {
                        SectionLabel(text: "Favoriten").padding(.top, 4)
                    }
                    .listRowBackground(Color.cardBackground)
                    .listRowSeparatorTint(Color.inkDivider)
                }

                if !myProducts.isEmpty {
                    Section {
                        ForEach(myProducts) { product in
                            productRow(product)
                        }
                    } header: {
                        SectionLabel(text: "Meine Produkte").padding(.top, 4)
                    }
                    .listRowBackground(Color.cardBackground)
                    .listRowSeparatorTint(Color.inkDivider)
                }

                if isSearching {
                    if !databaseProducts.isEmpty {
                        Section {
                            ForEach(databaseProducts) { product in
                                productRow(product)
                            }
                        } header: {
                            SectionLabel(text: "Datenbank").padding(.top, 4)
                        }
                        .listRowBackground(Color.cardBackground)
                        .listRowSeparatorTint(Color.inkDivider)
                    }
                } else if favorites.isEmpty && myProducts.isEmpty {
                    Section {
                        HStack(spacing: 10) {
                            MascotView(size: 24, mood: .think, tone: .beige)
                            Text("Suche in der Datenbank, um generische Lebensmittel zu finden (z. B. «Brokkoli», «Lachs»).")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.inkSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.cardBackground)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .searchable(text: $searchText, prompt: "Suchen (Brokkoli, Lachs, ...)")
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Produkt wählen")
                    .font(.display(18))
                    .foregroundStyle(Color.inkPrimary)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
                    .foregroundStyle(Color.warmBrown)
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showManualEntry = true } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.warmBrown)
                }
            }
        }
        .sheet(isPresented: $showManualEntry) {
            ManualProductEntryView()
        }
    }

    private func productRow(_ product: Product) -> some View {
        HStack(spacing: 12) {
            Button {
                selectedProduct = product
                gramsText = ""
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(product.source == .preloaded ? Color.beige : Color.terra.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Text(String(product.name.prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.warmBrown)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        HStack(spacing: 4) {
                            Text("\(Int(product.kcalPer100g)) kcal / 100g")
                                .foregroundStyle(Color.inkSecondary)
                            sourceTag(for: product)
                        }
                        .font(.system(size: 11))
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                product.isFavorite.toggle()
            } label: {
                Image(systemName: product.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(product.isFavorite ? Color.amber : Color.inkTertiary)
                    .font(.system(size: 15))
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func sourceTag(for product: Product) -> some View {
        switch product.source {
        case .ocr:    Text("· Gescannt").foregroundStyle(Color.terra)
        case .dish:   Text("· Gericht").foregroundStyle(Color.forest)
        case .manual: Text("· Manuell").foregroundStyle(Color.warmBrown)
        default:      EmptyView()
        }
    }

    // MARK: - Phase 2: Details eingeben

    private func detailsView(product: Product) -> some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Product card
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.terra.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Text(String(product.name.prefix(1)).uppercased())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.warmBrown)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.inkPrimary)
                            Text("\(Int(product.kcalPer100g)) kcal / 100g")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.inkSecondary)
                        }
                        Spacer()
                        Button("Ändern") {
                            selectedProduct = nil
                            searchText = ""
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.warmBrown)
                    }
                    .padding(14)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))

                    // Amount card
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Menge")
                        VStack(spacing: 0) {
                            HStack(spacing: 10) {
                                TextField(useMl ? "Milliliter" : "Gramm", text: $gramsText)
                                    .keyboardType(.decimalPad)
                                    .focused($gramsFocused)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.inkPrimary)
                                Picker("Einheit", selection: $useMl) {
                                    Text("g").tag(false)
                                    Text("ml").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 80)
                            }
                            .padding(14)

                            if let g = grams, g > 0 {
                                Divider().padding(.horizontal, 14)
                                let f = g / 100.0
                                HStack {
                                    macroPreviewPill("\(Int((product.kcalPer100g * f).rounded()))", label: "kcal", color: Color.terra)
                                    macroPreviewPill("\(fmt(product.proteinPer100g * f))g", label: "P", color: Color.terra)
                                    macroPreviewPill("\(fmt(product.fatPer100g * f))g", label: "F", color: Color.amber)
                                    macroPreviewPill("\(fmt(product.carbsPer100g * f))g", label: "KH", color: Color.forest)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            }
                        }
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
                    }

                    // Meal slot card
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Mahlzeit")
                        Picker("Mahlzeit", selection: $selectedSlot) {
                            ForEach(MealSlot.allCases) { slot in
                                Label(slot.rawValue, systemImage: slot.systemImage).tag(slot)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Add button
                    Button {
                        addEntry()
                    } label: {
                        Text("Hinzufügen")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canAdd ? Color.terra : Color.inkDivider)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(color: canAdd ? Color.terra.opacity(0.32) : .clear, radius: 18, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAdd)
                    .animation(.spring(response: 0.25), value: canAdd)

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Eintrag hinzufügen")
                    .font(.display(18))
                    .foregroundStyle(Color.inkPrimary)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
                    .foregroundStyle(Color.warmBrown)
            }
        }
        .onAppear { gramsFocused = true }
    }

    private func macroPreviewPill(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func addEntry() {
        guard let product = selectedProduct, let g = grams, g > 0 else { return }
        let entry = DiaryEntry(date: selectedDate, mealSlot: selectedSlot, product: product, grams: g, unit: useMl ? "ml" : "g")
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }

    private func fmt(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f", value) : String(Int(value.rounded()))
    }
}
