import SwiftUI

extension View {
    func povGlassCard(cornerRadius: CGFloat = 16) -> some View {
        padding()
            .glassEffect(in: .rect(cornerRadius: cornerRadius))
    }

    func povGlassProminentButton() -> some View {
        font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
}
