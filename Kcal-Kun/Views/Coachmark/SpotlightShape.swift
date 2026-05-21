import SwiftUI

/// Path, der den gesamten Screen füllt und ein rounded-Rect ausstanzt.
/// Wird mit `FillStyle(eoFill: true)` gefüllt → erzeugt das Spotlight-Loch.
/// Animatable, damit Rect + CornerRadius weich zwischen Steps interpolieren.
struct SpotlightCutout: Shape {
    var rect: CGRect
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<CGRect.AnimatableData, CGFloat> {
        get { AnimatablePair(rect.animatableData, cornerRadius) }
        set {
            rect.animatableData = newValue.first
            cornerRadius = newValue.second
        }
    }

    func path(in bounds: CGRect) -> Path {
        var p = Path()
        p.addRect(bounds)
        // Nur ausstanzen, wenn Rect gesetzt ist (Steps mit Spotlight)
        if rect.width > 1, rect.height > 1 {
            p.addRoundedRect(
                in: rect,
                cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
            )
        }
        return p
    }
}
