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
                                DiaryEntryRow(entry: entry)
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
