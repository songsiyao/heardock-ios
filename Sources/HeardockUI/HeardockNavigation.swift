import SwiftUI

extension View {
    /// Keeps the feedback screens visually consistent on iOS while letting the
    /// module compile (and preview) on macOS.
    @ViewBuilder
    func heardockNavigationChrome(background: Color) -> some View {
        #if os(iOS)
        self
            .toolbarBackground(background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
