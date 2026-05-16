import SwiftUI

// MARK: - Color Tokens

extension Color {
    static let appBackground  = Color(hex: 0xFBF7F0)
    static let appSurface     = Color(hex: 0xF4F1EA)
    static let cardBackground = Color.white
    static let inkPrimary     = Color(hex: 0x1A1A1A)
    static let inkSecondary   = Color(hex: 0x1A1A1A).opacity(0.5)
    static let inkTertiary    = Color(hex: 0x1A1A1A).opacity(0.3)
    static let inkDivider     = Color(hex: 0x1A1A1A).opacity(0.12)
    static let inkSubtle      = Color(hex: 0x1A1A1A).opacity(0.08)
    static let terra          = Color(hex: 0xD97757)
    static let forest         = Color(hex: 0x2A6F4A)
    static let amber          = Color(hex: 0xC58A3A)
    static let beige          = Color(hex: 0xE8DFD0)
    static let beigeDeep      = Color(hex: 0xC9BBA1)
    static let warmBrown      = Color(hex: 0x7C5E3C)

    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double(hex         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Typography

extension Font {
    static func display(_ size: CGFloat) -> Font {
        .custom("InstrumentSerif-Regular", size: size, relativeTo: .title)
    }
    static func displayItalic(_ size: CGFloat) -> Font {
        .custom("InstrumentSerif-Italic", size: size, relativeTo: .title)
    }
}

// MARK: - Card Style

struct CardStyle: ViewModifier {
    var radius: CGFloat = 22
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color(hex: 0x7C5E3C).opacity(0.07), lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x7C5E3C).opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

struct HeroCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [Color.beige, Color.cardBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color(hex: 0x7C5E3C).opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x7C5E3C).opacity(0.08), radius: 28, x: 0, y: 12)
    }
}

extension View {
    func cardStyle(radius: CGFloat = 22) -> some View {
        modifier(CardStyle(radius: radius))
    }
    func heroCardStyle() -> some View {
        modifier(HeroCardStyle())
    }
}

// MARK: - Section Label

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(Color.inkSecondary)
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    var progress: Double
    var overflow: Double = 0
    var size: CGFloat = 148
    var strokeWidth: CGFloat = 12
    var color: Color = .terra
    var trackColor: Color = Color(hex: 0x7C5E3C).opacity(0.15)
    var content: AnyView?

    init(progress: Double, overflow: Double = 0, size: CGFloat = 148, strokeWidth: CGFloat = 12,
         color: Color = .terra, trackColor: Color = Color(hex: 0x7C5E3C).opacity(0.15),
         content: (() -> AnyView)? = nil) {
        self.progress = progress
        self.overflow = overflow
        self.size = size
        self.strokeWidth = strokeWidth
        self.color = color
        self.trackColor = trackColor
        self.content = content?()
    }

    var body: some View {
        let isOver = overflow > 0
        // Minimum 18% arc so even tiny overages are clearly visible
        let displayOverflow = isOver ? max(min(overflow, 0.80), 0.18) : 0.0
        let activeTrackColor = isOver ? Color.terra.opacity(0.32) : trackColor

        ZStack {
            // Track — warms up visibly when over budget
            Circle()
                .stroke(activeTrackColor, lineWidth: strokeWidth)
                .animation(.easeInOut(duration: 0.4), value: isOver)

            // Main arc (0→100%)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)

            // Overflow arc — amber, same stroke width, starts fresh from 12 o'clock
            // Rendered on top of the terra ring so the colour contrast is immediately visible
            if isOver {
                Circle()
                    .trim(from: 0, to: displayOverflow)
                    .stroke(Color(hex: 0xA95040), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: displayOverflow)
            }

            if let content { content }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Mini Macro Ring

struct MiniRing: View {
    var progress: Double
    var color: Color
    var letter: String
    var size: CGFloat = 36

    private let strokeWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: 0x7C5E3C).opacity(0.15), lineWidth: strokeWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(letter)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Terra Primary Button

struct TerraCTAButton: View {
    let title: String
    let action: () -> Void
    var icon: String? = nil

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.terra)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: Color.terra.opacity(0.32), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

struct TerraOutlineButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.cardBackground)
                .foregroundStyle(Color.warmBrown)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(hex: 0x7C5E3C).opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
