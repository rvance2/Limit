import Foundation

/// Attempt Discipline rule 3: "3 consecutive attempts worse than the day's best." Extracted
/// from `AttemptLoggerView` so the decline-streak math is unit-testable independent of SwiftUI.
enum AttemptStopRuleLogic {
    /// `highPointHold` is free text and not reliably orderable, so outcome rank stands in for it.
    static func outcomeRank(_ outcome: String) -> Int {
        switch outcome {
        case "Flash": return 3
        case "Send": return 2
        case "Start/Link": return 1
        default: return 0
        }
    }

    /// Counts consecutive attempts (in chronological order) ranked below the running best
    /// established *before* that attempt. Resets on any attempt that matches or beats the
    /// best so far. Only genuine attempts should be passed in — rehearsals and "not genuine"
    /// attempts neither extend nor break the streak per Attempt Discipline rule 3.
    static func decliningStreak(genuineOutcomesInOrder outcomes: [String]) -> Int {
        var bestSoFar = -1
        var streak = 0
        for outcome in outcomes {
            let rank = outcomeRank(outcome)
            if bestSoFar >= 0 && rank < bestSoFar {
                streak += 1
            } else {
                streak = 0
            }
            bestSoFar = max(bestSoFar, rank)
        }
        return streak
    }
}
