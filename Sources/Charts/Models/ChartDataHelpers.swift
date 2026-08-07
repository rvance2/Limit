import Foundation
import SwiftUI
import SwiftData

/// Shared helpers for turning raw SwiftData logs into chart-ready aggregates, and for
/// deriving plan-week x-axis annotations (block boundaries, reduced/test/taper weeks) from
/// `SeedStore.shared.plan`. This is the one place chart code should touch that math so all
/// nine charts agree with each other and with Today/Plan.
enum ChartDataHelpers {

    // MARK: - Week number

    /// Plan week number for an arbitrary date. See `SessionScheduler.weekNumber(for:startDate:)`,
    /// the shared implementation Today/Plan/Log also use.
    static func weekNumber(for date: Date, startDate: Date) -> Int {
        SessionScheduler.weekNumber(for: date, startDate: startDate)
    }

    /// Approximate calendar date for the start of a given plan week. Used to place week-based
    /// RuleMarks on charts whose x-axis is a date rather than a raw week number.
    static func date(forWeek week: Int, startDate: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: week * 7, to: startDate) ?? startDate
    }

    // MARK: - Plan annotations (block boundaries, reduced/test/taper weeks)

    struct WeekAnnotation: Identifiable {
        let week: Int
        let kind: String // "reduced", "test", "taper" (never "training" — see nonTrainingWeeks)
        let isReduced: Bool
        var id: Int { week }
    }

    /// Non-training weeks (reduced / test / taper) from the plan, for colored vertical
    /// RuleMark overlays. Color convention matches `TimelineStripView` in PlanView.swift:
    /// reduced = orange (takes priority — week 12 is both reduced and a test week), test =
    /// blue, taper = purple.
    static var nonTrainingWeeks: [WeekAnnotation] {
        guard let weeks = SeedStore.shared.plan?.weeks else { return [] }
        return weeks.filter { $0.kind != "training" || $0.isReduced }
            .map { WeekAnnotation(week: $0.week, kind: $0.kind, isReduced: $0.isReduced) }
    }

    /// First week number of each block, for neutral dashed block-boundary rules.
    static var blockBoundaryWeeks: [Int] {
        guard let weeks = SeedStore.shared.plan?.weeks else { return [] }
        var seen = Set<String>()
        var result: [Int] = []
        for w in weeks.sorted(by: { $0.week < $1.week }) {
            if !seen.contains(w.blockID) {
                seen.insert(w.blockID)
                result.append(w.week)
            }
        }
        return result
    }

    static func color(forWeekKind kind: String, isReduced: Bool = false) -> Color {
        if isReduced { return .orange }
        switch kind {
        case "test": return .blue
        case "taper": return .purple
        default: return .secondary
        }
    }

    // MARK: - Weekly load / ACWR (chart 2)

    struct WeeklyLoad: Identifiable {
        let week: Int
        let loadUnits: Int
        var id: Int { week }
    }

    /// Sums `sessionRPE1to10 * actualDuration` per plan week (Fatigue.md / Readiness
    /// Monitoring.md: "Session RPE: rate 1-10, multiply by minutes. Sum for the week =
    /// acute."). Falls back to the session's stored `loadUnits` if RPE or duration wasn't
    /// logged, rather than silently dropping the session from the week's total.
    static func weeklyLoads(from sessions: [SessionLog], startDate: Date) -> [WeeklyLoad] {
        var byWeek: [Int: Int] = [:]
        for s in sessions {
            let wk = weekNumber(for: s.date, startDate: startDate)
            let load: Int
            if let rpe = s.sessionRPE1to10, let dur = s.actualDuration {
                load = rpe * dur
            } else if let stored = s.loadUnits {
                load = stored
            } else {
                continue
            }
            byWeek[wk, default: 0] += load
        }
        return byWeek.map { WeeklyLoad(week: $0.key, loadUnits: $0.value) }.sorted { $0.week < $1.week }
    }

    // MARK: - Bodyweight (chart 1)

    /// Most recent logged bodyweight, regardless of test date. Simple by design — the spec
    /// calls for "the most recent TestResult with testItemID == bodyweight, or kg-only if
    /// none logged," not a per-test-date lookup.
    static func mostRecentBodyweightKG(from tests: [TestResult]) -> Double? {
        tests
            .filter { $0.testItemID == "bodyweight" && $0.value != nil }
            .sorted { $0.date > $1.date }
            .first?.value
    }

    // MARK: - Mobility TestResult convention (chart 9)

    /// tests.json's "mobility" item bundles several sub-measurements (box split, ankle
    /// dorsiflexion both sides, hip rotation both sides) behind one protocol description, but
    /// `TestResult` only has one `value`/`unit` pair per row. Convention used here: one
    /// `TestResult` row per sub-measurement, all sharing `testItemID == "mobility"` and the
    /// same `date`/`weekNumber`, distinguished by `protocolVariant` (raw strings below).
    ///
    /// Reconciled with the Tests-battery logging UI (`Sources/Tests/Views/TestItemCards.swift`)
    /// — these raw strings are the ones it actually writes.
    enum MobilityVariant: String, CaseIterable {
        case boxSplitCM = "box_split_cm"
        case boxSplitNormalized = "box_split_normalized"
        case ankleDorsiflexionLeft = "ankle_dorsiflexion_left_cm"
        case ankleDorsiflexionRight = "ankle_dorsiflexion_right_cm"
        case hipRotationLeft = "hip_rotation_left_deg"
        case hipRotationRight = "hip_rotation_right_deg"

        var label: String {
            switch self {
            case .boxSplitCM: return "Box split (cm)"
            case .boxSplitNormalized: return "Box split (% height)"
            case .ankleDorsiflexionLeft: return "Ankle dorsiflexion L (cm)"
            case .ankleDorsiflexionRight: return "Ankle dorsiflexion R (cm)"
            case .hipRotationLeft: return "Hip rotation L (deg)"
            case .hipRotationRight: return "Hip rotation R (deg)"
            }
        }

        /// True for the two variants that share one physical measurement (heel-to-heel) —
        /// grouped together in the chart's "box split" panel rather than plotted separately.
        var isBoxSplit: Bool { self == .boxSplitCM || self == .boxSplitNormalized }
    }

    // MARK: - Crux-type heuristic (chart 6)

    enum CruxTypeGuess: String, CaseIterable {
        case powerful = "Powerful"
        case technical = "Technical"
        case unclassified = "Unclassified"
    }

    /// `Attempt` has no explicit crux-type field (Arousal Calibration.md's "task-dependence"
    /// section wants powerful-vs-technical logged per attempt, but the schema this chart code
    /// must render against doesn't have that column). This guesses from the free-text
    /// `failureMode` / `cueWord` fields using a keyword list — it is a heuristic for
    /// chart-splitting only, not a source of truth, and will misclassify or leave most
    /// attempts "Unclassified" until a real field exists. The correct long-term fix is a
    /// `crux` field on `Attempt` captured at log time; that's Log-tab/schema work outside this
    /// folder's scope.
    static func cruxTypeGuess(for attempt: Attempt) -> CruxTypeGuess {
        let text = ((attempt.failureMode ?? "") + " " + (attempt.cueWord ?? "")).lowercased()
        let powerfulKeywords = ["dyno", "deadpoint", "throw", "campus", "power", "lock", "explosive", "jump", "sprung", "snap", "pop"]
        let technicalKeywords = ["foot", "smear", "toe", "precision", "balance", "flag", "heel", "delicate", "slip", "adjust", "beta", "sequence"]
        if powerfulKeywords.contains(where: text.contains) { return .powerful }
        if technicalKeywords.contains(where: text.contains) { return .technical }
        return .unclassified
    }

    static func color(forCruxType type: CruxTypeGuess) -> Color {
        switch type {
        case .powerful: return .red
        case .technical: return .teal
        case .unclassified: return .secondary
        }
    }

    // MARK: - Attempt kind (chart 7)

    static func label(forAttemptKind kind: String) -> String {
        switch kind {
        case "genuine": return "Genuine"
        case "rehearsal": return "Rehearsal"
        case "notGenuine": return "Not genuine"
        default: return kind
        }
    }

    static func color(forAttemptKind kind: String) -> Color {
        switch kind {
        case "genuine": return .green
        case "rehearsal": return .yellow
        case "notGenuine": return .gray
        default: return .secondary
        }
    }
}
