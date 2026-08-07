import XCTest
@testable import Limit

final class StopRuleTests: XCTestCase {

    // MARK: - Outcome ranking

    func test_outcomeRank_ordering() {
        XCTAssertGreaterThan(AttemptStopRuleLogic.outcomeRank("Flash"), AttemptStopRuleLogic.outcomeRank("Send"))
        XCTAssertGreaterThan(AttemptStopRuleLogic.outcomeRank("Send"), AttemptStopRuleLogic.outcomeRank("Start/Link"))
        XCTAssertGreaterThan(AttemptStopRuleLogic.outcomeRank("Start/Link"), AttemptStopRuleLogic.outcomeRank("Miss"))
    }

    // MARK: - Rule 3: three consecutive attempts worse than the day's best

    func test_threeConsecutiveDeclines_triggersAtExactlyThree() {
        // Best established at Send, then three straight Misses below it.
        let outcomes = ["Send", "Miss", "Miss", "Miss"]
        XCTAssertEqual(AttemptStopRuleLogic.decliningStreak(genuineOutcomesInOrder: outcomes), 3)
    }

    func test_twoConsecutiveDeclines_doesNotTrigger() {
        let outcomes = ["Send", "Miss", "Miss"]
        let streak = AttemptStopRuleLogic.decliningStreak(genuineOutcomesInOrder: outcomes)
        XCTAssertEqual(streak, 2)
        XCTAssertLessThan(streak, 3, "two declines should not trip the stop rule")
    }

    func test_matchingTheBest_resetsTheStreakWithoutExtendingIt() {
        // Send, Miss, Miss (streak=2), Send again (matches best -> resets, doesn't count as
        // decline), Miss, Miss (streak back to 2) — never reaches 3.
        let outcomes = ["Send", "Miss", "Miss", "Send", "Miss", "Miss"]
        XCTAssertEqual(AttemptStopRuleLogic.decliningStreak(genuineOutcomesInOrder: outcomes), 2)
    }

    func test_newBest_resetsStreakAndBecomesTheNewFloor() {
        // Flash raises the bar mid-session; subsequent Sends now count as declines off it.
        let outcomes = ["Send", "Miss", "Flash", "Send", "Send", "Send"]
        // Send(2): streak0 best2. Miss(0<2): streak1. Flash(3): 3<2? no -> reset streak0, best3.
        // Send(2<3): streak1. Send(2<3): streak2. Send(2<3): streak3 -> trips.
        XCTAssertEqual(AttemptStopRuleLogic.decliningStreak(genuineOutcomesInOrder: outcomes), 3)
    }

    func test_emptyOrSingleAttempt_neverTrips() {
        XCTAssertEqual(AttemptStopRuleLogic.decliningStreak(genuineOutcomesInOrder: []), 0)
        XCTAssertEqual(AttemptStopRuleLogic.decliningStreak(genuineOutcomesInOrder: ["Miss"]), 0)
    }

    // MARK: - BlockRef ("all" vs a specific block number)

    func test_blockRef_allAppliesToEveryBlock() {
        let ref = BlockRef.all
        for block in 1...4 {
            XCTAssertTrue(ref.applies(toBlock: block))
        }
    }

    func test_blockRef_numberOnlyAppliesToThatBlock() {
        let ref = BlockRef.number(2)
        XCTAssertFalse(ref.applies(toBlock: 1))
        XCTAssertTrue(ref.applies(toBlock: 2))
        XCTAssertFalse(ref.applies(toBlock: 3))
    }

    // MARK: - Cut-order (§ Session Templates "cuttable" values)

    func test_cuttableValue_noIsNeverCuttable() {
        // `.no` items (the warm-up, Shoulder Protocol, the first three sets of the primary
        // finger method) are the only ones excluded from "cuttable" — `.yes` and
        // `.lastSetOnly` both count as cuttable in some form; SessionRunnerView special-cases
        // `.lastSetOnly` separately to trim only the trailing set rather than hide the item.
        XCTAssertFalse(CuttableValue.no.isCuttable)
        XCTAssertTrue(CuttableValue.yes.isCuttable)
        XCTAssertTrue(CuttableValue.lastSetOnly.isCuttable)
    }
}
