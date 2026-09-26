import SwiftUI

extension View {
    /// Caps prose-heavy content at a comfortable line length and centers it,
    /// so empty states don't stretch across a wide iPad window.
    func readableWidth() -> some View {
        modifier(ReadableWidthModifier())
    }
}

private struct ReadableWidthModifier: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var maxWidth = 560.0

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}
