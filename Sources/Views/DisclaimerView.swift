import SwiftUI


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
            }

            Spacer()

            Button("Continue") { onContinue() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
    }
}
