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

    @AppStorage("selectedMascotTone") private var savedMascotTone = "cream"

    private var profile: UserProfile? { profiles.first }

    private var mascotToneFromStorage: MascotTone {
        switch savedMascotTone {
        case "terra": return .terra
        case "beige": return .beige
        default:      return .cream
        }
    }

    private var dayEntries: [DiaryEntry] {
        allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private func entries(for slot: MealSlot) -> [DiaryEntry] {
        dayEntries.filter { $0.mealSlot == slot }
    }

    private var totalKcal:    Double { dayEntries.reduce(0) { $0 + $1.kcal } }
    private var totalProtein: Double { dayEntries.reduce(0) { $0 + $1.protein } }
    private var totalFat:     Double { dayEntries.reduce(0) { $0 + $1.fat } }
    private var totalCarbs:   Double { dayEntries.reduce(0) { $0 + $1.carbs } }

    private var effectiveTarget: Double {
        guard let p = profile else { return 2000 }
        let base = p.bmr + healthKit.workoutKcal
        return p.goalType == .deficit ? base - p.kcalDelta : base + p.kcalDelta
    }


    var body: some View {
        NavigationStack {
            List {
                // ── Date navigator ─────────────────────────────────
                Section {
                    DateNavigator(selectedDate: $selectedDate)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 4, trailing: 18))
                        .listRowSeparator(.hidden)
                }

                // ── Hero card ──────────────────────────────────────
                Section {
                    HeroKcalCard(
                        consumed: totalKcal,
                        target: effectiveTarget,
                        workoutKcal: healthKit.workoutKcal,
                        protein: totalProtein,
                        fat: totalFat,
                        carbs: totalCarbs,
                        profile: profile
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 18, bottom: 8, trailing: 18))
                    .listRowSeparator(.hidden)
                }

                // ── Meal slots ─────────────────────────────────────
                ForEach(MealSlot.allCases) { slot in
                    let slotEntries = entries(for: slot)
                    let slotKcal = slotEntries.reduce(0) { $0 + $1.kcal }

                    Section {
                        // Entry rows
                        ForEach(slotEntries) { entry in
                            Button { selectedEntry = entry } label: {
                                CozyEntryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.cardBackground)
                            .listRowSeparatorTint(Color.inkDivider)
                            .swipeActions(edge: .leading) {
                                Button {
                                    entryToCopy = entry
                                } label: {
                                    Label("Kopieren", systemImage: "doc.on.doc")
                                }
                                .tint(Color.warmBrown)
                            }
                        }
                        .onDelete { indexSet in
                            deleteEntries(slotEntries, at: indexSet)
                        }

                        // Empty state
                        if slotEntries.isEmpty {
                            HStack(spacing: 10) {
                                MascotView(size: 28, mood: .sleep, tone: .beige, tilt: -6)
                                Text("Schläft noch — füg etwas hinzu.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.inkSecondary)
                                    .italic()
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color.cardBackground)
                            .listRowSeparator(.hidden)
                        }

                        // Add button
                        Button {
                            activeSheet = slot
                        } label: {
                            Label("Hinzufügen", systemImage: "plus.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.terra)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.cardBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))

                    } header: {
                        CozyMealSectionHeader(slot: slot, slotKcal: slotKcal)
                    }
                    .listSectionSeparator(.hidden)
                }

                // Bottom padding for floating tab bar
                Section {
                    Color.clear
                        .frame(height: 90)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showProfile = true } label: { avatarView }
                }
                ToolbarItem(placement: .principal) {
                    Text("Tagebuch")
                        .font(.display(18))
                        .foregroundStyle(Color.inkPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showExportOptions = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.warmBrown)
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
            MascotView(size: 32, mood: .happy, tone: mascotToneFromStorage)
                .background(Color.beige.clipShape(Circle()))
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
        while let presented = presentingVC.presentedViewController { presentingVC = presented }
        presentingVC.present(activityVC, animated: true)
    }
}

// MARK: - Hero Kcal Card

private struct HeroKcalCard: View {
    let consumed: Double
    let target: Double
    let workoutKcal: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let profile: UserProfile?

    private var progress: Double { min(consumed / max(target, 1), 1.0) }
    private var remaining: Double { max(0, target - consumed) }
    private var kcalOverflow: Double {
        guard consumed > target else { return 0 }
        return (consumed - target) / max(target, 1)
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 20) {
                // Progress ring with kcal number inside
                ProgressRing(progress: progress, overflow: kcalOverflow, size: 148, strokeWidth: 12, color: .terra) {
                    AnyView(
                        VStack(spacing: 4) {
                            Text(Int(consumed).formatted())
                                .font(.display(44))
                                .foregroundStyle(Color.inkPrimary)
                                .monospacedDigit()
                            Text("kcal heute")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.4)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.inkSecondary)
                        }
                    )
                }

                // Stats column
                VStack(alignment: .leading, spacing: 6) {
                    StatRow(label: "Ziel", value: "\(Int(target).formatted())", unit: "kcal")
                    Divider().overlay(Color.inkDivider)
                    StatRow(label: "Übrig", value: "\(Int(remaining).formatted())", unit: "kcal", highlight: true)
                    Divider().overlay(Color.inkDivider)
                    StatRow(label: "Verbrannt", value: workoutKcal > 0 ? "+\(Int(workoutKcal))" : "—", unit: workoutKcal > 0 ? "kcal" : "", muted: workoutKcal == 0)
                }
            }

            // Macro mini-rings — goals derived from profile diet style
            HStack(spacing: 8) {
                MacroChip(label: "Protein", value: protein, goal: profile?.proteinGoal(kcal: target) ?? 150, color: .terra,  letter: "P")
                MacroChip(label: "KH",      value: carbs,   goal: profile?.carbGoal(kcal: target)    ?? 200, color: .forest, letter: "K")
                MacroChip(label: "Fett",    value: fat,     goal: profile?.fatGoal(kcal: target)     ?? 67,  color: .amber,  letter: "F")
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .heroCardStyle()
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    let unit: String
    var highlight = false
    var muted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color.inkSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.display(20))
                    .foregroundStyle(highlight ? Color.terra : muted ? Color.inkTertiary : Color.inkPrimary)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
    }
}

