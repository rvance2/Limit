import Foundation

/// Produces Markdown (Obsidian-clean) and CSV (Numbers-clean) exports of the
/// log history. No network involved — everything is written to a temp file
/// and handed to a share sheet by ExportView.
enum ExportService {
    private static let isoDate = ISO8601DateFormatter()

    private static func d(_ date: Date) -> String { isoDate.string(from: date) }

    // MARK: CSV

    /// Quotes a field only when it needs it: contains a comma, a quote, or a newline.
    /// Internal quotes are doubled per RFC 4180, which is what Numbers expects.
    static func csvField(_ raw: String) -> String {
        if raw.contains(",") || raw.contains("\"") || raw.contains("\n") {
            return "\"" + raw.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return raw
    }

    private static func csvRow(_ fields: [String]) -> String {
        fields.map(csvField).joined(separator: ",")
    }

    private static func csvTable(header: [String], rows: [[String]]) -> String {
        var lines = [csvRow(header)]
        lines.append(contentsOf: rows.map(csvRow))
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    static func dayLogCSV(_ logs: [DayLog]) -> String {
        csvTable(
            header: ["date", "hrv", "restingHR", "sleepHours", "sleepQuality1to5", "motivation1to5", "fingerStiffOnWaking", "stiffWhichFinger", "skinScore1to5", "skinCondition", "antihydralApplied", "flagCount", "verdict"],
            rows: logs.sorted { $0.date < $1.date }.map { log in
                [
                    d(log.date),
                    log.hrv.map { String($0) } ?? "",
                    log.restingHR.map { String($0) } ?? "",
                    log.sleepHours.map { String($0) } ?? "",
                    log.sleepQuality1to5.map { String($0) } ?? "",
                    log.motivation1to5.map { String($0) } ?? "",
                    log.fingerStiffOnWaking.map { $0 ? "true" : "false" } ?? "",
                    log.stiffWhichFinger ?? "",
                    log.skinScore1to5.map { String($0) } ?? "",
                    log.skinCondition ?? "",
                    log.antihydralApplied.map { $0 ? "true" : "false" } ?? "",
                    log.flagCount.map { String($0) } ?? "",
                    log.verdict ?? "",
                ]
            }
        )
    }

    static func sessionLogCSV(_ logs: [SessionLog]) -> String {
        csvTable(
            header: ["date", "templateID", "blockID", "weekNumber", "plannedDuration", "actualDuration", "sessionRPE1to10", "loadUnits", "footSlips", "oneLineNote", "attemptBudget", "attemptBudgetLocked"],
            rows: logs.sorted { $0.date < $1.date }.map { log in
                [
                    d(log.date), log.templateID, log.blockID, String(log.weekNumber),
                    log.plannedDuration.map { String($0) } ?? "",
                    log.actualDuration.map { String($0) } ?? "",
                    log.sessionRPE1to10.map { String($0) } ?? "",
                    log.loadUnits.map { String($0) } ?? "",
                    log.footSlips.map { String($0) } ?? "",
                    log.oneLineNote ?? "",
                    log.attemptBudget.map { String($0) } ?? "",
                    log.attemptBudgetLocked ? "true" : "false",
                ]
            }
        )
    }

    static func attemptCSV(_ attempts: [Attempt]) -> String {
        csvTable(
            header: ["timestamp", "sessionLogID", "projectID", "index", "kind", "grade", "outcome", "highPointHold", "failureMode", "arousal1to10", "cueWord"],
            rows: attempts.sorted { $0.timestamp < $1.timestamp }.map { a in
                [
                    d(a.timestamp), a.sessionLogID, a.projectID ?? "", String(a.index), a.kind, a.grade, a.outcome,
                    a.highPointHold ?? "", a.failureMode ?? "", a.arousal1to10.map { String($0) } ?? "", a.cueWord ?? "",
                ]
            }
        )
    }

    static func testResultCSV(_ results: [TestResult]) -> String {
        csvTable(
            header: ["date", "weekNumber", "testItemID", "protocolVariant", "value", "unit", "notes", "mediaRef"],
            rows: results.sorted { $0.date < $1.date }.map { r in
                [
                    d(r.date), String(r.weekNumber), r.testItemID, r.protocolVariant ?? "",
                    r.value.map { String($0) } ?? "", r.unit ?? "", r.notes ?? "", r.mediaRef ?? "",
                ]
            }
        )
    }

    static func conditionsLogCSV(_ logs: [ConditionsLog]) -> String {
        csvTable(
            header: ["date", "airTempC", "rockTempC", "dewPointC", "aspect", "windDescription", "skinScore", "readinessVerdictUsed", "goNoGoScore", "decision"],
            rows: logs.sorted { $0.date < $1.date }.map { c -> [String] in
                let airStr: String = c.airTempC.map { String($0) } ?? ""
                let rockStr: String = c.rockTempC.map { String($0) } ?? ""
                let dewStr: String = c.dewPointC.map { String($0) } ?? ""
                let skinStr: String = c.skinScore.map { String($0) } ?? ""
                let goNoGoStr: String = c.goNoGoScore.map { String($0) } ?? ""
                return [
                    d(c.date), airStr, rockStr, dewStr,
                    c.aspect ?? "", c.windDescription ?? "", skinStr,
                    c.readinessVerdictUsed ?? "", goNoGoStr, c.decision ?? "",
                ]
            }
        )
    }

    static func projectCSV(_ projects: [Project]) -> String {
        csvTable(
            header: ["name", "grade", "rock", "aspect", "approachNotes", "betaSequences", "vectorExperimentsTried", "sessionsCommitted", "sessionsUsed", "mediaRefs"],
            rows: projects.sorted { $0.name < $1.name }.map { p in
                [
                    p.name, p.grade, p.rock ?? "", p.aspect ?? "", p.approachNotes ?? "",
                    p.betaSequences.joined(separator: " | "), p.vectorExperimentsTried.joined(separator: " | "),
                    p.sessionsCommitted.map { String($0) } ?? "", String(p.sessionsUsed), p.mediaRefs.joined(separator: " | "),
                ]
            }
        )
    }

    // MARK: Markdown

    static func markdown(
        dayLogs: [DayLog], sessionLogs: [SessionLog], attempts: [Attempt],
        testResults: [TestResult], conditionsLogs: [ConditionsLog], projects: [Project]
    ) -> String {
        var out = ""
        out += "---\n"
        out += "exported: \(d(.now))\n"
        out += "source: Limit\n"
        out += "entities: [DayLog, SessionLog, Attempt, TestResult, ConditionsLog, Project]\n"
        out += "---\n\n"
        out += "# Limit log export\n\n"
        out += "Exported \(Date.now.formatted(date: .abbreviated, time: .shortened)). Plain markdown, no wikilinks, nothing in here points back into the app.\n\n"

        out += "## Day log\n\n"
        out += "| Date | HRV | RHR | Sleep hrs | Motivation | Skin | Antihydral | Flags | Verdict |\n"
        out += "| --- | --- | --- | --- | --- | --- | --- | --- | --- |\n"
        for log in dayLogs.sorted(by: { $0.date < $1.date }) {
            let dateStr: String = log.date.formatted(date: .abbreviated, time: .omitted)
            let hrvStr: String = log.hrv.map { String($0) } ?? ""
            let rhrStr: String = log.restingHR.map { String($0) } ?? ""
            let sleepStr: String = log.sleepHours.map { String($0) } ?? ""
            let motivationStr: String = log.motivation1to5.map { String($0) } ?? ""
            let skin: String = [log.skinScore1to5.map { String($0) }, log.skinCondition].compactMap { $0 }.joined(separator: " / ")
            let antihydralStr: String = log.antihydralApplied == true ? "yes" : ""
            let flagStr: String = log.flagCount.map { String($0) } ?? ""
            let verdictStr: String = log.verdict ?? ""
            out += "| \(dateStr) | \(hrvStr) | \(rhrStr) | \(sleepStr) | \(motivationStr) | \(skin) | \(antihydralStr) | \(flagStr) | \(verdictStr) |\n"
        }

        out += "\n## Sessions\n\n"
        out += "| Date | Template | Block | Week | RPE | Foot slips | Note |\n"
        out += "| --- | --- | --- | --- | --- | --- | --- |\n"
        for log in sessionLogs.sorted(by: { $0.date < $1.date }) {
            out += "| \(log.date.formatted(date: .abbreviated, time: .omitted)) | \(log.templateID) | \(log.blockID) | \(log.weekNumber) | \(log.sessionRPE1to10.map { String($0) } ?? "") | \(log.footSlips.map { String($0) } ?? "") | \(log.oneLineNote ?? "") |\n"
        }

        out += "\n## Attempts\n\n"
        out += "| Timestamp | Grade | Outcome | Kind | High point | Failure mode |\n"
        out += "| --- | --- | --- | --- | --- | --- |\n"
        for a in attempts.sorted(by: { $0.timestamp < $1.timestamp }) {
            out += "| \(a.timestamp.formatted(date: .abbreviated, time: .shortened)) | \(a.grade) | \(a.outcome) | \(a.kind) | \(a.highPointHold ?? "") | \(a.failureMode ?? "") |\n"
        }

        out += "\n## Test results\n\n"
        out += "| Date | Week | Item | Variant | Value | Unit | Notes |\n"
        out += "| --- | --- | --- | --- | --- | --- | --- |\n"
        for r in testResults.sorted(by: { $0.date < $1.date }) {
            let dateStr: String = r.date.formatted(date: .abbreviated, time: .omitted)
            let variantStr: String = r.protocolVariant ?? ""
            let valueStr: String = r.value.map { String($0) } ?? ""
            let unitStr: String = r.unit ?? ""
            let notesStr: String = r.notes ?? ""
            out += "| \(dateStr) | \(r.weekNumber) | \(r.testItemID) | \(variantStr) | \(valueStr) | \(unitStr) | \(notesStr) |\n"
        }

        out += "\n## Conditions log\n\n"
        out += "| Date | Rock °C | Dew point °C | Aspect | Wind | Skin | Decision |\n"
        out += "| --- | --- | --- | --- | --- | --- | --- |\n"
        for c in conditionsLogs.sorted(by: { $0.date < $1.date }) {
            let dateStr: String = c.date.formatted(date: .abbreviated, time: .omitted)
            let rockStr: String = c.rockTempC.map { String($0) } ?? ""
            let dewStr: String = c.dewPointC.map { String($0) } ?? ""
            let aspectStr: String = c.aspect ?? ""
            let windStr: String = c.windDescription ?? ""
            let skinStr: String = c.skinScore.map { String($0) } ?? ""
            let decisionStr: String = c.decision ?? ""
            out += "| \(dateStr) | \(rockStr) | \(dewStr) | \(aspectStr) | \(windStr) | \(skinStr) | \(decisionStr) |\n"
        }

        out += "\n## Beta Lab projects\n\n"
        for p in projects.sorted(by: { $0.name < $1.name }) {
            out += "### \(p.name), \(p.grade)\n\n"
            if let rock = p.rock { out += "Rock: \(rock)  \n" }
            if let aspect = p.aspect { out += "Aspect: \(aspect)  \n" }
            if let notes = p.approachNotes { out += "Approach: \(notes)  \n" }
            out += "Sessions: \(p.sessionsUsed)" + (p.sessionsCommitted.map { "/\($0)" } ?? "") + "\n\n"
            if !p.betaSequences.isEmpty {
                out += "Beta sequences:\n"
                for s in p.betaSequences { out += "- \(s)\n" }
                out += "\n"
            }
            if !p.vectorExperimentsTried.isEmpty {
                out += "Vector experiments tried:\n"
                for v in p.vectorExperimentsTried { out += "- \(v)\n" }
                out += "\n"
            }
        }

        return out
    }

    // MARK: File writing

    static func writeTempFile(name: String, contents: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
