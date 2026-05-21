import SwiftUI

struct CoachmarkBubble: View {
    let step: CoachmarkStep
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false

    private var mascotSize: CGFloat {
        step.placement == .center ? 96 : 80
    }

    var body: some View {
        Group {
            switch step.placement {
            case .center:
                centerLayout
            case .leftOfMascot, .rightOfMascot:
                sideLayout
            }
        }
    }

    // MARK: - Mascot + Accessory

    /// Position des Akzessoirs am Mascot — abhängig vom Bubble-Placement, damit
    /// die Bubble das Akzessoir nicht überdeckt.
    private var accessoryAlignment: Alignment {
        step.placement == .rightOfMascot ? .topLeading : .topTrailing
    }

    private var accessoryOffsetX: CGFloat {
        let mag = mascotSize * 0.18
        return step.placement == .rightOfMascot ? -mag : +mag
    }

    private var mascotWithAccessory: some View {
        ZStack(alignment: accessoryAlignment) {
            MascotView(size: mascotSize,
                       mood: step.mood,
                       tone: step.tone,
                       tilt: step.tilt)
                .offset(y: reduceMotion ? 0 : (bob ? -5 : 0))
                .rotationEffect(.degrees(reduceMotion ? 0 : (bob ? 2 : -2)))
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        bob = true
                    }
                }

            CoachmarkAccessory(kind: step.accessory, size: mascotSize * 0.42)
                .offset(x: accessoryOffsetX, y: -mascotSize * 0.18)
        }
        .frame(width: mascotSize, height: mascotSize)
    }

    // MARK: - Center Layout

    private var centerLayout: some View {
        VStack(spacing: 18) {
            mascotWithAccessory
                .padding(.top, 8)
            bubbleCard(isCenter: true)
        }
        .frame(maxWidth: 320)
    }

    // MARK: - Side Layout

    private var sideLayout: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if step.placement == .leftOfMascot {
                bubbleCard(isCenter: false)
                    .padding(.trailing, -8)
                mascotWithAccessory
                    .zIndex(1)
            } else {
                mascotWithAccessory
                    .zIndex(1)
                bubbleCard(isCenter: false)
                    .padding(.leading, -8)
            }
        }
        .frame(maxWidth: 340)
    }

    // MARK: - Bubble-Card

    @ViewBuilder
    private func bubbleCard(isCenter: Bool) -> some View {
        VStack(alignment: isCenter ? .center : .leading, spacing: 6) {
            Text(step.title)
                .font(.display(isCenter ? 24 : 19))
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(isCenter ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(step.body.replacingOccurrences(of: "{stepCount}", with: "\(COACH_STEPS.count)"))
                .font(.system(size: isCenter ? 14 : 13))
                .foregroundStyle(Color.inkPrimary.opacity(0.7))
                .multilineTextAlignment(isCenter ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(.horizontal, isCenter ? 22 : 16)
        .padding(.vertical, isCenter ? 22 : 14)
        .frame(maxWidth: isCenter ? .infinity : 220, alignment: isCenter ? .center : .leading)
        .background(
            Group {
                if isCenter {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white)
                } else {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: step.placement == .leftOfMascot ? 20 : 4,
                        bottomTrailingRadius: step.placement == .leftOfMascot ? 4 : 20,
                        topTrailingRadius: 20,
                        style: .continuous
                    )
                    .fill(Color.white)
                }
            }
        )
        .shadow(color: .black.opacity(0.28), radius: 25, x: 0, y: 18)
    }
}
