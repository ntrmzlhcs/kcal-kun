import SwiftUI

/// SwiftUI-Splash-Screen, der nach dem iOS-System-Launch-Screen für 2 Sekunden
/// angezeigt wird, bevor die eigentliche App-UI erscheint. Gibt der App einen
/// markenkonformen Cozy-Start-Moment (Mascot + Schriftzug auf creme Hintergrund)
/// statt direkt ins Tagebuch zu springen.
///
/// Der eingebaute iOS-Launch-Screen (Info.plist `UILaunchScreen`) ist sehr kurz
/// (~200-500ms) und vom System gesteuert — wir können ihn nicht verlängern. Ein
/// SwiftUI-Splash danach ist die gängige Lösung (auch Spotify, Netflix etc.
/// machen es so).
struct SplashScreenView: View {
    @AppStorage("selectedMascotTone") private var savedMascotTone = "cream"
    @State private var mascotScale: CGFloat = 0.8
    @State private var mascotOpacity: Double = 0
    @State private var titleOpacity: Double = 0

    private var mascotTone: MascotTone {
        switch savedMascotTone {
        case "terra": return .terra
        case "beige": return .beige
        default:      return .cream
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 18) {
                MascotView(size: 140, mood: .happy, tone: mascotTone, tilt: -4)
                    .scaleEffect(mascotScale)
                    .opacity(mascotOpacity)
                    .accessibilityHidden(true)

                Text("Kcal-Kun")
                    .font(.display(42))
                    .foregroundStyle(Color.inkPrimary)
                    .opacity(titleOpacity)
            }
        }
        .onAppear {
            // Mascot: kurzes „Pop" mit Bounce. Title: sanft eingefadet danach.
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
                mascotScale = 1.0
                mascotOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
                titleOpacity = 1.0
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
