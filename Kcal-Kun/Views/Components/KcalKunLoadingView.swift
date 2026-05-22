import SwiftUI

/// Einheitliche „Cozy" Loading-Anzeige für alle Async-Operations in der App.
/// Ersetzt den Bug-Befund W6 aus dem Pre-Release-Audit: vorher gab's drei
/// verschiedene Spinner-Stile (LoadingDots, ProgressView, terra-tinted
/// ProgressView). Jetzt: ein zentrales Mascot+Spinner-Pattern für visuelle
/// Konsistenz.
struct KcalKunLoadingView: View {
    let label: String
    var mood: MascotMood = .scan
    var tone: MascotTone = .cream
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 12 : 18) {
            MascotView(size: compact ? 64 : 80, mood: mood, tone: tone, tilt: -4)
                .accessibilityHidden(true)
            Text(label)
                .font(.callout)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
            ProgressView().tint(Color.terra)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Lädt: \(label)")
    }
}

#Preview {
    KcalKunLoadingView(label: "Suche in Open Food Facts …")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
}
