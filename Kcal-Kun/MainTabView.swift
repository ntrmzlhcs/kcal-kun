import SwiftUI

enum AppTab: String, CaseIterable {
    case diary, stats, library, scanner

    var label: String {
        switch self {
        case .diary:   "Tagebuch"
        case .stats:   "Statistik"
        case .library: "Bibliothek"
        case .scanner: "Scanner"
        }
    }

    var icon: String {
        switch self {
        case .diary:   "book"
        case .stats:   "chart.pie"
        case .library: "books.vertical"
        case .scanner: "camera.viewfinder"
        }
    }
}

struct MainTabView: View {
    @State private var activeTab: AppTab = .diary
    @State private var controller = CoachmarkController()
    @State private var latestFrames: [CoachmarkTarget: CGRect] = [:]
    @AppStorage("shouldStartTourAfterOnboarding") private var shouldStartTour = false

    var body: some View {
        ZStack {
            // Bestehender Tab-Inhalt
            ZStack(alignment: .bottom) {
                Color.appBackground.ignoresSafeArea()

                switch activeTab {
                case .diary:   DiaryView()
                case .stats:   StatsView()
                case .library: LibraryView()
                case .scanner: ScannerView()
                }

                FloatingTabBar(activeTab: $activeTab)
            }
            .ignoresSafeArea(edges: .bottom)

            // Coachmark-Tour Overlay
            if controller.isActive {
                CoachmarkOverlay(controller: controller)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        // Während die Tour aktiv ist, sehen alle Child-Views (Diary, Library, Stats)
        // diesen Flag und rendern ihre Demo-Daten anstelle echter User-Daten.
        .environment(\.coachmarkDemoMode, controller.isActive)
        // Spotlight-Frames via globaler GeometryReader-Messung (siehe CoachmarkAnchorKey).
        // PreferenceChange feuert bei jedem Layout/Scroll → Spotlight folgt automatisch.
        .onPreferenceChange(CoachmarkAnchorKey.self) { frames in
            updateSpotlight(frames: frames)
        }
        .onChange(of: controller.currentStep) { _, _ in
            // Beim Step-Wechsel: aktuelles Frame anhand des neuen Targets aus den
            // zuletzt empfangenen PreferenceValues nicht direkt verfügbar →
            // wir setzen spotlightRect zurück, der nächste .onPreferenceChange-Tick
            // wird ihn neu setzen.
            if let target = COACH_STEPS[controller.currentStep].target,
               let frame = latestFrames[target] {
                withAnimation(.easeInOut(duration: 0.35)) {
                    controller.spotlightRect = frame.insetBy(dx: -8, dy: -8)
                }
            } else {
                withAnimation(.easeInOut(duration: 0.35)) {
                    controller.spotlightRect = .zero
                }
            }
        }
        .onAppear {
            controller.tabBinding = $activeTab
            if shouldStartTour {
                // User wählte „Tour starten" am Onboarding-Ende → Flag konsumieren
                // und Tour-Storage zurücksetzen, damit start() sauber läuft.
                shouldStartTour = false
                UserDefaults.standard.set(false, forKey: CoachmarkController.storageKey)
                UserDefaults.standard.set(false, forKey: CoachmarkController.migratedKey)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    controller.start()
                }
            } else {
                controller.maybeAutoLaunch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .startCoachmarkTour)) { _ in
            controller.start()
        }
    }

    /// Aktualisiert spotlightRect basierend auf dem aktuellen Step und gemessenen Frames.
    @MainActor
    private func updateSpotlight(frames: [CoachmarkTarget: CGRect]) {
        latestFrames = frames
        guard controller.isActive,
              controller.currentStep < COACH_STEPS.count else { return }
        let step = COACH_STEPS[controller.currentStep]
        guard let target = step.target, let frame = frames[target] else {
            // Center-Step oder Target noch nicht gemessen
            if step.target == nil {
                withAnimation(.easeInOut(duration: 0.35)) {
                    controller.spotlightRect = .zero
                }
            }
            return
        }
        let padded = frame.insetBy(dx: -8, dy: -8)
        // Nur animieren wenn signifikant verschoben (vermeidet Jitter bei jeder Mini-Änderung)
        let shouldAnimate = abs(controller.spotlightRect.minX - padded.minX) > 1 ||
                            abs(controller.spotlightRect.minY - padded.minY) > 1 ||
                            abs(controller.spotlightRect.width  - padded.width)  > 1 ||
                            abs(controller.spotlightRect.height - padded.height) > 1
        if shouldAnimate {
            withAnimation(.easeInOut(duration: 0.35)) {
                controller.spotlightRect = padded
            }
        }
    }
}

// MARK: - Floating Tab Bar

private struct FloatingTabBar: View {
    @Binding var activeTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                TabPill(
                    tab: tab,
                    isActive: activeTab == tab,
                    onTap: { activeTab = tab }
                )
            }
        }
        .padding(6)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color(hex: 0x7C5E3C).opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x7C5E3C).opacity(0.14), radius: 32, x: 0, y: 12)
        .padding(.horizontal, 14)
        .padding(.bottom, 26)
    }
}

private struct TabPill: View {
    let tab: AppTab
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                Text(tab.label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isActive ? Color.warmBrown : Color.inkTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isActive ? Color.beige : Color.clear)
            )
            .animation(.spring(response: 0.25), value: isActive)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Product.self, DiaryEntry.self, UserProfile.self], inMemory: true)
}
