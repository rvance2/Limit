import SwiftUI
import SwiftData

// Entry point for the Test Battery (weeks 0, 12, 22).
// Expected to be linked from: Plan (Block 0 / week 12 / week 22 markers) and
// possibly Today on a test-week day. Parameterless — reachable as a plain
// NavigationLink or sheet from wherever the owning tab wants it.
struct TestBatteryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allResults: [TestResult]
    @Query private var appStates: [AppState]

    @AppStorage("loadCellConfigured") private var loadCellConfigured: Bool = false

    @State private var selectedWeek: Int = 0

    private var testWeeks: [Int] {
        SeedStore.shared.tests?.testWeeks ?? [0, 12, 22]
    }

    private var items: [TestItem] {
        SeedStore.shared.tests?.items ?? []
    }

    /// Critical force is hidden entirely — not just its inputs — when it
    /// requires a load cell I haven't configured.
    private var visibleItems: [TestItem] {
        items.filter { item in
            if item.id == "critical_force", item.requiresLoadCell == true, !loadCellConfigured {
                return false
            }
            return true
        }
    }

    private var appState: AppState? { appStates.first }

    /// Best-effort current week from AppState.startDate, used only to default the picker.
    private var currentWeek: Int {
        guard let state = appState else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: state.startDate), to: Calendar.current.startOfDay(for: .now)).day ?? 0
        return max(0, days / 7)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Test week", selection: $selectedWeek) {
                        ForEach(testWeeks, id: \.self) { week in
                            Text("Week \(week)").tag(week)
                        }
                    }
                    .pickerStyle(.segmented)

                    NavigationLink {
                        VideoComparisonView()
                    } label: {
                        Label("Compare benchmark videos, week 0 / 12 / 22", systemImage: "rectangle.split.3x1")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                Section("Load cell") {
                    Toggle("Load cell configured", isOn: $loadCellConfigured)
                }

                ForEach(visibleItems, id: \.id) { item in
                    Section(item.name) {
                        switch item.id {
                        case "7s_max_hang":
                            FingerHangCard(item: item, weekNumber: selectedWeek, allResults: allResults)
                        case "2rm_pull":
                            PullUpCard(item: item, weekNumber: selectedWeek, allResults: allResults)
                        case "one_arm_lockoff":
                            OneArmLockoffCard(item: item, weekNumber: selectedWeek, allResults: allResults)
                        case "deep_shoulder_capacity":
                            DeepShoulderCapacityCard(item: item, weekNumber: selectedWeek, allResults: allResults)
                        case "critical_force":
                            CriticalForceCard(item: item, weekNumber: selectedWeek, allResults: allResults)
                        case "mobility":
                            MobilityCard(item: item, weekNumber: selectedWeek, allResults: allResults)
                        case "shoulder_screen":
                            ShoulderScreenCard(item: item, weekNumber: selectedWeek, allResults: allResults)
                        case "skill_markers":
                            SkillMarkersCard(item: item, weekNumber: selectedWeek, allResults: allResults)
                        case "bodyweight":
                            BodyweightCard(item: item, weekNumber: selectedWeek, allResults: allResults)
                        default:
                            EmptyView()
                        }
                    }
                }
            }
            .navigationTitle("Test battery")
            .onAppear {
                if testWeeks.contains(currentWeek) {
                    selectedWeek = currentWeek
                } else {
                    selectedWeek = testWeeks.first ?? 0
                }
            }
        }
    }
}

#Preview {
    TestBatteryView()
        .modelContainer(for: [TestResult.self, AppState.self], inMemory: true)
}
