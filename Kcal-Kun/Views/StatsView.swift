import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query private var allEntries: [DiaryEntry]
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    private var dayEntries: [DiaryEntry] {
        allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var totals: MacroTotals {
        MacroTotals(
            kcal:    dayEntries.reduce(0) { $0 + $1.kcal },
            protein: dayEntries.reduce(0) { $0 + $1.protein },
            fat:     dayEntries.reduce(0) { $0 + $1.fat },
            carbs:   dayEntries.reduce(0) { $0 + $1.carbs },
            fiber:   dayEntries.reduce(0) { $0 + $1.fiber }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Date navigator
                    DateNavigator(selectedDate: $selectedDate)
                        .padding(.horizontal)

                    if totals.hasData {
                        MacroDonutChart(totals: totals)
                            .padding(.horizontal)
                    } else {
                        ContentUnavailableView(
                            "Noch keine Einträge",
                            systemImage: "chart.pie",
                            description: Text("Füge Mahlzeiten im Tagebuch hinzu.")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Statistik")
        }
    }
}

// MARK: - MacroTotals

struct MacroTotals {
    let kcal: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let fiber: Double

    var hasData: Bool { kcal > 0 }

    var slices: [MacroSlice] {
        var result: [MacroSlice] = [
            MacroSlice(label: "Protein",        grams: protein, color: .blue),
            MacroSlice(label: "Kohlenhydrate",  grams: carbs,   color: .orange),
            MacroSlice(label: "Fett",           grams: fat,     color: .yellow),
        ]
        if fiber > 0.05 {
            result.append(MacroSlice(label: "Ballaststoffe", grams: fiber, color: .green))
        }
        return result.filter { $0.grams > 0 }
    }
}

struct MacroSlice: Identifiable {
    let id = UUID()
    let label: String
    let grams: Double
    let color: Color
}

// MARK: - MacroDonutChart

private struct MacroDonutChart: View {
    let totals: MacroTotals

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Chart(totals.slices) { slice in
                    SectorMark(
                        angle: .value("g", slice.grams),
                        innerRadius: .ratio(0.58),
                        angularInset: 1.5
                    )
                    .foregroundStyle(slice.color)
                    .cornerRadius(4)
                }
                .frame(height: 240)

                VStack(spacing: 2) {
                    Text("\(Int(totals.kcal))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("kcal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(totals.slices) { slice in
                    MacroLegendItem(slice: slice)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct MacroLegendItem: View {
    let slice: MacroSlice

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(slice.color)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(slice.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatGrams(slice.grams))
                    .font(.subheadline.bold())
            }
            Spacer()
        }
    }

    private func formatGrams(_ g: Double) -> String {
        "\(g < 10 ? String(format: "%.1f", g) : String(Int(g.rounded())))g"
    }
}

// MARK: - DateNavigator (shared UI component)

struct DateNavigator: View {
    @Binding var selectedDate: Date

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var displayLabel: String {
        if Calendar.current.isDateInToday(selectedDate) { return "Heute" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Gestern" }
        return selectedDate.formatted(.dateTime.day().month(.wide).year())
    }

    var body: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .padding(.horizontal)
            }

            Spacer()

            Text(displayLabel)
                .font(.headline)
                .foregroundStyle(isToday ? .primary : .secondary)

            Spacer()

            Button {
                let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                if next <= Date() {
                    selectedDate = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .padding(.horizontal)
                    .foregroundStyle(isToday ? .tertiary : .primary)
            }
            .disabled(isToday)
        }
        .padding(.vertical, 8)
    }
}
