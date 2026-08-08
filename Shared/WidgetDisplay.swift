import SwiftUI

/// Cosmetic lookups the home-screen widget needs but can't get from `SeedStore` (JSON bundled
/// only in the main app target) or `AppState` (SwiftData, not shared across the app/widget
/// process boundary without an App Group). Deliberately small and JSON-free so it stays in sync
/// with `SessionScheduler` by construction rather than by convention.
enum WidgetDisplay {
    /// Week 0 of the plan starts Monday, August 10, 2026. Duplicated from `AppState.planStartDate`
    /// rather than shared, since the widget has no UI path to ever change it and this keeps the
    /// widget target free of a SwiftData dependency.
    static var planStartDate: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 10
        return Calendar.current.date(from: components) ?? .now
    }

    /// Block boundaries per Plan MOC: week 0 baseline, 1-6 Block 1 (incl. its reduced week),
    /// 7-12 Block 2, 13-19 Block 3, 20+ Block 4.
    static func blockNumber(forWeek week: Int) -> Int {
        switch week {
        case 0: return 0
        case 1...6: return 1
        case 7...12: return 2
        case 13...19: return 3
        default: return 4
        }
    }

    static func blockName(forNumber n: Int) -> String {
        switch n {
        case 0: return "Baseline Week"
        case 1: return "Base"
        case 2: return "Max Strength"
        case 3: return "Power and RFD"
        case 4: return "Peak and Send"
        default: return ""
        }
    }

    /// Friendly session name, matching `SeedSession.name` in sessions.json (which differs from
    /// the template id for the two Recovery slots).
    static func displayName(forTemplateId id: String) -> String {
        switch id {
        case "Weekly Recovery": return "Recovery"
        default: return id
        }
    }

    static func shortLabel(forTemplateId id: String) -> String {
        switch id {
        case "Recovery", "Weekly Recovery": return "Rec"
        case "S1 Finger Priority": return "S1"
        case "S2 Limit Boulder": return "S2"
        case "S3 Power and Contact": return "S3"
        case "S4 Volume and Skill": return "S4"
        case "S5 Outdoor Project Day": return "S5"
        case "S6 Skill and Pull": return "S6"
        case "Off": return "Off"
        default: return id
        }
    }

    static func color(forTemplateId id: String) -> Color {
        switch id {
        case "Recovery", "Weekly Recovery": return .mint
        case "S1 Finger Priority": return .blue
        case "S2 Limit Boulder": return .indigo
        case "S3 Power and Contact": return .red
        case "S4 Volume and Skill": return .green
        case "S5 Outdoor Project Day": return .purple
        case "S6 Skill and Pull": return .teal
        default: return .gray // Off
        }
    }

    static func icon(forTemplateId id: String) -> String {
        switch id {
        case "Recovery", "Weekly Recovery": return "leaf.fill"
        case "S1 Finger Priority": return "hand.raised.fill"
        case "S2 Limit Boulder": return "figure.climbing"
        case "S3 Power and Contact": return "bolt.fill"
        case "S4 Volume and Skill": return "arrow.triangle.2.circlepath"
        case "S5 Outdoor Project Day": return "flag.checkered"
        case "S6 Skill and Pull": return "dumbbell.fill"
        default: return "moon.zzz.fill" // Off
        }
    }
}
