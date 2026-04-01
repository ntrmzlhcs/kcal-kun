import SwiftUI

struct KcalProgressView: View {
    let consumed: Double
    let profile: UserProfile
    let workoutKcal: Double

    // Erhaltungsbedarf = Grundumsatz + Bewegungskalorien
    private var budget: Double { profile.bmr + workoutKcal }
    // Effektives Ziel = Erhaltungsbedarf ± Delta
    private var effectiveTarget: Double {
        profile.goalType == .deficit ? budget - profile.kcalDelta : budget + profile.kcalDelta
    }

    // MARK: - Farb-Logik

    private var barColor: Color {
        switch profile.goalType {
        case .deficit:
            if consumed >= budget         { return .red }
            if consumed >= effectiveTarget { return .orange }
            return .green

        case .surplus:
            if consumed > effectiveTarget * 1.10 { return .red }
            if consumed > effectiveTarget * 1.05 { return .orange }
            if consumed >= effectiveTarget        { return .green }
            if consumed >= budget                 { return .orange }
            return .secondary
        }
    }

    private var statusLabel: String {
        let remaining = effectiveTarget - consumed
        switch profile.goalType {
        case .deficit:
            if consumed >= budget          { return "Über Grundumsatz!" }
            if consumed >= effectiveTarget { return "\(Int(consumed - effectiveTarget)) kcal über Ziel" }
            return "\(Int(remaining)) kcal übrig"

        case .surplus:
            if consumed > effectiveTarget * 1.10 { return "\(Int(consumed - effectiveTarget)) kcal über Ziel" }
            if consumed > effectiveTarget * 1.05 { return "Leicht über Ziel" }
            if consumed >= effectiveTarget        { return "Ziel erreicht 🎯" }
            return "\(Int(remaining)) kcal bis zum Ziel"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kalorien")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(consumed))")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("/ \(Int(effectiveTarget)) kcal")
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
                            width: geo.size.width * min(consumed / max(effectiveTarget, 1), 1.0),
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
