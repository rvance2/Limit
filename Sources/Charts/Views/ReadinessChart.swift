import SwiftUI
import SwiftData
import Charts

/// Chart 3 — DayLog.flagCount over time, with HRV and resting HR as secondary series where
/// logged (nil-safe: a day missing HRV or restingHR just doesn't contribute a point to that
/// series rather than breaking the chart).
struct ReadinessChart: View {
    @Query(sort: \DayLog.date) private var dayLogs: [DayLog]
    @Query private var appStates: [AppState]

    private var startDate: Date { appStates.first?.startDate ?? .now }

    private var logsWithFlags: [DayLog] { dayLogs.filter { $0.flagCount != nil } }
    private var logsWithHRV: [DayLog] { dayLogs.filter { $0.hrv != nil } }
    private var logsWithRHR: [DayLog] { dayLogs.filter { $0.restingHR != nil } }

    var body: some View {
        ChartCard(
            title: "Readiness: flags, HRV, resting HR",
            caption: "Count how many are true: HRV ~10% below baseline, sleep under 7 h, resting HR up 5+ bpm, motivation flat, finger stiff on waking. 0-1 as prescribed, 2 downgrade, 3 skill/mobility only, 4-5 rest. (Readiness Monitoring.md)"
        ) {
            if dayLogs.isEmpty {
                ChartEmptyState(message: "No daily readiness logs yet.")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Flag count (0–5)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Chart {
                        ForEach(logsWithFlags, id: \.persistentModelID) { log in
                            BarMark(
                                x: .value("Date", log.date, unit: .day),
                                y: .value("Flags", log.flagCount ?? 0)
                            )
                            .foregroundStyle(.orange.gradient)
                        }
                        planDateAnnotations(startDate: startDate)
                    }
                    .frame(height: 90)

                    Text("HRV (ms) and resting HR (bpm), where logged")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Chart {
                        ForEach(logsWithHRV, id: \.persistentModelID) { log in
                            LineMark(
                                x: .value("Date", log.date, unit: .day),
                                y: .value("Value", log.hrv ?? 0),
                                series: .value("Series", "HRV")
                            )
                            .foregroundStyle(.green)
                        }
                        ForEach(logsWithRHR, id: \.persistentModelID) { log in
                            LineMark(
                                x: .value("Date", log.date, unit: .day),
                                y: .value("Value", log.restingHR ?? 0),
                                series: .value("Series", "Resting HR")
                            )
                            .foregroundStyle(.red)
                        }
                        planDateAnnotations(startDate: startDate)
                    }
                    .frame(height: 90)

                    if logsWithHRV.isEmpty && logsWithRHR.isEmpty {
                        Text("No HRV or resting HR logged yet.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 12) {
                            Label("HRV", systemImage: "circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption2)
                            Label("Resting HR", systemImage: "circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption2)
                        }
                    }
                }
            }
        }
    }
}