private struct MacroChip: View {
    let label: String
    let value: Double
    let goal: Double
    let color: Color
    let letter: String

    var body: some View {
        HStack(spacing: 8) {
            MiniRing(progress: value / max(goal, 1), color: color, letter: letter, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.inkSecondary)
                Text("\(Int(value))g")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.inkPrimary)
                Text("/ \(Int(goal))g")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Meal Section Header

private struct CozyMealSectionHeader: View {
    let slot: MealSlot
    let slotKcal: Double

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.beige)
                        .frame(width: 28, height: 28)
                    Image(systemName: slot.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.warmBrown)
                }
                Text(slot.rawValue)
                    .font(.display(16))
                    .foregroundStyle(Color.inkPrimary)
            }
            Spacer()
            if slotKcal > 0 {
                Text("\(Int(slotKcal)) kcal")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .textCase(nil)
        .listRowInsets(EdgeInsets())
    }
}

// MARK: - Entry Row

private struct CozyEntryRow: View {
    let entry: DiaryEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.product?.name ?? (entry.productName.isEmpty ? "Unbekannt" : entry.productName))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Text("\(formatGrams(entry.grams)) \(entry.unit)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkSecondary)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(entry.kcal.rounded()))")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.inkPrimary)
                Text("kcal")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    private func formatGrams(_ g: Double) -> String {
        g.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(g)) : String(format: "%.1f", g)
    }
}

// MARK: - KcalSummaryCard (no profile fallback)

