import Foundation
import SwiftData

// `SessionLog` (Sources/Models/Schema.swift) has no stable `id: UUID` field of its own —
// only `DayLog` does. `ExerciseSet.sessionLogID` and `Attempt.sessionLogID` are both typed
// `String` and need something to key against. Rather than touch Schema.swift (out of scope,
// owned by another process), a SessionLog is addressed by a deterministic natural key:
// templateID + calendar day. That's unique for this app's actual usage (one session per
// template per day) and lets `ExerciseSet`/`Attempt` rows be correlated to a `SessionLog`
// purely by string comparison, with no dependency on SwiftData's opaque persistent IDs.
extension SessionLog {
    static func key(templateID: String, date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return "\(templateID)__\(formatter.string(from: day))"
    }

    /// This log's own natural key — use as the value stored in `ExerciseSet.sessionLogID`
    /// and `Attempt.sessionLogID` when attaching child records.
    var key: String {
        SessionLog.key(templateID: templateID, date: date)
    }

    /// Appends a stop-rule event in the documented format:
    /// "<rule>|<itemOrSession>|<ISO8601 timestamp>|overridden:<bool>"
    func logStopRuleEvent(rule: String, item: String, overridden: Bool) {
        let ts = ISO8601DateFormatter().string(from: .now)
        stopRuleEvents.append("\(rule)|\(item)|\(ts)|overridden:\(overridden)")
    }
}
