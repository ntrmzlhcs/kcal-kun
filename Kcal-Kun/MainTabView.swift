import SwiftUI

private enum AppTab: String, CaseIterable {
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

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Color.appBackground.ignoresSafeArea()

            switch activeTab {
            case .diary:   DiaryView()
            case .stats:   StatsView()
            case .library: LibraryView()
            case .scanner: ScannerView()
            }

            // Floating tab bar
            FloatingTabBar(activeTab: $activeTab)
        }
        .ignoresSafeArea(edges: .bottom)
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
