import SwiftUI

enum PulseStyle {
    static let background = Color(hex: "F2F3F5")
    static let primaryText = Color(hex: "232833")
    static let secondary = Color(hex: "6A7282")
    static let accent = Color(hex: "FF0A3D")
    static let accentTint = Color(hex: "FFE8ED")
    static let separator = Color(hex: "DFE2E7")
    static let actionGradient = LinearGradient(
        colors: [Color(hex: "FF2450"), Color(hex: "FF002B")],
        startPoint: .top, endPoint: .bottom
    )
}

struct PulsePrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(.white)
            .background(PulseStyle.actionGradient, in: Capsule())
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
    }
}
