import SwiftUI
import SwiftData

struct DiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var healthKit
    @Query private var allEntries: [DiaryEntry]
    @Query private var profiles: [UserProfile]

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var activeSheet: MealSlot? = nil
    @State private var showProfile = false
    @State private var selectedEntry: DiaryEntry? = nil
    @State private var isSelecting = false
    @State private var selectedEntryIDs: Set<PersistentIdentifier> = []
    @State private var showCopySheet = false

    private var profile: UserProfile? { profiles.first }

    private var dayEntries: [DiaryEntry] {
        allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private func entries(for slot: MealSlot) -> [DiaryEntry] {
        dayEntries.filter { $0.mealSlot == slot }
    }

    private var totalKcal: Double {
        dayEntries.reduce(0) { $0 + $1.kcal }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    // Date navigator
                    Section {
                        DateNavigator(selectedDate: $selectedDate)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    // Kcal summary / progress
                    Section {
                        if let profile {
                            KcalProgressView(
                                consumed: totalKcal,
                                profile: profile,
                                workoutKcal: healthKit.workoutKcal
                            )
                        } else {
                            KcalSummaryCard(kcal: totalKcal)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    // Meal slots
                    ForEach(MealSlot.allCases) { slot in
                        let slotEntries = entries(for: slot)
                        let slotKcal = slotEntries.reduce(0) { $0 + $1.kcal }

                        Section {
                            ForEach(slotEntries) { entry in
                                Button {
                                    if isSelecting {
                                        let id = entry.persistentModelID
                                        if selectedEntryIDs.contains(id) { selectedEntryIDs.remove(id) }
                                        else { selectedEntryIDs.insert(id) }
                                    } else {
                                        selectedEntry = entry
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        if isSelecting {
                                            let selected = selectedEntryIDs.contains(entry.persistentModelID)
                                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selected ? .blue : .secondary)
                                                .font(.title3)
                                        }
                                        DiaryEntryRow(entry: entry)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { indexSet in
                                deleteEntries(slotEntries, at: indexSet)
                            }

                            Button {
                                activeSheet = slot
                            } label: {
                                Label("Hinzufügen", systemImage: "plus.circle")
                                    .foregroundStyle(.tint)
                            }
                        } header: {
                            HStack {
                                Label(slot.rawValue, systemImage: slot.systemImage)
                                Spacer()
                                if slotKcal > 0 {
                                    Text("\(Int(slotKcal)) kcal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tagebuch")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isSelecting {
                        Button("Kopieren (\(selectedEntryIDs.count))") { showCopySheet = true }
                            .disabled(selectedEntryIDs.isEmpty)
                    } else {
                        Button { showProfile = true } label: { avatarView }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelecting {
                        Button("Abbrechen") {
                            isSelecting = false
                            selectedEntryIDs = []
                        }
                    } else {
                        Button("Auswählen") { isSelecting = true }
                            .disabled(dayEntries.isEmpty)
                    }
                }
            }
            .sheet(item: $activeSheet) { slot in
                AddEntryView(selectedDate: selectedDate, initialSlot: slot)
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(item: $selectedEntry) { entry in
                DiaryEntryDetailSheet(entry: entry)
            }
            .sheet(isPresented: $showCopySheet) {
                let entriesToCopy = dayEntries.filter { selectedEntryIDs.contains($0.persistentModelID) }
                let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                CopyEntriesSheet(entries: entriesToCopy, defaultDate: nextDay) {
                    isSelecting = false
                    selectedEntryIDs = []
                }
            }
            .onChange(of: selectedDate) { _, _ in
                if isSelecting { isSelecting = false; selectedEntryIDs = [] }
            }
            .onAppear {
                let stale = allEntries.filter { $0.productName.isEmpty && $0.product != nil }
                if !stale.isEmpty {
                    for entry in stale { entry.productName = entry.product!.name }
                    try? modelContext.save()
                }
            }
            .task(id: selectedDate) {
                await healthKit.fetchWorkoutKcal(for: selectedDate)
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let data = profile?.photoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    private func deleteEntries(_ slotEntries: [DiaryEntry], at indexSet: IndexSet) {
        for index in indexSet {
            modelContext.delete(slotEntries[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Subviews

private struct KcalSummaryCard: View {
    let kcal: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Kalorien")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(Int(kcal)) kcal")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
            }
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange.gradient)
        }
        .padding()
    }
}

private struct DiaryEntryDetailSheet: View {
    let entry: DiaryEntry
    @Environment(\.dismiss) private var dismiss

    private var product: Product? { entry.product }
    private var displayName: String {
        product?.name ?? (entry.productName.isEmpty ? "Unbekannt" : entry.productName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Portion") {
                        Text("\(formatAmount(entry.grams)) \(entry.unit)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Nährwerte (Portion)") {
                    macroRow("Energie",         value: entry.kcal,    unit: "kcal")
                    macroRow("Protein",         value: entry.protein, unit: "g")
                    macroRow("Kohlenhydrate",   value: entry.carbs,   unit: "g")
                    if let sugar = product?.sugarPer100g {
                        macroRow("  davon Zucker", value: sugar * entry.grams / 100, unit: "g")
                    }
                    macroRow("Fett",            value: entry.fat,     unit: "g")
                    macroRow("Ballaststoffe",   value: entry.fiber,   unit: "g")
                    if let salt = product?.saltPer100g {
                        macroRow("Salz",        value: salt * entry.grams / 100, unit: "g")
                    }
                }

                if let p = product {
                    Section("Pro 100 \(entry.unit)") {
                        macroRow("Energie",         value: p.kcalPer100g,    unit: "kcal")
                        macroRow("Protein",         value: p.proteinPer100g, unit: "g")
                        macroRow("Kohlenhydrate",   value: p.carbsPer100g,   unit: "g")
                        if let sugar = p.sugarPer100g {
                            macroRow("  davon Zucker", value: sugar,          unit: "g")
                        }
                        macroRow("Fett",            value: p.fatPer100g,     unit: "g")
                        if let fiber = p.fiberPer100g {
                            macroRow("Ballaststoffe", value: fiber,           unit: "g")
                        }
                        if let salt = p.saltPer100g {
                            macroRow("Salz",          value: salt,            unit: "g")
                        }
                    }
                }
            }
            .navigationTitle(displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func macroRow(_ label: String, value: Double, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(String(format: "%.1f", value)) \(unit)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func formatAmount(_ g: Double) -> String {
        g.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(g)) : String(format: "%.1f", g)
    }
}

private struct DiaryEntryRow: View {
    let entry: DiaryEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.product?.name ?? (entry.productName.isEmpty ? "Unbekannt" : entry.productName))
                Text("\(formatGrams(entry.grams)) \(entry.unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(entry.kcal.rounded())) kcal")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func formatGrams(_ g: Double) -> String {
        g.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(g)) : String(format: "%.1f", g)
    }
}

// MARK: - CopyEntriesSheet

private struct CopyEntriesSheet: View {
    struct CopyItem: Identifiable {
        let id = UUID()
        let entry: DiaryEntry
        var gramsText: String

        init(_ entry: DiaryEntry) {
            self.entry = entry
            let g = entry.grams
            gramsText = g.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(g)) : String(format: "%.1f", g)
        }

        var isAvailable: Bool { entry.product != nil }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entries: [DiaryEntry]
    let defaultDate: Date
    let onDone: () -> Void

    @State private var targetDate: Date
    @State private var items: [CopyItem]

    init(entries: [DiaryEntry], defaultDate: Date, onDone: @escaping () -> Void) {
        self.entries = entries
        self.defaultDate = defaultDate
        self.onDone = onDone
        _targetDate = State(initialValue: defaultDate)
        _items = State(initialValue: entries.map { CopyItem($0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Zieldatum") {
                    DatePicker("Datum", selection: $targetDate, displayedComponents: .date)
                }

                Section("Einträge") {
                    ForEach($items) { $item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.entry.product?.name ?? (item.entry.productName.isEmpty ? "Unbekannt" : item.entry.productName))
                                    .font(.body)
                                    .foregroundStyle(item.isAvailable ? .primary : .secondary)
                                Label(item.entry.mealSlot.rawValue, systemImage: item.entry.mealSlot.systemImage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if item.isAvailable {
                                TextField("Menge", text: $item.gramsText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                Text(item.entry.unit)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Produkt gelöscht")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Kopieren nach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kopieren") { copyEntries() }
                        .disabled(!items.contains { $0.isAvailable })
                }
            }
        }
    }

    private func copyEntries() {
        let targetDay = Calendar.current.startOfDay(for: targetDate)
        for item in items {
            guard let product = item.entry.product else { continue }
            let normalized = item.gramsText.replacingOccurrences(of: ",", with: ".")
            let grams = Double(normalized) ?? item.entry.grams
            guard grams > 0 else { continue }
            let newEntry = DiaryEntry(
                date: targetDay,
                mealSlot: item.entry.mealSlot,
                product: product,
                grams: grams,
                unit: item.entry.unit
            )
            modelContext.insert(newEntry)
        }
        try? modelContext.save()
        onDone()
        dismiss()
    }
}
