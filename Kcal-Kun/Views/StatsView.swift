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
    @State private var showAPIKeySetup = false
    @State private var rollingWeights: [Date: Double] = [:]
    @State private var weeklyWorkoutKcals: [Date: Double] = [:]

    private var dayEntries: [DiaryEntry] {
        allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var analysisPeriodEntries: [DiaryEntry] {
        let cutoff = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: -29, to: Date())!
        )
        return allEntries.filter { $0.date >= cutoff }
    }

    private var last7DayEntries: [DiaryEntry] {
        let cutoff = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        )
        return allEntries.filter { $0.date >= cutoff }
    }

    @Environment(\.coachmarkDemoMode) private var coachmarkDemo

    private var displayRollingWeights: [Date: Double] {
        coachmarkDemo ? CoachmarkDemoData.demoRollingWeights : rollingWeights
    }

    private var displayAnalysis: String {
        coachmarkDemo ? CoachmarkDemoData.demoAnalysisJSON : cachedAnalysis
    }

    private var displayAnalysisTimestamp: TimeInterval {
        coachmarkDemo ? Date().timeIntervalSince1970 : cachedTimestamp
    }

    private var totals: MacroTotals {
        if coachmarkDemo {
            return MacroTotals(
                kcal:    CoachmarkDemoData.dailyConsumed,
                protein: CoachmarkDemoData.dailyProtein,
                fat:     CoachmarkDemoData.dailyFat,
                carbs:   CoachmarkDemoData.dailyCarbs,
                fiber:   CoachmarkDemoData.dailyFiber
            )
        }
        return MacroTotals(
            kcal:    dayEntries.reduce(0) { $0 + $1.kcal },
            protein: dayEntries.reduce(0) { $0 + $1.protein },
            fat:     dayEntries.reduce(0) { $0 + $1.fat },
            carbs:   dayEntries.reduce(0) { $0 + $1.carbs },
            fiber:   dayEntries.reduce(0) { $0 + $1.fiber }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollViewReader { scrollProxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            DateNavigator(selectedDate: $selectedDate)
                                .padding(.horizontal, 18)

                            if totals.hasData {
                                MacroDonutChart(totals: totals)
                                    .padding(.horizontal, 18)
                                FiberProgressBar(fiber: totals.fiber)
                                    .padding(.horizontal, 18)
                            } else {
                                VStack(spacing: 12) {
                                    MascotView(size: 72, mood: .sleep, tone: .beige)
                                    Text("Heute noch keine Einträge")
                                        .font(.display(22))
                                        .foregroundStyle(Color.inkPrimary)
                                    Text("Füge Mahlzeiten im Tagebuch hinzu.")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.inkSecondary)
                                }
                                .padding(.top, 24)
                                .padding(.bottom, 12)
                            }

                            // Wochenverlauf wird IMMER gezeigt — er bezieht sich auf die
                            // letzten 7 Tage, nicht nur heute. (Im Tour-Demo-Modus mit Demo-Daten.)
                            WeeklyKcalChart(entries: last7DayEntries, workoutKcals: weeklyWorkoutKcals, profile: profiles.first)
                                .padding(.horizontal, 18)
                                .coachmarkTarget(.statsWeeklyChart)  // misst nur die Card (ohne Polster)
                                .padding(.top, 8)                      // 8pt Atemraum über Card
                                .id("coachmark.statsWeeklyChart")     // Scroll-Target = Card + Polster

                            if displayRollingWeights.count >= 2 {
                                WeightChart(data: displayRollingWeights)
                                    .padding(.horizontal, 18)
                                    .coachmarkTarget(.statsWeightChart)
                                    .padding(.top, 8)
                                    .id("coachmark.statsWeightChart")
                            }

                            NutritionAnalysisCard(
                                isLoading: isLoadingAnalysis,
                                analysis: displayAnalysis,
                                timestamp: displayAnalysisTimestamp,
                                error: coachmarkDemo ? nil : analysisError,
                                onRefresh: {
                                    if APIKeyService.hasKey {
                                        Task { await runAnalysis() }
                                    } else {
                                        showAPIKeySetup = true
                                    }
                                }
                            )
                            .padding(.horizontal, 18)
                            .coachmarkTarget(.statsAIAnalysis)
                            .padding(.top, 8)
                            .id("coachmark.statsAIAnalysis")

                            Spacer().frame(height: 90)
                        }
                        .padding(.top, 8)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .coachmarkStepChanged)) { notif in
                        guard let target = notif.object as? CoachmarkTarget else { return }
                        let scrollID: String?
                        switch target {
                        case .statsWeeklyChart: scrollID = "coachmark.statsWeeklyChart"
                        case .statsWeightChart: scrollID = "coachmark.statsWeightChart"
                        case .statsAIAnalysis:  scrollID = "coachmark.statsAIAnalysis"
                        default:                scrollID = nil
                        }
                        guard let id = scrollID else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeInOut(duration: 0.45)) {
                                scrollProxy.scrollTo(id, anchor: .top)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Statistik")
                        .font(.display(18))
                        .foregroundStyle(Color.inkPrimary)
                }
            }
        }
        .task {
            rollingWeights = await healthKit.fetchRollingAverageWeights(days: 30)
            weeklyWorkoutKcals = await healthKit.fetchWorkoutKcals(forLast: 7)
        }
        .sheet(isPresented: $showAPIKeySetup) {
            APIKeySetupView(mode: .sheet, onDone: { showAPIKeySetup = false })
        }
    }
}

