import SwiftUI

/// One-screen first-launch disclaimer. Shown once via `hasSeenDisclaimer`, not re-shown after.
struct DisclaimerView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            Text("Limit")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 16) {
                Text("A personal training log.")
                    .font(.body)

                Text("Training data stays on your device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Continue") { onContinue() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
    }
}
