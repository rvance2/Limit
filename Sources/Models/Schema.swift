import Foundation
import SwiftData

@Model
final class DayLog {
    var id: UUID = UUID()
    var date: Date
    var hrv: Double?
    var restingHR: Double?
    var sleepHours: Double?
    var sleepQuality1to5: Int?
    var motivation1to5: Int?
    var fingerStiffOnWaking: Bool?
    var stiffWhichFinger: String?
    var skinScore1to5: Int?
    var antihydralApplied: Bool?
    var flagCount: Int?
    var verdict: String?
    // Skin Programme condition tag: sweaty / correct / dry / glassy / split.
    // Added by the Skin module (Sources/Skin) — the one additive Schema field
    // it's allowed to introduce. Local-only, optional, doesn't affect existing rows.
    var skinCondition: String?

    init(date: Date = .now) {
        self.date = date
    }
}

@Model
final class SessionLog {
    var date: Date
    var templateID: String
    var blockID: String
    var weekNumber: Int
    var plannedDuration: Int? // minutes
    var actualDuration: Int? // minutes
    var sessionRPE1to10: Int?
    var loadUnits: Int?
    var footSlips: Int?
    var oneLineNote: String?
    var completedItems: [String] = []
    // Attempt Discipline rule 2: budget entered before the session starts, then locked.
    var attemptBudget: Int?
    var attemptBudgetLocked: Bool = false
    // Each entry: "<rule>|<itemOrSession>|<ISO8601 timestamp>|<overridden true/false>"
    var stopRuleEvents: [String] = []

    init(date: Date = .now, templateID: String, blockID: String, weekNumber: Int) {
        self.date = date
        self.templateID = templateID
        self.blockID = blockID
        self.weekNumber = weekNumber
    }
}

@Model
final class ExerciseSet {
    var sessionLogID: String
    var moduleID: String
    var edgeMM: Int?
    var addedKG: Double?
    var durationSec: Int?
    var marginSec: Int?
    var setIndex: Int
    var peakForceKG: Double?
    var subjectiveRating: Int?
    var note: String?

    init(sessionLogID: String, moduleID: String, setIndex: Int) {
        self.sessionLogID = sessionLogID
        self.moduleID = moduleID
        self.setIndex = setIndex
    }
}

@Model
final class Attempt {
    var sessionLogID: String
    var projectID: String?
    var index: Int
    var kind: String // genuine, rehearsal, notGenuine
    var grade: String
    var outcome: String // Flash, Send, Start/Link, Miss
    var highPointHold: String?
    var failureMode: String?
    var arousal1to10: Int?
    var cueWord: String?
    var timestamp: Date

    init(sessionLogID: String, index: Int, kind: String, grade: String = "V5", outcome: String = "Miss", timestamp: Date = .now) {
        self.sessionLogID = sessionLogID
        self.index = index
        self.kind = kind
        self.grade = grade
        self.outcome = outcome
        self.timestamp = timestamp
    }
}

@Model
final class Project {
    var name: String
    var grade: String
    var rock: String?
    var aspect: String?
    var approachNotes: String?
    var betaSequences: [String] = []
    var vectorExperimentsTried: [String] = []
    var sessionsCommitted: Int?
    var sessionsUsed: Int = 0
    var mediaRefs: [String] = []

    init(name: String, grade: String) {
        self.name = name
        self.grade = grade
    }
}

@Model
final class TestResult {
    var date: Date
    var weekNumber: Int
    var testItemID: String
    var value: Double?
    var unit: String?
    var notes: String?
    var mediaRef: String?
    var protocolVariant: String?

    init(date: Date = .now, weekNumber: Int, testItemID: String) {
        self.date = date
        self.weekNumber = weekNumber
        self.testItemID = testItemID
    }
}

@Model
final class ConditionsLog {
    var date: Date
    var airTempC: Double?
    var rockTempC: Double?
    var dewPointC: Double?
    var aspect: String?
    var windDescription: String?
    var skinScore: Int?
    var readinessVerdictUsed: String?
    var goNoGoScore: Int?
    var decision: String?

    init(date: Date = .now) {
        self.date = date
    }
}
