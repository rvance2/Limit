import SwiftUI
import SwiftData
import Charts

/// Chart 4 — DayLog.sleepHours over time against the 8.5 h (training day) and 9 h (project
/// day) targets from Sleep.md.
struct SleepChart: View {
    @Query(sort: \DayLog.date) private var dayLogs: [DayLog]
    @Query private var appStates: [AppState]

    private var startDate: Date { appStates.first?.startDate ?? .now }

    private var logsWithSleep: [DayLog] { dayLogs.filter { $0.sleepHours != nil } }

    var body: some View {
        ChartCard(
            title: "Sleep",
            caption: "8.5–9 h in bed on training days, 9+ before a project day; fixed wake time, consistency beats duration for the circadian part. (Sleep.md)"
        ) {
            if logsWithSleep.isEmpty {
                ChartEmptyState(message: "No sleep hours logged yet.")
            } else {
                Chart {
                    ForEach(logsWithSleep, id: \.persistentModelID) { log in
                        LineMark(
                            x: .value("Date", log.date, unit: .day),
                            y: .value("Hours", log.sleepHours ?? 0)
                        )
                        .foregroundStyle(.indigo)
                        .symbol(.circle)
                    }
                    RuleMark(y: .value("Target", 8.5))
                        .foregroundStyle(Color.gray.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("8.5 h, training day")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    RuleMark(y: .value("Target", 9.0))
                        .foregroundStyle(Color.gray.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        .annotation(position: .bottom, alignment: .leading) {
                            Text("9 h, project day")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    planDateAnnotations(startDate: startDate)
                }
                .frame(height: 200)
            }
        }
    }
}
