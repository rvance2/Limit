import SwiftUI
import SwiftData

struct SeedPlan: Codable {
    let blocks: [PlanBlock]
    let weeks: [PlanWeek]
    let reducedWeekRule: String?
    let progressionRule: String?
}

struct PlanWeek: Codable {
    let week: Int
    let blockID: String
    let kind: String
    /// True for weeks 6, 12, 19. Independent of `kind` because week 12 is deliberately both
    /// reduced *and* a test week ("rested numbers are comparable numbers" — Plan MOC) — `kind`
    /// stays "test" there while this still flags the 60%-volume/85-90%-intensity reduced-week
    /// training rules as active.
    let isReduced: Bool
    let fingerPrescription: FingerPrescription?
}

struct FingerPrescription: Codable {
    let notation: String
    let frequency: String
    let plainLanguage: String
    let note: String?
}

struct PlanBlock: Codable {
    let id: String
    let name: String
}

// A module's `blocks` frontmatter is either a list of block numbers ([1, 2, 4]) or the
// literal string "all" — both appear across the 30 module notes.
enum BlockRef: Codable, Hashable {
    case number(Int)
    case all
    /// A block number with a caveat, e.g. "1 from week 4" (Recruitment Pulls enters Block 1
    /// partway through). Stores the raw text for display and derives the leading block number
    /// for `applies(toBlock:)` matching.
    case conditional(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .number(intValue)
        } else if let strValue = try? container.decode(String.self) {
            if strValue == "all" {
                self = .all
            } else if let leading = Int(strValue.prefix(while: \.isNumber)) {
                self = .conditional(strValue)
                _ = leading // silence unused-warning; kept for clarity at call sites
            } else {
                self = .conditional(strValue)
            }
        } else {
            self = .all
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let n): try container.encode(n)
        case .all: try container.encode("all")
        case .conditional(let text): try container.encode(text)
        }
    }

    /// True if this module applies to the given block number (1-4).
    func applies(toBlock block: Int) -> Bool {
        switch self {
        case .all: return true
        case .number(let n): return n == block
        case .conditional(let text): return Int(text.prefix(while: \.isNumber)) == block
        }
    }

    /// The caveat text, if this is a `.conditional` ref, e.g. "from week 4".
    var caveat: String? {
        guard case .conditional(let text) = self else { return nil }
        let digits = text.prefix(while: \.isNumber)
        return String(text.dropFirst(digits.count)).trimmingCharacters(in: .whitespaces)
    }
}

struct SeedModule: Codable {
    let id: String
    let name: String
    let folder: String
    let trains: [String]?
    let blocks: [BlockRef]?
    let frequency: String?
    let placement: String?
    let dose: String?
    let progressionRule: String?
    let stopRules: String?

    var isNonNegotiable: Bool {
        ["Shoulder Protocol", "Hip and Ankle Mobility", "Visualization Protocol", "Skin Programme"].contains(id)
    }

    /// True if this module applies to the given block number (1-4), or if `blocks` is unset.
    func applies(toBlock block: Int) -> Bool {
        guard let blocks else { return true }
        return blocks.contains { $0.applies(toBlock: block) }
    }
}

struct SeedSession: Codable {
    let id: String
    let name: String
    let day: String?
    let duration: String?
    let items: [SeedSessionItem]
    let block1Variation: String?
    let preSession: String?
    let stopRules: [String]
    let shortOnTimeNote: String?
}

struct SeedSessionItem: Codable, Identifiable, Hashable {
    let order: Int
    let name: String
    let moduleId: String?
    let time: String?
    let blocks: [Int]?
    let variation: String?
    let cuttable: CuttableValue

    var id: Int { order }
}

// `cuttable` is either a bool or the string "lastSetOnly" in the seed JSON.
enum CuttableValue: Codable, Hashable {
    case no
    case yes
    case lastSetOnly

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            self = bool ? .yes : .no
        } else if let str = try? container.decode(String.self), str == "lastSetOnly" {
            self = .lastSetOnly
        } else {
            self = .no
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .no: try container.encode(false)
        case .yes: try container.encode(true)
        case .lastSetOnly: try container.encode("lastSetOnly")
        }
    }

    var isCuttable: Bool { self != .no }
}

struct SeedTest: Codable {
    let items: [TestItem]
    let testWeeks: [Int]
}

struct TestItem: Codable {
    let id: String
    let name: String
    let unit: String?
    let protocolText: String?
    let shoulderModification: String?
    let variants: [String]?
    let requiresLoadCell: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, unit, protocolText = "protocol", shoulderModification, variants, requiresLoadCell
    }
}

// MARK: - benchmarks.json

