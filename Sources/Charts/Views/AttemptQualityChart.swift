import SwiftUI
import SwiftData
import Charts

/// Chart 7 — attempts per week, stacked by kind (genuine / rehearsal / not genuine).
///
/// Bucketed by the attempt's own `timestamp` (via `ChartDataHelpers.weekNumber`), not by
/// joining through `sessionLogID` to a SessionLog/week. `AttemptLoggerView.swift` (Log tab,
/// out of scope here) currently stores a *DayLog's* id in `Attempt.sessionLogID`, not a
/// SessionLog's, so that relationship looks unsettled elsewhere in the app. Bucketing on the
/// attempt's own timestamp sidesteps that ambiguity and is the more reliable read either way.
struct AttemptQualityChart: View {
    @Query private var attempts: [Attempt]
    @Query private var appStates: [AppState]

    private var startDate: Date { appStates.first?.startDate ?? .now }

    private struct WeekKindCount: Identifiable {
        let week: Int
        let kind: String
        let count: Int
        var id: String { "\(week)-\(kind)" }
    }

    private var counts: [WeekKindCount] {
        var byWeekKind: [String: Int] = [:]
        for a in attempts {
            let wk = ChartDataHelpers.weekNumber(for: a.timestamp, startDate: startDate)
            byWeekKind["\(wk)|\(a.kind)", default: 0] += 1
        }
        return byWeekKind.compactMap { key, count in
            let parts = key.split(separator: "|")
            guard parts.count == 2, let week = Int(parts[0]) else { return nil }
            return WeekKindCount(week: week, kind: String(parts[1]), count: count)
        }
    }

    var body: some View {
        ChartCard(
            title: "Attempts per week: genuine, rehearsal, not genuine",
            caption: "Naming the attempt before pulling on (\"this is a real one\" vs \"this is a rehearsal\") keeps the data honest. Attempts that were secretly rehearsals contaminate what I know about whether a move is possible. (Attempt Discipline.md)"
        ) {
            if attempts.isEmpty {
                ChartEmptyState(message: "No attempts logged yet.")
            } else {
                Chart {
                    ForEach(counts) { c in
                        BarMark(
                            x: .value("Week", c.week),
                            y: .value("Attempts", c.count)
                        )
                        .foregroundStyle(by: .value("Kind", ChartDataHelpers.label(forAttemptKind: c.kind)))
                    }
                    planWeekAnnotations()
                }
                .chartForegroundStyleScale([
                    ChartDataHelpers.label(forAttemptKind: "genuine"): ChartDataHelpers.color(forAttemptKind: "genuine"),
                    ChartDataHelpers.label(forAttemptKind: "rehearsal"): ChartDataHelpers.color(forAttemptKind: "rehearsal"),
                    ChartDataHelpers.label(forAttemptKind: "notGenuine"): ChartDataHelpers.color(forAttemptKind: "notGenuine")
                ])
                .frame(height: 200)
            }
        }
    }
}