// MARK: - Analysis helpers (StatsView extension)

extension StatsView {
    func runAnalysis() async {
        isLoadingAnalysis = true
        analysisError = nil
        do {
            let workoutKcals = await healthKit.fetchWorkoutKcals(forLast: 30)
            let prompt = GeminiService.buildNutritionPrompt(
                entries: analysisPeriodEntries,
                workoutKcals: workoutKcals,
                profile: profiles.first,
                rollingWeights: rollingWeights
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

// MARK: - Analysis Data Structures

private struct MealSuggestion: Codable, Identifiable {
    let id = UUID()
    let name: String
    let portions: String
    let macros: String
    private enum CodingKeys: String, CodingKey { case name, portions, macros }
}

private struct AnalysisSection: Codable, Identifiable {
    let id: String
    let title: String
    let highlight: String?
    let body: String?
    let meals: [MealSuggestion]?
}

private struct AnalysisResult: Codable {
    let sections: [AnalysisSection]
}

// MARK: - NutritionAnalysisCard

private struct NutritionAnalysisCard: View {
    let isLoading: Bool
    let analysis: String
    let timestamp: Double
    let error: String?
    let onRefresh: () -> Void

    private var parsedResult: AnalysisResult? {
        guard !analysis.isEmpty, let data = analysis.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AnalysisResult.self, from: data)
    }

    private var timestampLabel: String? {
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
            .formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "de")))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(text: "KI-Analyse")
                    Text("30 Tage")
                        .font(.display(19))
                        .foregroundStyle(Color.inkPrimary)
                }
                Spacer()
                Button {
                    onRefresh()
                } label: {
                    Label("Aktualisieren", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.warmBrown)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.beige)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }

            if let label = timestampLabel {
                Text("Letzte Analyse: \(label)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkTertiary)
            }

            Divider().overlay(Color.inkDivider)

            if isLoading {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView().tint(Color.terra)
                        Text("Gemini analysiert…")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if let error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.terra)
            } else if analysis.isEmpty {
                Text("Tippe auf 'Aktualisieren' für eine Auswertung der letzten 30 Tage.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkSecondary)
            } else if let result = parsedResult {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(result.sections) { section in
                        analysisSectionView(section)
                        if section.id != result.sections.last?.id {
                            Divider().overlay(Color.inkDivider).padding(.vertical, 12)
                        }
                    }
                }
            } else {
                // Alter Cache (kein JSON) — Neustart anzeigen
                Text("Format veraltet — bitte Analyse aktualisieren.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(18)
        .heroCardStyle()
    }

    @ViewBuilder
    private func analysisSectionView(_ section: AnalysisSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.title)
                .font(.display(16))
                .foregroundStyle(Color.inkPrimary)

            if let highlight = section.highlight {
                Text(highlight)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.terra)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.terra.opacity(0.10))
                    .clipShape(Capsule())
            }

            if let body = section.body {
                Text(body)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let meals = section.meals {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(meals) { meal in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.warmBrown)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.inkPrimary)
                                Text("\(meal.portions) · \(meal.macros)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.inkSecondary)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - WeightChart

private struct WeightChart: View {
    let data: [Date: Double]

    private struct DataPoint: Identifiable {
        let id = UUID()
        let day: Date
        let kg: Double
    }

    private var chartData: [DataPoint] {
        data.map { DataPoint(day: $0.key, kg: $0.value) }
            .sorted { $0.day < $1.day }
    }

    private var yMin: Double { (chartData.map(\.kg).min() ?? 0) - 1 }
    private var yMax: Double { (chartData.map(\.kg).max() ?? 0) + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(text: "Gewichtsverlauf")
                Text("30 Tage · Ø 7 Messungen")
                    .font(.display(19))
                    .foregroundStyle(Color.inkPrimary)
            }

            Chart(chartData) { point in
                AreaMark(
                    x: .value("Datum", point.day),
                    yStart: .value("kg", yMin),
                    yEnd: .value("kg", point.kg)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color.terra.opacity(0.15), location: 0.0),
                            .init(color: Color.terra.opacity(0.0),  location: 0.75)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Datum", point.day),
                    y: .value("kg", point.kg)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.terra)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 10)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated).year()
                        .locale(Locale(identifier: "de")))
                    AxisGridLine()
                }
            }
            .chartYScale(domain: yMin...yMax)
            .chartPlotStyle { $0.background(.clear) }
            .frame(height: 180)
        }
        .padding(18)
        .heroCardStyle()
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
            MacroSlice(label: "Protein",        grams: protein, color: Color.terra),
            MacroSlice(label: "Kohlenhydrate",  grams: carbs,   color: Color.forest),
            MacroSlice(label: "Fett",           grams: fat,     color: Color.amber),
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
                        .font(.display(34))
                        .foregroundStyle(Color.inkPrimary)
                        .monospacedDigit()
                    Text("kcal")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.inkSecondary)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(totals.slices) { slice in
                    MacroLegendItem(slice: slice)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Color.beige, Color.cardBackground], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color(hex: 0x7C5E3C).opacity(0.10), lineWidth: 1))
        .shadow(color: Color(hex: 0x7C5E3C).opacity(0.08), radius: 24, x: 0, y: 10)
    }
}

