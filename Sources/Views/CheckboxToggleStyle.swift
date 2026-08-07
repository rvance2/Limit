import SwiftUI

/// A plain checkbox — square outline / filled checkmark — since iOS has no native checkbox
/// toggle style (that's macOS-only in SwiftUI). Used wherever a flag reads as "check this off"
/// rather than "tap this button."
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(configuration.isOn ? Color.accentColor : Color.secondary)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}
