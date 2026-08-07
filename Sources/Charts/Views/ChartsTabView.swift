import SwiftUI

/// Root view for the Charts tab. Parameterless by design — someone else wires this into
/// ContentView.swift's Charts tab (out of scope here).
///
/// All nine charts read live SwiftData state via their own `@Query`s, so this view has
/// nothing to fetch itself: it's just layout. Every chart handles the zero/few-data-point
/// case itself (see `ChartEmptyState` in ChartCard.swift) since there's little real logged
/// data yet.
struct ChartsTabView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    FingerStrengthChart()
                    LoadChart()
                    ReadinessChart()
                    SleepChart()
                    SkinChart()
                    ArousalOutcomeChart()
                    AttemptQualityChart()
                    FootSlipsChart()
                    MobilityChart()
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Charts")
        }
    }
}

#Preview {
    ChartsTabView()
}
