import XCTest
@testable import Limit

final class SessionSchedulerTests: XCTestCase {

    func test_weekdayMapping_mondayThroughSunday() {
        // Week 5 is inside Block 1 (weeks 1-5), so Tuesday is still S4.
        XCTAssertEqual(SessionScheduler.sessionTemplateId(forWeekday: 2, weekNumber: 5), "S1 Finger Priority") // Mon
        XCTAssertEqual(SessionScheduler.sessionTemplateId(forWeekday: 3, weekNumber: 5), "S4 Volume and Skill") // Tue
        XCTAssertEqual(SessionScheduler.sessionTemplateId(forWeekday: 4, weekNumber: 5), "Recovery") // Wed
        XCTAssertEqual(SessionScheduler.sessionTemplateId(forWeekday: 5, weekNumber: 5), "S3 Power and Contact") // Thu
        XCTAssertEqual(SessionScheduler.sessionTemplateId(forWeekday: 6, weekNumber: 5), "S2 Limit Boulder") // Fri
        XCTAssertEqual(SessionScheduler.sessionTemplateId(forWeekday: 7, weekNumber: 5), "Weekly Recovery") // Sat
        XCTAssertEqual(SessionScheduler.sessionTemplateId(forWeekday: 1, weekNumber: 5), "Off") // Sun
    }

    /// Week Template: "From Block 2 this is replaced on Tuesdays by S6 Skill and Pull. S4
    /// stays as the Block 1 version and the reduced-week version." Reduced weeks are 6, 12, 19.
    func test_tuesday_isS4DuringBlock1AndReducedWeeks() {
        for week in [0, 1, 5, 6, 12, 19] {
            XCTAssertEqual(
                SessionScheduler.sessionTemplateId(forWeekday: 3, weekNumber: week),
                "S4 Volume and Skill",
                "week \(week) Tuesday should be S4"
            )
        }
    }

    func test_tuesday_isS6DuringBlocks2Through4ExceptReducedWeeks() {
        for week in [7, 8, 11, 13, 15, 18, 20, 22] {
            XCTAssertEqual(
                SessionScheduler.sessionTemplateId(forWeekday: 3, weekNumber: week),
                "S6 Skill and Pull",
                "week \(week) Tuesday should be S6"
            )
        }
    }

    /// Plan MOC: "outdoor projecting from week 13." Friday (weekday 6) must default to
    /// S2 before week 13 and S5 from week 13 on — not the same template every week.
    func test_friday_defaultsToS2LimitBoulderBeforeWeek13() {
        for week in [0, 1, 7, 12] {
            XCTAssertEqual(
                SessionScheduler.sessionTemplateId(forWeekday: 6, weekNumber: week),
                "S2 Limit Boulder",
                "week \(week) Friday should default to indoor S2"
            )
        }
    }

    func test_friday_defaultsToS5OutdoorProjectDayFromWeek13() {
        for week in [13, 15, 18, 22] {
            XCTAssertEqual(
                SessionScheduler.sessionTemplateId(forWeekday: 6, weekNumber: week),
                "S5 Outdoor Project Day",
                "week \(week) Friday should default to outdoor S5"
            )
        }
    }

    func test_weekNumber_flooredAtZero() {
        let start = Calendar.current.startOfDay(for: .now)
        let before = Calendar.current.date(byAdding: .day, value: -3, to: start)!
        XCTAssertEqual(SessionScheduler.weekNumber(for: before, startDate: start), 0)
    }

    func test_weekNumber_incrementsEverySevenDays() {
        let start = Calendar.current.startOfDay(for: .now)
        let week2 = Calendar.current.date(byAdding: .day, value: 14, to: start)!
        XCTAssertEqual(SessionScheduler.weekNumber(for: week2, startDate: start), 2)
    }

    // MARK: - FingerMethodResolver

    func test_fingerMethodResolver_block2ResolvesToMEDHangs() {
        XCTAssertEqual(FingerMethodResolver.moduleID(forItemName: "Primary finger method", blockNumber: 2), "MED Hangs")
    }

    func test_fingerMethodResolver_otherBlocksResolveToMaxHangs() {
        for block in [1, 3, 4] {
            XCTAssertEqual(FingerMethodResolver.moduleID(forItemName: "Primary finger method", blockNumber: block), "Max Hangs")
        }
    }

    func test_fingerMethodResolver_displayNameAppendsResolvedModule() {
        XCTAssertEqual(
            FingerMethodResolver.displayName(itemName: "Primary finger method", blockNumber: 1),
            "Primary finger method: Max Hangs"
        )
    }

    func test_fingerMethodResolver_leavesOtherItemsUnchanged() {
        XCTAssertNil(FingerMethodResolver.moduleID(forItemName: "Limit Bouldering", blockNumber: 2))
        XCTAssertEqual(FingerMethodResolver.displayName(itemName: "Limit Bouldering", blockNumber: 2), "Limit Bouldering")
    }
}
