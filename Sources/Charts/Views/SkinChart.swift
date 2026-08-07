import SwiftUI
import SwiftData
import Charts

/// Chart 5 — DayLog.skinScore1to5 over time, with days Antihydral was applied marked as a
/// separate point overlay. One of the more important charts per Skin Programme.md: this is
/// the personal dose-response curve no article can supply.
struct SkinChart: View {
    @Query(sort: \DayLog.date) private var dayLogs: [DayLog]
    @Query private var appStates: [AppState]

    private var startDate: Date { appStates.first?.startDate ?? .now }

    private var logsWithSkin: [DayLog] { dayLogs.filter { $0.skinScore1to5 != nil } }
    private var antihydralDays: [DayLog] {
        logsWithSkin.filter { $0.antihydralApplied == true }
    }

    var body: some View {
        ChartCard(
            title: "Skin",
            caption: "Five is fresh and perfect, one is destroyed. After six weeks of logging this I'll be able to see my own dose-response curve, which no article can give me. (Skin Programme.md)"
        ) {
            if logsWithSkin.isEmpty {
                ChartEmptyState(message: "No skin scores logged yet.")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Chart {
                        ForEach(logsWithSkin, id: \.persistentModelID) { log in
                            LineMark(
                                x: .value("Date", log.date, unit: .day),
                                y: .value("Skin score", Double(log.skinScore1to5 ?? 0))
                            )
                            .foregroundStyle(.brown)
                        }
                        ForEach(antihydralDays, id: \.persistentModelID) { log in
                            PointMark(
                                x: .value("Date", log.date, unit: .day),
                                y: .value("Skin score", Double(log.skinScore1to5 ?? 0))
                            )
                            .foregroundStyle(.cyan)
                            .symbol(.diamond)
                            .symbolSize(90)
                        }
                        planDateAnnotations(startDate: startDate)
                    }
                    .chartYScale(domain: 0...5.5)
                    .frame(height: 200)

                    HStack(spacing: 12) {
                        Label("Skin score 1–5", systemImage: "line.diagonal")
                            .foregroundStyle(.brown)
                            .font(.caption2)
                        Label("Antihydral applied", systemImage: "diamond.fill")
                            .foregroundStyle(.cyan)
                            .font(.caption2)
                    }
                }
            }
        }
    }
}