private struct MacroLegendItem: View {
    let slice: MacroSlice

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(slice.color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(slice.label)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.inkSecondary)
                Text(formatGrams(slice.grams))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
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

    private var fillColor: Color {
        let ratio = fiber / goal
        if ratio >= 0.85 { return .forest }
        if ratio >= 0.5  { return .amber }
        return .terra
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(text: "Ballaststoffe")
                    Text("Tagesziel 35 g")
                        .font(.display(19))
                        .foregroundStyle(Color.inkPrimary)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(fiber < 10 ? String(format: "%.1f", fiber) : "\(Int(fiber.rounded()))")
                        .font(.display(22))
                        .foregroundStyle(fillColor)
                    Text("/ \(Int(goal)) g")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkSecondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.inkDivider)
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(fillColor)
                        .frame(width: geo.size.width * min(fiber / goal, 1.0), height: 10)
                        .animation(.spring(duration: 0.4), value: fiber)
                }
            }
            .frame(height: 10)
        }
        .padding(18)
        .heroCardStyle()
    }
}

// MARK: - WeeklyKcalChart

private struct WeeklyKcalChart: View {
    let entries: [DiaryEntry]
    let workoutKcals: [Date: Double]
    let profile: UserProfile?

    private struct DayData: Identifiable {
        let id = UUID()
        let day: Date
        let kcal: Double
        let effectiveTarget: Double
        let label: String
        let isToday: Bool
    }

    @Environment(\.coachmarkDemoMode) private var coachmarkDemo

    /// Tagesziel für RuleMark + Header-Pill. In Demo-Modus fallback wenn Profil fehlt.
    private var displayBaseTarget: Double? {
        if let p = profile {
            return p.goalType == .deficit ? p.bmr - p.kcalDelta : p.bmr + p.kcalDelta
        }
        return coachmarkDemo ? CoachmarkDemoData.fallbackDailyTarget : nil
    }

