import SwiftUI
import SwiftData
import Charts

/// Chart 8 — SessionLog.footSlips over time. Per Footwork Precision.md, one of the few skill
/// metrics available without motion capture, and the cheapest to log.
struct FootSlipsChart: View {
    @Query(sort: \SessionLog.date) private var sessions: [SessionLog]
    @Query private var appStates: [AppState]

    private var startDate: Date { appStates.first?.startDate ?? .now }

    private var logged: [SessionLog] { sessions.filter { $0.footSlips != nil } }

    var body: some View {
        ChartCard(
            title: "Foot slips per session",
            caption: "One of the few skill metrics available without motion capture. A number that halves over six weeks is real progress. (Footwork Precision.md)"
        ) {
            if logged.isEmpty {
                ChartEmptyState(message: "No foot slip counts logged yet.")
            } else {
                Chart {
                    ForEach(logged, id: \.persistentModelID) { s in
                        LineMark(
                            x: .value("Date", s.date, unit: .day),
                            y: .value("Foot slips", s.footSlips ?? 0)
                        )
                        .foregroundStyle(.mint)
                        .symbol(.circle)
                    }
                    planDateAnnotations(startDate: startDate)
                }
                .frame(height: 200)
            }
        }
    }
}
