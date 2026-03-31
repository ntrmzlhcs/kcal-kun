import SwiftUI

struct KcalProgressView: View {
    let consumed: Double
    let profile: UserProfile
    let workoutKcal: Double

    private var budget: Double { profile.bmr + workoutKcal }
    private var target: Double { profile.targetKcal }

    // MARK: - Farb-Logik

    private var barColor: Color {
        switch profile.goalType {
        case .deficit:
            if consumed >= budget  { return .red }
            if consumed >= target  { return .orange }
            return .green

        case .surplus:
            if consumed > target * 1.10 { return .red }
            if consumed > target * 1.05 { return .orange }
            if consumed >= target       { return .green }
            if consumed >= budget       { return .orange }
            return .secondary
        }
    }

    private var statusLabel: String {
        let remaining = target - consumed
        switch profile.goalType {
        case .deficit:
            if consumed >= budget  { return "Über Grundumsatz!" }
            if consumed >= target  { return "\(Int(consumed - target)) kcal über Ziel" }
            return "\(Int(remaining)) kcal übrig"

        case .surplus:
            if consumed > target * 1.10 { return "\(Int(consumed - target)) kcal über Ziel" }
            if consumed > target * 1.05 { return "Leicht über Ziel" }
            if consumed >= target       { return "Ziel erreicht 🎯" }
            return "\(Int(remaining)) kcal bis zum Ziel"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kalorien heute")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(consumed))")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("/ \(Int(target)) kcal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange.gradient)
            }

            // Fortschrittsbalken
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(barColor.gradient)
                        .frame(
                            width: geo.size.width * min(consumed / max(target, 1), 1.0),
                            height: 12
                        )
                        .animation(.spring(duration: 0.4), value: consumed)
                }
            }
            .frame(height: 12)

            HStack {
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(barColor)
                Spacer()
                if workoutKcal > 0 {
                    Label("+\(Int(workoutKcal)) kcal Bewegung (−10%)", systemImage: "figure.run")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}