struct SeedBenchmarks: Codable {
    let twoArm7sHang: BenchmarkTable
    let oneArmPull: BenchmarkTable
    /// One Arm Progression's own hold-time targets (seconds), not population data — see
    /// `BenchmarkRow.isTarget`.
    let oneArmLockOff: BenchmarkTable?
    let conditions: ConditionsBenchmarks
    let readinessRuleFlags: ReadinessRuleFlags
}

struct BenchmarkTable: Codable {
    let edge: String?
    let unit: String
    let note: String?
    let rows: [BenchmarkRow]
}

struct BenchmarkRow: Codable, Identifiable {
    let grade: String
    let percentBW: Double
    let provenance: String // "published", "interpolated", or "target"
    let source: String

    var id: String { grade }
    var isPublished: Bool { provenance == "published" }
    /// A programme target (e.g. One Arm Progression's lock-off times) rather than population
    /// data — chart against my own history, not this table.
    var isTarget: Bool { provenance == "target" }
}

struct ConditionsBenchmarks: Codable {
    let unit: String
    let rows: [ConditionsRow]
    let rockTempMustExceedDewPoint: Bool
    let spreadRules: SpreadRules
    let goNoGo: GoNoGo
}

struct ConditionsRow: Codable, Identifiable {
    let verdict: String
    let range: [Double]
    var id: String { verdict }
}

struct SpreadRules: Codable {
    let dryingAboveC: Double
    let nearCondensingBelowC: Double
}

struct GoNoGo: Codable {
    let inputs: [String]
    let badThreshold: Int
    let totalInputs: Int
    let note: String
}

struct ReadinessRuleFlags: Codable {
    let flags: [ReadinessFlagDef]
    let verdicts: [ReadinessVerdictRange]
    let degradedNoHRV: DegradedReadiness
}

struct ReadinessFlagDef: Codable, Identifiable {
    let id: String
    let description: String
    let requiresDays: Int?
}

struct ReadinessVerdictRange: Codable {
    let flagRange: [Int]
    let verdict: String
}

struct DegradedReadiness: Codable {
    let scale: Int
    let verdicts: [ReadinessVerdictRange]
}

@main
struct LimitApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DayLog.self,
            SessionLog.self,
            ExerciseSet.self,
            Attempt.self,
            Project.self,
            TestResult.self,
            ConditionsLog.self,
            AppState.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            LimitApp.loadSeedsAndPrintCount()
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }

    static func loadSeedsAndPrintCount() {
        guard let planUrl = Bundle.main.url(forResource: "plan", withExtension: "json", subdirectory: "Seeds"),
              let modulesUrl = Bundle.main.url(forResource: "modules", withExtension: "json", subdirectory: "Seeds"),
              let sessionsUrl = Bundle.main.url(forResource: "sessions", withExtension: "json", subdirectory: "Seeds"),
              let testsUrl = Bundle.main.url(forResource: "tests", withExtension: "json", subdirectory: "Seeds"),
              let benchmarksUrl = Bundle.main.url(forResource: "benchmarks", withExtension: "json", subdirectory: "Seeds") else {
            print("Failed to locate seed files.")
            return
        }

        do {
            let planData = try Data(contentsOf: planUrl)
            let modulesData = try Data(contentsOf: modulesUrl)
            let sessionsData = try Data(contentsOf: sessionsUrl)
            let testsData = try Data(contentsOf: testsUrl)
            let benchmarksData = try Data(contentsOf: benchmarksUrl)

            let decoder = JSONDecoder()
            let plan = try decoder.decode(SeedPlan.self, from: planData)
            let modules = try decoder.decode([SeedModule].self, from: modulesData)
            let sessions = try decoder.decode([SeedSession].self, from: sessionsData)
            let tests = try decoder.decode(SeedTest.self, from: testsData)
            
            // We just parse benchmarks as a generic dictionary for the count check
            let benchmarks = try JSONSerialization.jsonObject(with: benchmarksData, options: []) as? [String: Any]

            let reducedWeeksCount = plan.weeks.filter(\.isReduced).count
            print("plan.json: \(plan.weeks.count) weeks, \(plan.blocks.count) blocks, \(reducedWeeksCount) reduced weeks")
            print("modules.json: \(modules.count) modules")
            print("sessions.json: \(sessions.count) session templates")
            print("tests.json: \(tests.items.count) test items, \(tests.testWeeks.count) test weeks")
            print("benchmarks.json: \(benchmarks?.keys.contains("twoArm7sHang") == true ? 2 : 0) finger tables, \(benchmarks?.keys.contains("conditions") == true ? 1 : 0) conditions table, \(benchmarks?.keys.contains("readinessRuleFlags") == true ? 1 : 0) readiness rule")
        } catch {
            print("Failed to decode seed JSON files: \(error)")
        }
    }
}
