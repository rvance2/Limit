import SwiftUI
import SwiftData
import AVKit

// Week 0 / 12 / 22 side-by-side benchmark video comparison.
// Per Block 4 — Peak and Send: "The video comparison is the one that'll
// surprise me" — this is why it gets a prominent entry point from
// TestBatteryView rather than being buried in a detail screen.
struct VideoComparisonView: View {
    @Query private var allResults: [TestResult]

    @State private var boulder: BoulderSlot = .flash

    private enum BoulderSlot: String, CaseIterable, Identifiable {
        case flash = "video_flash"
        case solidLimit = "video_solid_limit"
        case doneOnce = "video_done_once"

        var id: String { rawValue }
        var label: String {
            switch self {
            case .flash: return "Flash level"
            case .solidLimit: return "Solid limit"
            case .doneOnce: return "Done-once"
            }
        }
    }

    private let weeks = [0, 12, 22]

    private func ref(for week: Int) -> String? {
        allResults.first { $0.testItemID == "skill_markers" && $0.weekNumber == week && $0.protocolVariant == boulder.rawValue }?.mediaRef
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Boulder", selection: $boulder) {
                    ForEach(BoulderSlot.allCases) { slot in
                        Text(slot.label).tag(slot)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Text("Same boulder, three points in the block. Hip path is what to look at.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ForEach(weeks, id: \.self) { week in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Week \(week)")
                            .font(.headline)
                        if let ref = ref(for: week), let url = MediaFileStore.resolve(ref) {
                            VideoPlayer(player: AVPlayer(url: url))
                                .frame(height: 220)
                                .cornerRadius(10)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                                Text("No clip logged for week \(week)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(height: 120)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Video comparison")
    }
}

#Preview {
    NavigationStack {
        VideoComparisonView()
            .modelContainer(for: [TestResult.self], inMemory: true)
    }
}
