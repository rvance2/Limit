import XCTest
@testable import Limit

final class LoadTests: XCTestCase {

    func test_weeklyLoads_fallsBackToStoredLoadUnitsWhenRPEOrDurationMissing() {
        let start = Calendar.current.startOfDay(for: .now)
        let s1 = SessionLog(date: start, templateID: "S1 Finger Priority", blockID: "Block 1", weekNumber: 0)
        s1.sessionRPE1to10 = 7
        s1.actualDuration = 60 // 7 * 60 = 420

        let s2 = SessionLog(date: start, templateID: "S4 Volume and Skill", blockID: "Block 1", weekNumber: 0)
        s2.loadUnits = 150 // no RPE/duration logged, falls back to stored loadUnits

        let loads = ChartDataHelpers.weeklyLoads(from: [s1, s2], startDate: start)
        XCTAssertEqual(loads.count, 1)
        XCTAssertEqual(loads[0].loadUnits, 570)
    }

    func test_weeklyLoads_sumsAcrossSessionsInTheSameWeek() {
        let start = Calendar.current.startOfDay(for: .now)
        let day2 = Calendar.current.date(byAdding: .day, value: 2, to: start)!
        let s1 = SessionLog(date: start, templateID: "S1 Finger Priority", blockID: "Block 1", weekNumber: 0)
        s1.sessionRPE1to10 = 5
        s1.actualDuration = 60 // 300
        let s2 = SessionLog(date: day2, templateID: "S3 Power and Contact", blockID: "Block 1", weekNumber: 0)
        s2.sessionRPE1to10 = 6
        s2.actualDuration = 50 // 300

        let loads = ChartDataHelpers.weeklyLoads(from: [s1, s2], startDate: start)
        XCTAssertEqual(loads.count, 1)
        XCTAssertEqual(loads[0].loadUnits, 600)
    }
}