private struct KcalSummaryCard: View {
    let kcal: Double

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "Kalorien heute")
                Text(Int(kcal).formatted())
                    .font(.display(48))
                    .foregroundStyle(Color.inkPrimary)
                    .monospacedDigit()
                Text("kcal")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkSecondary)
            }
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.terra.gradient)
        }
        .padding(24)
        .heroCardStyle()
    }
}

// MARK: - Diary Entry Detail Sheet (unchanged logic, design updated)

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
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Form {
                    Section {
                        HStack {
                            Text("Portion")
                                .foregroundStyle(Color.inkPrimary)
                            Spacer()
                            TextField("Menge", text: $gramsText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .foregroundStyle(Color.inkPrimary)
                            Text(entry.unit)
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }

                    Section("Nährwerte (Portion)") {
                        if let p = product {
                            macroRow("Energie",       value: p.kcalPer100g    * factor, unit: "kcal", color: .terra)
                            macroRow("Protein",       value: p.proteinPer100g * factor, unit: "g",    color: .terra)
                            macroRow("Kohlenhydrate", value: p.carbsPer100g   * factor, unit: "g",    color: .forest)
                            if let sugar = p.sugarPer100g {
                                macroRow("  davon Zucker", value: sugar * factor, unit: "g")
                            }
                            macroRow("Fett",          value: p.fatPer100g     * factor, unit: "g",    color: .amber)
                            if let fiber = p.fiberPer100g {
                                macroRow("Ballaststoffe", value: fiber * factor, unit: "g")
                            }
                            if let salt = p.saltPer100g {
                                macroRow("Salz",           value: salt  * factor, unit: "g")
                            }
                        } else {
                            macroRow("Energie",       value: entry.kcal,    unit: "kcal", color: .terra)
                            macroRow("Protein",       value: entry.protein, unit: "g",    color: .terra)
                            macroRow("Kohlenhydrate", value: entry.carbs,   unit: "g",    color: .forest)
                            macroRow("Fett",          value: entry.fat,     unit: "g",    color: .amber)
                            macroRow("Ballaststoffe", value: entry.fiber,   unit: "g")
                        }
                    }

                    if let p = product {
                        Section("Pro 100 \(entry.unit)") {
                            macroRow("Energie",         value: p.kcalPer100g,    unit: "kcal", color: .terra)
                            macroRow("Protein",         value: p.proteinPer100g, unit: "g",    color: .terra)
                            macroRow("Kohlenhydrate",   value: p.carbsPer100g,   unit: "g",    color: .forest)
                            if let sugar = p.sugarPer100g {
                                macroRow("  davon Zucker", value: sugar, unit: "g")
                            }
                            macroRow("Fett",            value: p.fatPer100g,     unit: "g",    color: .amber)
                            if let fiber = p.fiberPer100g {
                                macroRow("Ballaststoffe", value: fiber, unit: "g")
                            }
                            if let salt = p.saltPer100g {
                                macroRow("Salz",          value: salt,  unit: "g")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Color.terra)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .foregroundStyle(Color.terra)
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

    private func macroRow(_ label: String, value: Double, unit: String, color: Color = .inkPrimary) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", value))
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }
}

// MARK: - CopyEntriesSheet (unchanged logic, design tokens applied)

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
            ZStack {
                Color.appBackground.ignoresSafeArea()
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
                                        .foregroundStyle(item.isAvailable ? Color.inkPrimary : Color.inkSecondary)
                                    Label(item.entry.mealSlot.rawValue, systemImage: item.entry.mealSlot.systemImage)
                                        .font(.caption)
                                        .foregroundStyle(Color.inkSecondary)
                                }
                                Spacer()
                                if item.isAvailable {
                                    TextField("Menge", text: $item.gramsText)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 60)
                                    Text(item.entry.unit)
                                        .foregroundStyle(Color.inkSecondary)
                                } else {
                                    Text("Produkt gelöscht")
                                        .font(.caption)
                                        .foregroundStyle(Color.inkSecondary)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Kopieren nach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Color.terra)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kopieren") { copyEntries() }
                        .foregroundStyle(Color.terra)
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
