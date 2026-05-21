import SwiftUI

struct CoachmarkAccessory: View {
    let kind: AccessoryKind
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var float = false

    var body: some View {
        content
            .frame(width: size, height: size)
            .offset(y: reduceMotion ? 0 : (float ? -3 : 0))
            .rotationEffect(.degrees(reduceMotion ? 0 : (float ? 4 : -4)))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    float = true
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .wave:       waveView
        case .target:     targetView
        case .pkf:        pkfView
        case .plus:       plusView
        case .star:       starView
        case .magnifier:  magnifierView
        case .sparkles:   sparklesView
        case .bars:       barsView
        case .confetti:   confettiView
        case .scale:      scaleView
        case .lightbulb:  lightbulbView
        }
    }

    // MARK: - Einzel-Akzessoires

    private var circleBg: some View {
        Circle().fill(Color.cream)
            .overlay(Circle().stroke(Color.warmBrown.opacity(0.15), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }

    private var waveView: some View {
        ZStack {
            circleBg
            Image(systemName: "hand.wave.fill")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(Color.amber)
        }
    }

    private var targetView: some View {
        ZStack {
            Circle().fill(Color.terra)
            Circle().fill(Color.cream).padding(size * 0.18)
            Circle().fill(Color.terra).padding(size * 0.34)
        }
        .shadow(color: Color.terra.opacity(0.32), radius: 4, y: 2)
    }

    private var pkfView: some View {
        HStack(spacing: 2) {
            miniBadge("P", Color.terra)
            miniBadge("K", Color.forest)
            miniBadge("F", Color.amber)
        }
    }

    private func miniBadge(_ letter: String, _ color: Color) -> some View {
        ZStack {
            Circle().fill(color)
            Text(letter)
                .font(.system(size: size * 0.22, weight: .heavy))
                .foregroundStyle(.white)
        }
        .frame(width: size * 0.32, height: size * 0.32)
    }

    private var plusView: some View {
        ZStack {
            Circle().fill(Color.terra)
            Image(systemName: "plus")
                .font(.system(size: size * 0.5, weight: .heavy))
                .foregroundStyle(.white)
        }
        .shadow(color: Color.terra.opacity(0.32), radius: 4, y: 2)
    }

    private var starView: some View {
        ZStack {
            Circle().fill(Color.amber)
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.5, weight: .heavy))
                .foregroundStyle(.white)
        }
        .shadow(color: Color.amber.opacity(0.32), radius: 4, y: 2)
    }

    private var magnifierView: some View {
        ZStack {
            circleBg
            Image(systemName: "magnifyingglass")
                .font(.system(size: size * 0.52, weight: .heavy))
                .foregroundStyle(Color.warmBrown)
        }
    }

    private var sparklesView: some View {
        ZStack {
            Circle().fill(Color.forest)
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.55, weight: .semibold))
                .foregroundStyle(.white)
        }
        .shadow(color: Color.forest.opacity(0.32), radius: 4, y: 2)
    }

    private var barsView: some View {
        ZStack {
            circleBg
            HStack(alignment: .bottom, spacing: size * 0.05) {
                Capsule().fill(Color.amber)
                    .frame(width: size * 0.13, height: size * 0.35)
                Capsule().fill(Color.terra)
                    .frame(width: size * 0.13, height: size * 0.55)
                Capsule().fill(Color.forest)
                    .frame(width: size * 0.13, height: size * 0.42)
            }
        }
    }

    private var confettiView: some View {
        ZStack {
            ForEach(0..<6) { i in
                ConfettiPiece(index: i, baseSize: size)
            }
        }
    }

    private var scaleView: some View {
        ZStack {
            circleBg
            Image(systemName: "scalemass.fill")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(Color.terra)
        }
    }

    private var lightbulbView: some View {
        ZStack {
            Circle().fill(Color.amber)
            Image(systemName: "lightbulb.fill")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
        }
        .shadow(color: Color.amber.opacity(0.32), radius: 4, y: 2)
    }
}

// MARK: - Konfetti

private struct ConfettiPiece: View {
    let index: Int
    let baseSize: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    private static let trajectories: [(dx: CGFloat, dy: CGFloat, rot: Double, color: Color)] = [
        ( 0.55, -0.65, 140, .terra),
        (-0.50, -0.70, -120, .forest),
        ( 0.40,  0.50, 200, .amber),
        (-0.60,  0.30, -160, .warmBrown),
        ( 0.65,  0.10, 110, .terra),
        (-0.30, -0.55, -80, .forest),
    ]

    var body: some View {
        let traj = Self.trajectories[index % Self.trajectories.count]
        return RoundedRectangle(cornerRadius: 1.5)
            .fill(traj.color)
            .frame(width: baseSize * 0.12, height: baseSize * 0.18)
            .offset(
                x: phase ? traj.dx * baseSize * 0.9 : 0,
                y: phase ? traj.dy * baseSize * 0.9 : 0
            )
            .rotationEffect(.degrees(phase ? traj.rot : 0))
            .opacity(phase ? 0.0 : 1.0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeOut(duration: 1.6)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.12)
                ) {
                    phase = true
                }
            }
    }
}

// MARK: - Cream Color Shortcut (für Accessory-BGs)

private extension Color {
    static let cream = Color(red: 245/255, green: 235/255, blue: 214/255)
}
