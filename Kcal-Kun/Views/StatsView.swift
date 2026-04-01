import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(HealthKitService.self) private var healthKit
    @Query private var allEntries: [DiaryEntry]
    @Query private var profiles: [UserProfile]
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @AppStorage("aiNutritionAnalysis") private var cachedAnalysis = ""
    @AppStorage("aiNutritionAnalysisTimestamp") private var cachedTimestamp: Double = 0
    @State private var isLoadingAnalysis = false
    @State private var analysisError: String? = nil

    private var dayEntries: [DiaryEntry] {
        allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var analysisPeriodEntries: [DiaryEntry] {
        let cutoff = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        )
        return allEntries.filter { $0.date >= cutoff }
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
                        FiberProgressBar(fiber: totals.fiber)
                            .padding(.horizontal)
                    } else {
                        ContentUnavailableView(
                            "Noch keine Einträge",
                            systemImage: "chart.pie",
                            description: Text("Füge Mahlzeiten im Tagebuch hinzu.")
                        )
                        .padding(.top, 40)
                    }

                    NutritionAnalysisCard(
                        isLoading: isLoadingAnalysis,
                        analysis: cachedAnalysis,
                        timestamp: cachedTimestamp,
                        error: analysisError,
                        onRefresh: { Task { await runAnalysis() } }
                    )
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Statistik")
        }
    }
}

// MARK: - Analysis helpers (StatsView extension)

extension StatsView {
    func runAnalysis() async {
        isLoadingAnalysis = true
        analysisError = nil
        do {
            let workoutKcals = await healthKit.fetchWorkoutKcals(forLast: 7)
            // Prompt auf @MainActor bauen (SwiftData-Modelle sind nicht Sendable)
            let prompt = GeminiService.buildNutritionPrompt(
                entries: analysisPeriodEntries,
                workoutKcals: workoutKcals,
                profile: profiles.first
            )
            let text = try await GeminiService.analyzeNutrition(prompt: prompt)
            cachedAnalysis = text
            cachedTimestamp = Date().timeIntervalSince1970
        } catch {
            analysisError = (error as? GeminiServiceError)?.localizedDescription
                ?? "Analyse fehlgeschlagen."
        }
        isLoadingAnalysis = false
    }
}

// MARK: - NutritionAnalysisCard

private struct NutritionAnalysisCard: View {
    let isLoading: Bool
    let analysis: String
    let timestamp: Double
    let error: String?
    let onRefresh: () -> Void

    private var timestampLabel: String? {
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
            .formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "de")))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("KI-Analyse (7 Tage)")
                    .font(.headline)
                Spacer()
                Button {
                    onRefresh()
                } label: {
                    Label("Aktualisieren", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                }
                .disabled(isLoading)
            }

            if let label = timestampLabel {
                Text("Letzte Analyse: \(label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if isLoading {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Gemini analysiert…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if let error {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            } else if analysis.isEmpty {
                Text("Tippe auf 'Aktualisieren' für eine Auswertung der letzten 7 Tage.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(analysis)
                    .font(.subheadline)
                    .lineSpacing(4)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
        [
            MacroSlice(label: "Protein",        grams: protein, color: .blue),
            MacroSlice(label: "Kohlenhydrate",  grams: carbs,   color: .orange),
            MacroSlice(label: "Fett",           grams: fat,     color: .yellow),
        ].filter { $0.grams > 0 }
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

// MARK: - FiberProgressBar

private struct FiberProgressBar: View {
    let fiber: Double
    private let goal: Double = 35.0

    private var color: Color {
        let ratio = fiber / goal
        if ratio >= 0.85 { return .green }
        if ratio >= 0.5  { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ballaststoffe")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(fiber < 10 ? String(format: "%.1f", fiber) : "\(Int(fiber.rounded()))")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("/ \(Int(goal)) g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.gradient)
                        .frame(width: geo.size.width * min(fiber / goal, 1.0), height: 12)
                        .animation(.spring(duration: 0.4), value: fiber)
                }
            }
            .frame(height: 12)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
        return selectedDate.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "de")))
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
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .padding(.horizontal)
                    .foregroundStyle(isToday ? .tertiary : .primary)
            }
            .disabled(isToday)
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 8)
    }
}