    private var chartData: [DayData] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de")
        fmt.dateFormat = "EEE"
        let baseTarget: Double
        if let p = profile {
            baseTarget = p.goalType == .deficit ? p.bmr - p.kcalDelta : p.bmr + p.kcalDelta
        } else if coachmarkDemo {
            baseTarget = CoachmarkDemoData.fallbackDailyTarget
        } else {
            baseTarget = 0
        }
        return (0..<7).compactMap { offset -> DayData? in
            guard let day = cal.date(byAdding: .day, value: -(6 - offset), to: today) else { return nil }
            let kcal: Double
            let workout: Double
            if coachmarkDemo {
                kcal = CoachmarkDemoData.weeklyKcals[offset]
                workout = 0
            } else {
                kcal = entries
                    .filter { cal.isDate($0.date, inSameDayAs: day) }
                    .reduce(0) { $0 + $1.kcal }
                workout = workoutKcals[day] ?? 0
            }
            let effective = baseTarget > 0 ? baseTarget + workout : 0
            let isToday = cal.isDateInToday(day)
            return DayData(day: day, kcal: kcal, effectiveTarget: effective, label: fmt.string(from: day), isToday: isToday)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(text: "Woche")
                    Text("Letzte 7 Tage")
                        .font(.display(19))
                        .foregroundStyle(Color.inkPrimary)
                }
                Spacer()
                if let displayTarget = displayBaseTarget {
                    Text("Ziel \(Int(displayTarget)) kcal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.warmBrown)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.beige)
                        .clipShape(Capsule())
                }
            }

            Chart {
                ForEach(chartData) { d in
                    BarMark(
                        x: .value("Tag", d.label),
                        y: .value("kcal", d.kcal)
                    )
                    .foregroundStyle(barColor(for: d))
                    .cornerRadius(6)
                }
                if let displayTarget = displayBaseTarget {
                    RuleMark(y: .value("Ziel", displayTarget))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5]))
                        .foregroundStyle(Color.warmBrown.opacity(0.6))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .frame(height: 160)
        }
        .padding(18)
        .heroCardStyle()
    }

    /// Bar-Color logic:
    /// - Goal-aware (Defizit/Maintenance/Surplus)
    /// - ±5% vom Ziel → forest (perfekt)
    /// - ±5–15% → amber (leichte Abweichung)
    /// - >±15% in ungewünschter Richtung → terra (deutliche Abweichung)
    /// - Heute: volle Sättigung; andere Tage: 0.7 Opacity
    private func barColor(for d: DayData) -> Color {
        guard d.effectiveTarget > 0 else {
            return d.isToday ? .beige : .beige.opacity(0.6)
        }
        let ratio = d.kcal / d.effectiveTarget
        let deviation = ratio - 1.0   // positiv = über, negativ = unter

        let goalType = profile?.goalType ?? .maintenance
        let base: Color
        switch goalType {
        case .deficit:
            // Defizit: unter oder leicht über Ziel = gut
            if deviation <= 0.05      { base = .forest }
            else if deviation <= 0.15 { base = .amber }
            else                      { base = .terra }
        case .maintenance:
            // Halten: nah am Ziel in beide Richtungen
            if abs(deviation) <= 0.05      { base = .forest }
            else if abs(deviation) <= 0.15 { base = .amber }
            else                           { base = .terra }
        case .surplus:
            // Aufbau: über oder leicht unter Ziel = gut
            if deviation >= -0.05      { base = .forest }
            else if deviation >= -0.15 { base = .amber }
            else                       { base = .terra }
        }

        return d.isToday ? base : base.opacity(0.7)
    }
}

// MARK: - DateNavigator (shared UI component)

struct DateNavigator: View {
    @Binding var selectedDate: Date

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var displayLabel: String {
        if Calendar.current.isDateInYesterday(selectedDate) { return "Gestern" }
        if Calendar.current.isDateInToday(selectedDate)     { return "Heute" }
        if Calendar.current.isDateInTomorrow(selectedDate)  { return "Morgen" }
        return selectedDate.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "de")))
    }

    var body: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.warmBrown)
                    .frame(width: 36, height: 36)
                    .background(Color.cardBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.inkDivider, lineWidth: 1))
            }

            Spacer()

            Text(displayLabel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isToday ? Color.inkPrimary : Color.inkSecondary)

            Spacer()

            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.warmBrown)
                    .frame(width: 36, height: 36)
                    .background(Color.cardBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.inkDivider, lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}
