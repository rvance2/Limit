import SwiftUI
import SwiftData
import Charts

/// Chart 2 — weekly session load (RPE × minutes), per `ChartDataHelpers.weeklyLoads`.
/// Deliberately just the bars: an acute:chronic ratio line used to sit alongside this, but
/// it's a contested metric and reading a load trend against the block/reduced-week
/// annotations already does the useful job without implying a validated threshold exists.
struct LoadChart: View {
    @Query private var sessions: [SessionLog]
    @Query private var appStates: [AppState]

    private var startDate: Date { appStates.first?.startDate ?? .now }

    private var weeklyLoads: [ChartDataHelpers.WeeklyLoad] {
        ChartDataHelpers.weeklyLoads(from: sessions, startDate: startDate)
    }

    var body: some View {
        ChartCard(
            title: "Session load",
            caption: "Session RPE × minutes, summed per week. A good trend rises gradually through a block and drops in reduced weeks. A week far heavier than recent weeks is the thing worth noticing. (Readiness Monitoring.md)"
        ) {
            if weeklyLoads.isEmpty {
                ChartEmptyState(message: "No sessions logged yet.")
            } else {
                Chart {
                    ForEach(weeklyLoads) { wl in
                        BarMark(
                            x: .value("Week", wl.week),
                            y: .value("Load", wl.loadUnits)
                        )
                        .foregroundStyle(.blue.gradient)
                    }
                    planWeekAnnotations()
                }
                .frame(height: 160)
            }
        }
    }
}
