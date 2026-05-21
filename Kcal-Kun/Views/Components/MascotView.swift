import SwiftUI

// MARK: - Enums

enum MascotMood {
    case happy, sleep, wow, think, smug, scan
}

enum MascotTone {
    case cream, terra, beige

    var body: Color {
        switch self {
        case .cream: Color(hex: 0xF5EBD6)
        case .terra: Color(hex: 0xE8A584)
        case .beige: Color(hex: 0xD8C9A8)
        }
    }
    var shadow: Color {
        switch self {
        case .cream: Color(hex: 0xE5D7B8)
        case .terra: Color(hex: 0xD78E68)
        case .beige: Color(hex: 0xB8A57E)
        }
    }
    var stroke: Color {
        switch self {
        case .cream: Color(hex: 0x3A2E1F)
        case .terra: Color(hex: 0x3A1F12)
        case .beige: Color(hex: 0x3A2E1F)
        }
    }
}

// MARK: - MascotView

struct MascotView: View {
    var size: CGFloat = 80
    var mood: MascotMood = .happy
    var tone: MascotTone = .cream
    var tilt: Double = 0

    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width / 100.0
            let cx = sz.width / 2
            let cy = sz.height / 2

            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: cx + x * s, y: cy + y * s)
            }

            // --- Shadow underside ---
            let shadowEllipse = Path(ellipseIn: CGRect(
                x: cx - 28 * s, y: cy + 29 * s,
                width: 56 * s, height: 6 * s
            ))
            ctx.fill(shadowEllipse, with: .color(tone.stroke.opacity(0.12)))

            // --- Body ---
            var body = Path()
            body.move(to: pt(-32, 8))
            body.addQuadCurve(to: pt(0, -32), control: pt(-36, -30))
            body.addQuadCurve(to: pt(32, 8), control: pt(36, -30))
            body.addQuadCurve(to: pt(0, 30), control: pt(34, 30))
            body.addQuadCurve(to: pt(-32, 8), control: pt(-34, 30))
            ctx.fill(body, with: .color(tone.body))

            // --- Body shadow ---
            var bodyShadow = Path()
            bodyShadow.move(to: pt(-30, 12))
            bodyShadow.addQuadCurve(to: pt(-10, 26), control: pt(-32, 22))
            bodyShadow.addQuadCurve(to: pt(30, 22), control: pt(15, 28))
            bodyShadow.addQuadCurve(to: pt(32, 8), control: pt(34, 18))
            bodyShadow.addQuadCurve(to: pt(0, 20), control: pt(28, 18))
            bodyShadow.addQuadCurve(to: pt(-30, 12), control: pt(-25, 20))
            ctx.fill(bodyShadow, with: .color(tone.shadow.opacity(0.55)))

            // --- Feet ---
            let leftFoot = Path(ellipseIn: CGRect(x: cx - 18 * s, y: cy + 25 * s, width: 12 * s, height: 6 * s))
            let rightFoot = Path(ellipseIn: CGRect(x: cx + 6 * s, y: cy + 25 * s, width: 12 * s, height: 6 * s))
            ctx.fill(leftFoot, with: .color(tone.shadow))
            ctx.fill(rightFoot, with: .color(tone.shadow))

            // --- Eyes ---
            drawEyes(ctx: ctx, pt: pt, mood: mood, tone: tone, s: s, cx: cx, cy: cy)

            // --- Blush ---
            let lBlush = Path(ellipseIn: CGRect(x: cx - 16.5 * s, y: cy + 3.5 * s, width: 5 * s, height: 5 * s))
            let rBlush = Path(ellipseIn: CGRect(x: cx + 11.5 * s, y: cy + 3.5 * s, width: 5 * s, height: 5 * s))
            ctx.fill(lBlush, with: .color(Color(hex: 0xE8A484).opacity(0.45)))
            ctx.fill(rBlush, with: .color(Color(hex: 0xE8A484).opacity(0.45)))

            // --- Mouth ---
            drawMouth(ctx: ctx, pt: pt, mood: mood, tone: tone)

            // --- Leaves ---
            var leafL = Path()
            leafL.move(to: pt(0, -32))
            leafL.addQuadCurve(to: pt(-7, -36), control: pt(-3, -38))
            leafL.addQuadCurve(to: pt(0, -32), control: pt(-3, -33))
            ctx.fill(leafL, with: .color(Color(hex: 0x5C8F4F)))

            var leafR = Path()
            leafR.move(to: pt(0, -32))
            leafR.addQuadCurve(to: pt(7, -36), control: pt(3, -38))
            leafR.addQuadCurve(to: pt(0, -32), control: pt(3, -33))
            ctx.fill(leafR, with: .color(Color(hex: 0x6FA258)))

            // --- Sleeping Zs ---
            if mood == .sleep {
                let zAttrs = AttributedString("z", attributes: AttributeContainer()
                    .font(Font.custom("InstrumentSerif-Italic", size: 12 * s))
                    .foregroundColor(tone.stroke))
                ctx.draw(Text(zAttrs), at: pt(22, -22))

                let zSmallAttrs = AttributedString("z", attributes: AttributeContainer()
                    .font(Font.custom("InstrumentSerif-Italic", size: 8 * s))
                    .foregroundColor(tone.stroke.opacity(0.6)))
                ctx.draw(Text(zSmallAttrs), at: pt(30, -32))
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(tilt))
        // Maskottchen ist meist dekorativ. Wo es eine semantische Rolle hat
        // (z. B. Onboarding-Mascot-Header), kann der Aufrufer den Modifier
        // mit einem expliziten `.accessibilityLabel("...")` überschreiben.
        .accessibilityHidden(true)
    }

    // MARK: Eyes
    private func drawEyes(
        ctx: GraphicsContext, pt: (CGFloat, CGFloat) -> CGPoint,
        mood: MascotMood, tone: MascotTone, s: CGFloat, cx: CGFloat, cy: CGFloat
    ) {
        let eyeSize: CGFloat = 3.6 * s
        let eyeY = cy + 0 * s

        switch mood {
        case .sleep:
            // closed arcs
            var leftEye = Path()
            leftEye.move(to: CGPoint(x: cx - 8 * s - 4 * s, y: eyeY))
            leftEye.addQuadCurve(
                to: CGPoint(x: cx - 8 * s + 4 * s, y: eyeY),
                control: CGPoint(x: cx - 8 * s, y: eyeY + 3 * s)
            )
            var rightEye = Path()
            rightEye.move(to: CGPoint(x: cx + 8 * s - 4 * s, y: eyeY))
            rightEye.addQuadCurve(
                to: CGPoint(x: cx + 8 * s + 4 * s, y: eyeY),
                control: CGPoint(x: cx + 8 * s, y: eyeY + 3 * s)
            )
            ctx.stroke(leftEye, with: .color(tone.stroke), lineWidth: 1.6 * s)
            ctx.stroke(rightEye, with: .color(tone.stroke), lineWidth: 1.6 * s)

        case .wow:
            let lEye = Path(ellipseIn: CGRect(x: cx - 10 * s, y: eyeY - 2.6 * s, width: 4 * s, height: 5.2 * s))
            let rEye = Path(ellipseIn: CGRect(x: cx + 6 * s,  y: eyeY - 2.6 * s, width: 4 * s, height: 5.2 * s))
            ctx.fill(lEye, with: .color(tone.stroke))
            ctx.fill(rEye, with: .color(tone.stroke))

        case .smug:
            var leftEye = Path()
            leftEye.move(to: CGPoint(x: cx - 11 * s, y: eyeY))
            leftEye.addQuadCurve(
                to: CGPoint(x: cx - 5 * s, y: eyeY),
                control: CGPoint(x: cx - 8 * s, y: eyeY - 2 * s)
            )
            var rightEye = Path()
            rightEye.move(to: CGPoint(x: cx + 5 * s, y: eyeY))
            rightEye.addQuadCurve(
                to: CGPoint(x: cx + 11 * s, y: eyeY),
                control: CGPoint(x: cx + 8 * s, y: eyeY - 2 * s)
            )
            ctx.stroke(leftEye, with: .color(tone.stroke), lineWidth: 1.6 * s)
            ctx.stroke(rightEye, with: .color(tone.stroke), lineWidth: 1.6 * s)

        case .scan:
            let lEye = Path(ellipseIn: CGRect(x: cx - 10.2 * s, y: eyeY - 2.2 * s, width: 4.4 * s, height: 4.4 * s))
            let rEye = Path(ellipseIn: CGRect(x: cx + 5.8 * s,  y: eyeY - 2.2 * s, width: 4.4 * s, height: 4.4 * s))
            ctx.fill(lEye, with: .color(tone.stroke))
            ctx.fill(rEye, with: .color(tone.stroke))
            // highlight dots
            let lH = Path(ellipseIn: CGRect(x: cx - 8.5 * s, y: eyeY - 1.7 * s, width: 1.4 * s, height: 1.4 * s))
            let rH = Path(ellipseIn: CGRect(x: cx + 7.3 * s,  y: eyeY - 1.7 * s, width: 1.4 * s, height: 1.4 * s))
            ctx.fill(lH, with: .color(.white))
            ctx.fill(rH, with: .color(.white))

        default:
            // happy / think — oval eyes
            let lEye = Path(ellipseIn: CGRect(x: cx - 9.8 * s, y: eyeY - 2.2 * s, width: 3.6 * s, height: eyeSize))
            let rEye = Path(ellipseIn: CGRect(x: cx + 6.2 * s,  y: eyeY - 2.2 * s, width: 3.6 * s, height: eyeSize))
            ctx.fill(lEye, with: .color(tone.stroke))
            ctx.fill(rEye, with: .color(tone.stroke))
        }
    }

    // MARK: Mouth
    private func drawMouth(
        ctx: GraphicsContext, pt: (CGFloat, CGFloat) -> CGPoint,
        mood: MascotMood, tone: MascotTone
    ) {
        switch mood {
        case .happy:
            var mouth = Path()
            mouth.move(to: pt(-3, 4))
            mouth.addQuadCurve(to: pt(3, 4), control: pt(0, 7))
            ctx.stroke(mouth, with: .color(tone.stroke), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

        case .sleep:
            var mouth = Path()
            mouth.move(to: pt(-1.5, 4))
            mouth.addQuadCurve(to: pt(1.5, 4), control: pt(0, 6))
            ctx.stroke(mouth, with: .color(tone.stroke), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

        case .wow:
            // open oval mouth
            let mouthRect = CGRect(
                x: (pt(-2, 3)).x, y: (pt(-2, 3)).y,
                width: (pt(2, 3)).x - (pt(-2, 3)).x,
                height: (pt(0, 8)).y - (pt(0, 3)).y
            )
            let mouth = Path(ellipseIn: mouthRect)
            ctx.fill(mouth, with: .color(tone.stroke))

        case .smug:
            var mouth = Path()
            mouth.move(to: pt(-2, 4))
            mouth.addQuadCurve(to: pt(2, 4), control: pt(0, 5.5))
            ctx.stroke(mouth, with: .color(tone.stroke), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

        case .scan:
            var mouth = Path()
            mouth.move(to: pt(-2, 4.5))
            mouth.addLine(to: pt(2, 4.5))
            ctx.stroke(mouth, with: .color(tone.stroke), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

        default:
            var mouth = Path()
            mouth.move(to: pt(-2, 4))
            mouth.addQuadCurve(to: pt(2, 4), control: pt(0, 6))
            ctx.stroke(mouth, with: .color(tone.stroke), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 12) {
        ForEach([MascotMood.happy, .sleep, .wow, .smug, .scan, .think], id: \.self) { mood in
            MascotView(size: 60, mood: mood, tone: .cream)
        }
    }
    .padding()
    .background(Color.appBackground)
}

extension MascotMood: Hashable {}
