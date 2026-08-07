import SwiftUI

/// Spec §7: "Add a one-screen first-launch disclaimer: personal training log, not a medical
/// device, not medical advice." Shown once via `hasSeenDisclaimer`, not re-shown after.
struct DisclaimerView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            Text("Limit")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 16) {
                Text("A personal training log for one climber running a specific plan.")
                    .font(.body)

                Text("Not a medical device. Not medical advice.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("All data stays on this device. No accounts, no cloud, no sharing.")
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
