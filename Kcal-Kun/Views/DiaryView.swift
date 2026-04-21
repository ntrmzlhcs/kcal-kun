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
    @State private var entryToCopy: DiaryEntry? = nil
    @State private var showExportOptions = false

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
                                Button { selectedEntry = entry } label: {
                                    DiaryEntryRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .leading) {
                                    Button {
                                        entryToCopy = entry
                                    } label: {
                                        Label("Kopieren", systemImage: "doc.on.doc")
                                    }
                                    .tint(.blue)
                                }
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
                    Button { showProfile = true } label: { avatarView }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showExportOptions = true } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(allEntries.isEmpty)
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
            .sheet(item: $entryToCopy) { entry in
                let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                CopyEntriesSheet(entries: [entry], defaultDate: nextDay) {
                    entryToCopy = nil
                }
            }
            .confirmationDialog("Exportieren", isPresented: $showExportOptions, titleVisibility: .visible) {
                Button("Heute") { exportCSV(entries: dayEntries, label: "heute") }
                Button("Letzte 7 Tage") {
                    let cutoff = Calendar.current.date(byAdding: .day, value: -6, to: selectedDate)!
                    exportCSV(entries: allEntries.filter { $0.date >= cutoff }, label: "7-tage")
                }
                Button("Letzte 30 Tage") {
                    let cutoff = Calendar.current.date(byAdding: .day, value: -29, to: selectedDate)!
                    exportCSV(entries: allEntries.filter { $0.date >= cutoff }, label: "30-tage")
                }
                Button("Alle Daten") { exportCSV(entries: allEntries, label: "alle") }
                Button("Abbrechen", role: .cancel) {}
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

    private func generateCSV(entries: [DiaryEntry]) -> String {
        var lines = ["Datum,Mahlzeit,Produkt,Gramm,Einheit,Kcal,Protein,Fett,Kohlenhydrate,Ballaststoffe"]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for entry in entries.sorted(by: { $0.date == $1.date ? $0.mealSlot.rawValue < $1.mealSlot.rawValue : $0.date < $1.date }) {
            let name = (entry.product?.name ?? entry.productName)
                .replacingOccurrences(of: ",", with: ";")
            lines.append([
                formatter.string(from: entry.date),
                entry.mealSlot.rawValue,
                name,
                String(format: "%.1f", entry.grams),
                entry.unit,
                String(format: "%.0f", entry.kcal),
                String(format: "%.1f", entry.protein),
                String(format: "%.1f", entry.fat),
                String(format: "%.1f", entry.carbs),
                String(format: "%.1f", entry.fiber)
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private func exportCSV(entries: [DiaryEntry], label: String) {
        let csv = generateCSV(entries: entries)
        let filename = "Kcal-Kun-\(label).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? csv.write(to: url, atomically: true, encoding: .utf8)

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        var presentingVC = rootVC
        while let presented = presentingVC.presentedViewController {
            presentingVC = presented
        }
        presentingVC.present(activityVC, animated: true)
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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var gramsText = ""

    private var product: Product? { entry.product }
    private var displayName: String {
        product?.name ?? (entry.productName.isEmpty ? "Unbekannt" : entry.productName)
    }
    private var currentGrams: Double {
        Double(gramsText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    private var factor: Double { currentGrams / 100.0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Portion")
                        Spacer()
                        TextField("Menge", text: $gramsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(entry.unit)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Nährwerte (Portion)") {
                    if let p = product {
                        macroRow("Energie",       value: p.kcalPer100g    * factor, unit: "kcal")
                        macroRow("Protein",       value: p.proteinPer100g * factor, unit: "g")
                        macroRow("Kohlenhydrate", value: p.carbsPer100g   * factor, unit: "g")
                        if let sugar = p.sugarPer100g {
                            macroRow("  davon Zucker", value: sugar * factor, unit: "g")
                        }
                        macroRow("Fett",          value: p.fatPer100g     * factor, unit: "g")
                        if let fiber = p.fiberPer100g {
                            macroRow("Ballaststoffe",  value: fiber * factor, unit: "g")
                        }
                        if let salt = p.saltPer100g {
                            macroRow("Salz",           value: salt  * factor, unit: "g")
                        }
                    } else {
                        macroRow("Energie",       value: entry.kcal,    unit: "kcal")
                        macroRow("Protein",       value: entry.protein, unit: "g")
                        macroRow("Kohlenhydrate", value: entry.carbs,   unit: "g")
                        macroRow("Fett",          value: entry.fat,     unit: "g")
                        macroRow("Ballaststoffe", value: entry.fiber,   unit: "g")
                    }
                }

                if let p = product {
                    Section("Pro 100 \(entry.unit)") {
                        macroRow("Energie",         value: p.kcalPer100g,    unit: "kcal")
                        macroRow("Protein",         value: p.proteinPer100g, unit: "g")
                        macroRow("Kohlenhydrate",   value: p.carbsPer100g,   unit: "g")
                        if let sugar = p.sugarPer100g {
                            macroRow("  davon Zucker", value: sugar, unit: "g")
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .disabled(currentGrams <= 0)
                }
            }
            .onAppear {
                let g = entry.grams
                gramsText = g.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(g)) : String(format: "%.1f", g)
            }
        }
    }

    private func save() {
        entry.grams = currentGrams
        if let p = entry.product {
            let f = currentGrams / 100.0
            entry.kcal    = p.kcalPer100g    * f
            entry.protein = p.proteinPer100g * f
            entry.fat     = p.fatPer100g     * f
            entry.carbs   = p.carbsPer100g   * f
            entry.fiber   = (p.fiberPer100g ?? 0) * f
        }
        try? modelContext.save()
        dismiss()
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

