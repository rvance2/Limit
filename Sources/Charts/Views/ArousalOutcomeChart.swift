import SwiftUI
import SwiftData
import Charts

/// Chart 6 — Attempt.arousal1to10 vs outcome, colored by a crux-type guess (see
/// `ChartDataHelpers.cruxTypeGuess` — a keyword heuristic, not a measured field).
///
/// Note on plan-week annotations: every other chart in this folder gets block-boundary and
/// reduced-week vertical RuleMarks per the brief. This one's x-axis is the categorical
/// `outcome` field (Flash/Send/Start-Link/Miss), not time or week — a week-based vertical
/// rule has no meaningful position on that axis, so it's intentionally omitted here rather
/// than forced onto an axis it doesn't describe.
struct ArousalOutcomeChart: View {
    @Query private var attempts: [Attempt]

    private var scored: [Attempt] { attempts.filter { $0.arousal1to10 != nil } }
    private let outcomeOrder = ["Miss", "Start/Link", "Send", "Flash"]

    var body: some View {
        ChartCard(
            title: "Arousal vs outcome",
            caption: "Common pattern: best attempts cluster at 6-7, not 9-10, because high arousal costs precision before it costs strength. A pattern to check against, not assume as my number. (Arousal Calibration.md)"
        ) {
            if scored.isEmpty {
                ChartEmptyState(message: "No attempts with arousal logged yet.")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Chart {
                        ForEach(scored, id: \.persistentModelID) { attempt in
                            PointMark(
                                x: .value("Outcome", attempt.outcome),
                                y: .value("Arousal", attempt.arousal1to10 ?? 0)
                            )
                            .foregroundStyle(by: .value("Crux type", ChartDataHelpers.cruxTypeGuess(for: attempt).rawValue))
                            .opacity(0.8)
                        }
                    }
                    .chartXScale(domain: outcomeOrder)
                    .chartYScale(domain: 0...10)
                    .chartForegroundStyleScale([
                        ChartDataHelpers.CruxTypeGuess.powerful.rawValue: ChartDataHelpers.color(forCruxType: .powerful),
                        ChartDataHelpers.CruxTypeGuess.technical.rawValue: ChartDataHelpers.color(forCruxType: .technical),
                        ChartDataHelpers.CruxTypeGuess.unclassified.rawValue: ChartDataHelpers.color(forCruxType: .unclassified)
                    ])
                    .frame(height: 200)

                    Text("Crux type is guessed from the failure mode and cue word, not something I log directly yet.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
