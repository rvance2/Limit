import XCTest
@testable import Limit

final class ReadinessManagerTests: XCTestCase {

    private func evaluate(
        hrv: Double? = 50, hrvBaseline: Double? = 50, hrvDays: Int = 14,
        rhr: Double? = 50, rhrBaseline: Double? = 50,
        sleep: Double? = 8, motivation: Int? = 4, stiff: Bool? = false
    ) -> ReadinessResult {
        ReadinessManager.evaluate(
            hrvLatest: hrv, hrvBaseline: hrvBaseline, hrvDays: hrvDays,
            rhrLatest: rhr, rhrBaseline: rhrBaseline,
            sleepHours: sleep, motivation: motivation, fingerStiff: stiff
        )
    }

    // MARK: - HRV-available path (0-5 flags)

    func test_zeroFlags_asPrescribed() {
        let r = evaluate()
        XCTAssertEqual(r.flagCount, 0)
        XCTAssertEqual(r.verdict, "As prescribed")
        XCTAssertFalse(r.isDegraded)
    }

    func test_oneFlag_stillAsPrescribed() {
        let r = evaluate(sleep: 6)
        XCTAssertEqual(r.flagCount, 1)
        XCTAssertEqual(r.verdict, "As prescribed")
    }

    func test_twoFlags_downgrade() {
        let r = evaluate(rhr: 60, sleep: 6) // RHR +10 over baseline, sleep < 7
        XCTAssertEqual(r.flagCount, 2)
        XCTAssertTrue(r.verdict.hasPrefix("Downgrade"))
    }

    func test_threeFlags_skillAndMobilityOnly() {
        let r = evaluate(rhr: 60, sleep: 6, motivation: 2)
        XCTAssertEqual(r.flagCount, 3)
        XCTAssertTrue(r.verdict.hasPrefix("Skill and mobility only"))
    }

    func test_fourFlags_rest() {
        let r = evaluate(rhr: 60, sleep: 6, motivation: 2, stiff: true)
        XCTAssertEqual(r.flagCount, 4)
        XCTAssertTrue(r.verdict.hasPrefix("Rest"))
    }

    func test_fiveFlags_rest() {
        // All five, including HRV >10% below the 14-day baseline.
        let r = evaluate(hrv: 40, hrvBaseline: 50, hrvDays: 14, rhr: 60, sleep: 6, motivation: 2, stiff: true)
        XCTAssertEqual(r.flagCount, 5)
        XCTAssertTrue(r.verdict.hasPrefix("Rest"))
    }

    func test_hrvFlag_requiresAtLeastSevenDaysOfBaseline() {
        // HRV would flag (40 vs 50 baseline) but only 3 days of data — flag must not fire.
        let r = evaluate(hrv: 40, hrvBaseline: 50, hrvDays: 3)
        XCTAssertEqual(r.flagCount, 0)
        XCTAssertTrue(r.isDegraded, "fewer than 7 days of HRV data means the degraded (no-HRV) scale applies")
    }

    // MARK: - Degraded no-HRV path (0-4 flags on a 4-flag scale)

    func test_degraded_zeroFlags() {
        let r = evaluate(hrv: nil, hrvBaseline: nil)
        XCTAssertEqual(r.flagCount, 0)
        XCTAssertEqual(r.verdict, "As prescribed")
        XCTAssertTrue(r.isDegraded)
    }

    func test_degraded_twoFlags_downgrade() {
        let r = evaluate(hrv: nil, hrvBaseline: nil, rhr: 60, sleep: 6)
        XCTAssertEqual(r.flagCount, 2)
        XCTAssertTrue(r.verdict.hasPrefix("Downgrade"))
    }

    func test_degraded_fourFlags_rest_maxOnFourFlagScale() {
        // Only 4 flags are possible without HRV (sleep, RHR, motivation, stiffness).
        let r = evaluate(hrv: nil, hrvBaseline: nil, rhr: 60, sleep: 6, motivation: 2, stiff: true)
        XCTAssertEqual(r.flagCount, 4)
        XCTAssertTrue(r.verdict.hasPrefix("Rest"))
    }

    func test_missingMetrics_neverBlockTheSurvey() {
        // Every metric nil except motivation — should just skip unavailable flags, not crash
        // or throw, per "never block the survey on a missing metric."
        let r = evaluate(hrv: nil, hrvBaseline: nil, rhr: nil, rhrBaseline: nil, sleep: nil, motivation: 4, stiff: nil)
        XCTAssertEqual(r.flagCount, 0)
        XCTAssertEqual(r.verdict, "As prescribed")
    }
}
