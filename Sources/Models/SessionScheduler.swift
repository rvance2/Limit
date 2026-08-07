import Foundation

/// The single source of truth for "which session template runs on this day," used by Today,
/// the Log tab, and Plan. Previously duplicated three ways (one copy per file, from when those
/// were built in parallel by separate processes) — consolidated here so a fix like the
/// Saturday S2/S5 alternation only has to happen once.
enum SessionScheduler {
    /// Reduced weeks per Plan MOC: "The three reduced weeks. Weeks 6, 12, 19." Week 12 is also
    /// a test week (`PlanWeek.kind == "test"`), so this can't be derived from `kind` alone —
    /// see `PlanWeek.isReduced`. Duplicated here as a plain set (rather than a SeedStore lookup)
    /// so this scheduler stays a pure, directly-testable function of (weekday, weekNumber).
    static let reducedWeeks: Set<Int> = [6, 12, 19]

    /// weekday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat (Calendar `.weekday` component).
    ///
    /// Wednesday alternates: per Week Template, S6 Skill and Pull runs Blocks 2-4, and S4
    /// Volume and Skill is "the Block 1 version and the reduced-week version" — so weeks 0-6
    /// (Block 0 + Block 1 + its reduced week) and the other two reduced weeks (12, 19) get S4;
    /// every other week gets S6.
    ///
    /// Saturday alternates: per Plan MOC, "outdoor projecting from week 13" — so weeks 0-12
    /// default to the indoor S2 Limit Boulder, week 13+ default to S5 Outdoor Project Day. The
    /// actual choice on any given Saturday is weather/skin/schedule dependent and the app can't
    /// know that in advance; this is only the calendar default.
    static func sessionTemplateId(forWeekday weekday: Int, weekNumber: Int) -> String {
        switch weekday {
        case 2: return "Monday Recovery"
        case 3: return "S1 Finger Priority"
        case 4: return (weekNumber <= 6 || reducedWeeks.contains(weekNumber)) ? "S4 Volume and Skill" : "S6 Skill and Pull"
        case 5: return "Recovery"
        case 6: return "S3 Power and Contact"
        case 7: return weekNumber >= 13 ? "S5 Outdoor Project Day" : "S2 Limit Boulder"
        default: return "Off"
        }
    }

    static func sessionTemplateId(for date: Date, startDate: Date) -> String {
        sessionTemplateId(
            forWeekday: Calendar.current.component(.weekday, from: date),
            weekNumber: weekNumber(for: date, startDate: startDate)
        )
    }

    /// Plan week = floor(days since `startDate` / 7), clamped to 0. `startDate` is snapped to
    /// the Monday of the launch week (see `TodayView`'s `AppState` creation) so this lines up
    /// with the Mon-Sun slots in Week Template.md.
    static func weekNumber(for date: Date, startDate: Date) -> Int {
        let cal = Calendar.current
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: startDate),
            to: cal.startOfDay(for: date)
        ).day ?? 0
        return max(0, days / 7)
    }
}
