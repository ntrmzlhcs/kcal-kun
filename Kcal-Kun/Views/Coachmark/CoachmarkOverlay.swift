import SwiftUI

struct CoachmarkOverlay: View {
    @Bindable var controller: CoachmarkController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var strokePulse = false

    private var step: CoachmarkStep {
        COACH_STEPS[min(controller.currentStep, COACH_STEPS.count - 1)]
    }

    private var hasSpotlight: Bool {
        step.target != nil && controller.spotlightRect.width > 1
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                dimLayer
                if hasSpotlight {
                    strokeLayer
                }
                bubbleLayer(in: geo.size, insets: geo.safeAreaInsets)
                chromeTop(insets: geo.safeAreaInsets)
                chromeBottom(in: geo.size, insets: geo.safeAreaInsets)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .ignoresSafeArea()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    strokePulse = true
                }
            }
        }
    }

    // MARK: - Dimm + Cutout

    private var dimLayer: some View {
        SpotlightCutout(rect: hasSpotlight ? controller.spotlightRect : .zero,
                        cornerRadius: step.spotCornerRadius)
            .fill(
                Color(red: 20/255, green: 15/255, blue: 8/255).opacity(0.55),
                style: FillStyle(eoFill: true)
            )
            .allowsHitTesting(true)
            .animation(.easeInOut(duration: 0.35), value: controller.spotlightRect)
    }

    private var strokeLayer: some View {
        RoundedRectangle(cornerRadius: step.spotCornerRadius, style: .continuous)
            .stroke(Color.terra, style: StrokeStyle(lineWidth: 2.5, dash: [8, 5]))
            .frame(width: controller.spotlightRect.width,
                   height: controller.spotlightRect.height)
            .position(x: controller.spotlightRect.midX,
                      y: controller.spotlightRect.midY)
            .opacity(reduceMotion ? 0.85 : (strokePulse ? 1.0 : 0.55))
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.35), value: controller.spotlightRect)
    }

    // MARK: - Bubble

    private func bubbleLayer(in size: CGSize, insets: EdgeInsets) -> some View {
        CoachmarkBubble(step: step)
            .id(controller.currentStep)
            .transition(.opacity.combined(with: .offset(y: 8)))
            .padding(.horizontal, 20)
            .position(bubblePosition(in: size, insets: insets))
            .allowsHitTesting(false)
    }

    private func bubblePosition(in size: CGSize, insets: EdgeInsets) -> CGPoint {
        // Echte Chrome-Höhen aus den tatsächlichen Werten:
        //   chromeTop  = insets.top + 8 (Top-Padding) + ~32 (Pill-Höhe) + 16 (Margin)
        //   chromeBot  = insets.bottom + 48 (Bottom-Padding) + ~44 (Button) + 14 (Dots) + 16
        let safeTop:    CGFloat = insets.top    + 8 + 32 + 16
        let safeBottom: CGFloat = insets.bottom + 48 + 44 + 14 + 16

        switch step.placement {
        case .center:
            return CGPoint(x: size.width / 2,
                           y: (safeTop + (size.height - safeBottom)) / 2)

        case .leftOfMascot, .rightOfMascot:
            guard hasSpotlight else {
                return CGPoint(x: size.width / 2,
                               y: (safeTop + (size.height - safeBottom)) / 2)
            }
            let spot = controller.spotlightRect
            let bubbleH: CGFloat = 140       // konservativ geschätzt
            let gap: CGFloat = 24

            let spaceAbove = spot.minY - safeTop
            let spaceBelow = (size.height - safeBottom) - spot.maxY

            let y: CGFloat
            if spaceBelow >= bubbleH + gap {
                y = spot.maxY + bubbleH / 2 + gap
            } else if spaceAbove >= bubbleH + gap {
                y = spot.minY - bubbleH / 2 - gap
            } else {
                // Wenig Platz — Fallback: mittig zum Spotlight, geclampt im sicheren Bereich
                let clampedMin = safeTop + bubbleH / 2
                let clampedMax = size.height - safeBottom - bubbleH / 2
                y = max(clampedMin, min(spot.midY, clampedMax))
            }
            return CGPoint(x: size.width / 2, y: y)
        }
    }

    // MARK: - Top-Chrome

    private func chromeTop(insets: EdgeInsets) -> some View {
        HStack {
            counterPill
            Spacer()
            closePill
        }
        .padding(.horizontal, 18)
        .padding(.top, insets.top + 8)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var counterPill: some View {
        Text("Schritt \(controller.currentStep + 1) / \(COACH_STEPS.count)")
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(Color.warmBrown)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.95))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }

    private var closePill: some View {
        Button {
            controller.dismiss()
        } label: {
            HStack(spacing: 6) {
                Text("Tour beenden")
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Color.warmBrown)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.95))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom-Chrome

    private func chromeBottom(in size: CGSize, insets: EdgeInsets) -> some View {
        VStack(spacing: 14) {
            progressDots
            HStack(spacing: 10) {
                if step.showsBack {
                    backButton
                }
                primaryButton
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
        .position(x: size.width / 2,
                  y: size.height - insets.bottom - 24 - 40)
    }

    private var progressDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<COACH_STEPS.count, id: \.self) { i in
                let isActive = i == controller.currentStep
                Capsule()
                    .fill(isActive ? Color.terra : Color.warmBrown.opacity(0.30))
                    .frame(width: isActive ? 18 : 8, height: 4)
                    .animation(.spring(response: 0.3), value: controller.currentStep)
            }
        }
    }

    private var backButton: some View {
        Button {
            controller.back()
        } label: {
            Text("Zurück")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.warmBrown)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.95))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.warmBrown.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var primaryButton: some View {
        Button {
            controller.next()
        } label: {
            HStack(spacing: 6) {
                Text(step.primaryCTA)
                    .font(.system(size: 14, weight: .semibold))
                if controller.currentStep < COACH_STEPS.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(step.primaryTint == .terra ? Color.terra : Color.inkPrimary)
            .clipShape(Capsule())
            .shadow(
                color: (step.primaryTint == .terra ? Color.terra : Color.inkPrimary).opacity(0.32),
                radius: 14, y: 6
            )
        }
        .buttonStyle(.plain)
    }
}
