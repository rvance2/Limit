import Foundation

/// Skin Programme condition tags — Skin Programme.md, "The log":
/// `Date | skin 1-5 | Antihydral? | condition: (sweaty / correct / dry / glassy / split)`
enum SkinCondition: String, CaseIterable, Identifiable {
    case sweaty, correct, dry, glassy, split
    var id: String { rawValue }
    var label: String { rawValue }
}

enum SkinScheduleDay: String, CaseIterable, Identifiable {
    case wednesday = "Wednesday night"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"

    var id: String { rawValue }

    var action: String {
        switch self {
        case .wednesday: return "Thin layer, fingertips and palms. Avoid creases. Wash off after 30-60 min."
        case .thursday: return "Moisturise heavily. No Antihydral."
        case .friday: return "Moisturise. Light file if needed. Assess: too dry, correct, still sweaty?"
        case .saturday: return "Project day. Adjust next week's dose from Friday's assessment."
        }
    }
}

/// Not a UI helper — this is the function a future Plan calendar view can call
/// to show projected skin readiness against a day, without this module owning
/// any Plan UI. Reads the most recent DayLog.skinCondition / skinScore1to5.
enum SkinReadiness {
    static func projectedReadiness(from logs: [DayLog]) -> String {
        let recent = logs
            .filter { $0.skinCondition != nil || $0.skinScore1to5 != nil }
            .sorted { $0.date > $1.date }

        guard let latest = recent.first else {
            return "No skin log yet."
        }

        if let condition = latest.skinCondition {
            switch condition {
            case SkinCondition.split.rawValue:
                return "Split logged \(latest.date.formatted(date: .abbreviated, time: .omitted)). A split takes up to a full week. Skin is the binding constraint on attempt count."
            case SkinCondition.glassy.rawValue:
                return "Glassy at last log. Escalate no further. Moisturise while using it."
            case SkinCondition.sweaty.rawValue:
                return "Still sweaty at last log. Escalate only if Friday reads still sweaty."
            case SkinCondition.dry.rawValue:
                return "Dry at last log. Assess before adding more Antihydral."
            case SkinCondition.correct.rawValue:
                return "Correct at last log, on schedule."
            default:
                break
            }
        }

        if let score = latest.skinScore1to5 {
            return "Skin score \(score)/5 as of \(latest.date.formatted(date: .abbreviated, time: .omitted))."
        }

        return "No recent skin log."
    }

    /// True if the last two logs both read "glassy", or any of the recent logs read "split".
    /// This is the trigger for the warning surfaced in SkinView — not just informational.
    static func shouldWarn(logs: [DayLog]) -> Bool {
        let recent = logs
            .filter { $0.skinCondition != nil }
            .sorted { $0.date > $1.date }
            .prefix(5)

        if recent.contains(where: { $0.skinCondition == SkinCondition.split.rawValue }) {
            return true
        }

        let lastTwo = Array(recent.prefix(2))
        if lastTwo.count == 2 && lastTwo.allSatisfy({ $0.skinCondition == SkinCondition.glassy.rawValue }) {
            return true
        }

        return false
    }
}
