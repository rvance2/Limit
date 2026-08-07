import Foundation
import SwiftData

/// Upsert helpers for TestResult rows keyed by (weekNumber, testItemID, protocolVariant).
/// Every card in the test battery goes through this so re-entering a value for the same
/// week/item/variant overwrites rather than duplicates.
enum TestResultStore {
    static func find(in results: [TestResult], weekNumber: Int, testItemID: String, protocolVariant: String?) -> TestResult? {
        results.first {
            $0.weekNumber == weekNumber && $0.testItemID == testItemID && $0.protocolVariant == protocolVariant
        }
    }

    @discardableResult
    static func upsert(
        context: ModelContext,
        existing: [TestResult],
        weekNumber: Int,
        testItemID: String,
        protocolVariant: String? = nil,
        value: Double? = nil,
        unit: String? = nil,
        notes: String? = nil,
        mediaRef: String? = nil
    ) -> TestResult {
        if let match = find(in: existing, weekNumber: weekNumber, testItemID: testItemID, protocolVariant: protocolVariant) {
            match.value = value
            match.unit = unit
            match.notes = notes
            match.mediaRef = mediaRef
            match.date = .now
            return match
        } else {
            let result = TestResult(weekNumber: weekNumber, testItemID: testItemID)
            result.protocolVariant = protocolVariant
            result.value = value
            result.unit = unit
            result.notes = notes
            result.mediaRef = mediaRef
            context.insert(result)
            return result
        }
    }
}
