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
                    Button { showProfile = true } label: {
                        avatarView
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

    private var product: Product { entry.product }

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
                    if let sugar = product.sugarPer100g {
                        macroRow("  davon Zucker", value: sugar * entry.grams / 100, unit: "g")
                    }
                    macroRow("Fett",            value: entry.fat,     unit: "g")
                    macroRow("Ballaststoffe",   value: entry.fiber,   unit: "g")
                    if let salt = product.saltPer100g {
                        macroRow("Salz",        value: salt * entry.grams / 100, unit: "g")
                    }
                }

                Section("Pro 100 \(entry.unit)") {
                    macroRow("Energie",         value: product.kcalPer100g,    unit: "kcal")
                    macroRow("Protein",         value: product.proteinPer100g, unit: "g")
                    macroRow("Kohlenhydrate",   value: product.carbsPer100g,   unit: "g")
                    if let sugar = product.sugarPer100g {
                        macroRow("  davon Zucker", value: sugar,               unit: "g")
                    }
                    macroRow("Fett",            value: product.fatPer100g,     unit: "g")
                    if let fiber = product.fiberPer100g {
                        macroRow("Ballaststoffe", value: fiber,                unit: "g")
                    }
                    if let salt = product.saltPer100g {
                        macroRow("Salz",          value: salt,                 unit: "g")
                    }
                }
            }
            .navigationTitle(product.name)
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
                Text(entry.product.name)
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
