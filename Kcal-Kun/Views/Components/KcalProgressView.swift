import SwiftUI

struct KcalProgressView: View {
    let consumed: Double
    let profile: UserProfile
    let workoutKcal: Double

    private var budget: Double { profile.bmr + workoutKcal }
    private var effectiveTarget: Double {
        switch profile.goalType {
        case .deficit:     budget - profile.kcalDelta
        case .maintenance: budget
        case .surplus:     budget + profile.kcalDelta
        }
    }

    private var progress: Double {
        min(consumed / max(effectiveTarget, 1), 1.0)
    }

    private var isOver: Bool { consumed > effectiveTarget }

    private var overflowFraction: Double {
        guard isOver else { return 0 }
        return (consumed - effectiveTarget) / max(effectiveTarget, 1)
    }

    private var ringColor: Color {
        switch profile.goalType {
        case .deficit:
            if consumed >= budget          { return .terra }
            if consumed >= effectiveTarget { return .amber }
            return .forest
        case .maintenance:
            if consumed > effectiveTarget * 1.10 { return .terra }
            if consumed > effectiveTarget * 1.05 { return .amber }
            if consumed >= effectiveTarget * 0.90 { return .forest }
            return .inkTertiary
        case .surplus:
            if consumed > effectiveTarget * 1.10 { return .terra }
            if consumed > effectiveTarget * 1.05 { return .amber }
            if consumed >= effectiveTarget        { return .forest }
            if consumed >= budget                 { return .amber }
            return .inkTertiary
        }
    }

    private var statusLabel: String {
        let remaining = effectiveTarget - consumed
        switch profile.goalType {
        case .deficit:
            if consumed >= budget          { return "Über Grundumsatz!" }
            if consumed >= effectiveTarget { return "\(Int(consumed - effectiveTarget)) kcal über Ziel" }
            return "\(Int(remaining)) kcal übrig"
        case .maintenance:
            if consumed > effectiveTarget * 1.10 { return "\(Int(consumed - effectiveTarget)) kcal über Tagesziel" }
            if consumed > effectiveTarget * 1.05 { return "Leicht über Tagesziel" }
            if consumed >= effectiveTarget * 0.90 { return "Im Zielbereich" }
            return "\(Int(remaining)) kcal übrig"
        case .surplus:
            if consumed > effectiveTarget * 1.10 { return "\(Int(consumed - effectiveTarget)) kcal über Ziel" }
            if consumed > effectiveTarget * 1.05 { return "Leicht über Ziel" }
            if consumed >= effectiveTarget        { return "Ziel erreicht" }
            return "\(Int(remaining)) kcal bis zum Ziel"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kalorien")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(consumed))")
                            .font(.display(34))
                            .foregroundStyle(Color.inkPrimary)
                            .monospacedDigit()
                        Text("/ \(Int(effectiveTarget)) kcal")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isOver ? Color.terra.opacity(0.30) : ringColor.opacity(0.15), lineWidth: 5)
                        .frame(width: 48, height: 48)
                        .animation(.easeInOut(duration: 0.4), value: isOver)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 0.5), value: progress)
                    if isOver {
                        Circle()
                            .trim(from: 0, to: max(min(overflowFraction, 0.80), 0.18))
                            .stroke(Color(hex: 0xA95040), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 48, height: 48)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.5), value: overflowFraction)
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ringColor.opacity(0.12))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ringColor)
                        .frame(width: geo.size.width * progress, height: 10)
                        .animation(.spring(duration: 0.4), value: consumed)
                }
            }
            .frame(height: 10)

            HStack {
                Text(statusLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ringColor)
                Spacer()
                if workoutKcal > 0 {
                    Label("+\(Int(workoutKcal)) kcal Bewegung (−10%)", systemImage: "figure.run")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
        .padding(16)
    }
}
