import Foundation
import SwiftData

@Observable
final class SeedStore {
    var plan: SeedPlan?
    var modules: [SeedModule] = []
    var sessions: [SeedSession] = []
    var tests: SeedTest?
    var benchmarks: SeedBenchmarks?

    static let shared = SeedStore()

    private init() {
        load()
    }

    private func load() {
        guard let planUrl = Bundle.main.url(forResource: "plan", withExtension: "json", subdirectory: "Seeds"),
              let modulesUrl = Bundle.main.url(forResource: "modules", withExtension: "json", subdirectory: "Seeds"),
              let sessionsUrl = Bundle.main.url(forResource: "sessions", withExtension: "json", subdirectory: "Seeds"),
              let testsUrl = Bundle.main.url(forResource: "tests", withExtension: "json", subdirectory: "Seeds"),
              let benchmarksUrl = Bundle.main.url(forResource: "benchmarks", withExtension: "json", subdirectory: "Seeds") else {
            return
        }

        do {
            let decoder = JSONDecoder()
            self.plan = try decoder.decode(SeedPlan.self, from: try Data(contentsOf: planUrl))
            self.modules = try decoder.decode([SeedModule].self, from: try Data(contentsOf: modulesUrl))
            self.sessions = try decoder.decode([SeedSession].self, from: try Data(contentsOf: sessionsUrl))
            self.tests = try decoder.decode(SeedTest.self, from: try Data(contentsOf: testsUrl))
            self.benchmarks = try decoder.decode(SeedBenchmarks.self, from: try Data(contentsOf: benchmarksUrl))
        } catch {
            print("Failed to load seeds: \(error)")
        }
    }

    func getWeek(number: Int) -> PlanWeek? {
        plan?.weeks.first(where: { $0.week == number })
    }

    func getBlock(id: String) -> PlanBlock? {
        plan?.blocks.first(where: { $0.id == id })
    }

    func getSessionTemplate(id: String) -> SeedSession? {
        sessions.first(where: { $0.id == id })
    }

    func getModule(id: String) -> SeedModule? {
        modules.first(where: { $0.id == id })
    }

    /// Resolves the block number (1-4) for a given blockID like "Block 2".
    func blockNumber(for blockID: String) -> Int? {
        Int(blockID.replacingOccurrences(of: "Block ", with: ""))
    }
}
