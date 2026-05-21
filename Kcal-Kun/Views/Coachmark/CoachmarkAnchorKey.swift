import SwiftUI

/// Targets, die von der Coachmark-Tour spotlighted werden können.
enum CoachmarkTarget: String, Hashable, Codable {
    case kcalRing
    case macroChips
    case breakfastPlus
    case libraryFavorites
    case scannerLabelBtn
    case scannerDishBtn
    case statsWeeklyChart
    case statsWeightChart
    case statsAIAnalysis
}

/// PreferenceKey, der die GLOBALEN Frames (Screen-Koordinaten) der Targets liefert.
/// Direkter und robuster als Anchor<CGRect>-Auflösung:
/// - funktioniert auch in ScrollViews (Frame folgt dem Scroll)
/// - kein Timing-/Retry-Problem
/// - Koordinatensystem matched direkt mit `.ignoresSafeArea()`-Overlay
struct CoachmarkAnchorKey: PreferenceKey {
    static let defaultValue: [CoachmarkTarget: CGRect] = [:]
    static func reduce(value: inout [CoachmarkTarget: CGRect],
                       nextValue: () -> [CoachmarkTarget: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Markiert eine View als Spotlight-Ziel der Coachmark-Tour.
    /// Misst das globale Frame der View bei jedem Layout/Scroll.
    func coachmarkTarget(_ target: CoachmarkTarget) -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: CoachmarkAnchorKey.self,
                        value: [target: geo.frame(in: .global)]
                    )
            }
        )
    }

    /// Markiert eine View nur dann als Spotlight-Ziel, wenn `condition` true ist.
    @ViewBuilder
    func coachmarkTargetIf(_ condition: Bool, _ target: CoachmarkTarget) -> some View {
        if condition {
            self.coachmarkTarget(target)
        } else {
            self
        }
    }
}
