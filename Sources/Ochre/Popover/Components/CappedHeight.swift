import SwiftUI

/// Высота по содержимому, но не больше `limit`: длинная вкладка (все датчики Ultra, много томов)
/// прокручивается внутри панели, а не уходит за край экрана. Считается за один проход раскладки —
/// без состояния и второго кадра, поэтому панель не прыгает при смене вкладок.
struct CappedHeight: Layout {
    let limit: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let ideal = child.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? ideal.width, height: min(ideal.height, limit))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}
