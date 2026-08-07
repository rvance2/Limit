import SwiftUI
import SwiftData

/// Attempt logger for Limit Bouldering / project-day items. Target is under ten seconds per
/// attempt: kind/outcome/grade/arousal carry over from the previous attempt so a clean repeat
/// is a single tap, and high point / failure mode / cue word are chip-first with free text as
/// the fallback rather than the default.
struct AttemptLoggerView: View {
    /// `SessionLog.key` — see `Sources/Log/Models/SessionLogKey.swift`.
    let sessionKey: String
    /// What this instance is logging attempts for, e.g. "Limit Bouldering" or "Attempts" (S5).
    /// Used as the `<itemOrSession>` field in `SessionLog.stopRuleEvents` and as the stop-rule
    /// card's exercise-scope label when this item, not the whole session, is what ends.
    let itemLabel: String
    let sessionStopRules: [String]
    let moduleID: String?
    let attemptBudget: Int?
    let ended: Bool
    let onLogged: () -> Void
    let onTrip: (StopRuleTrigger) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var allAttempts: [Attempt]
    @Query private var allSessionLogs: [SessionLog]

    @State private var kind = "genuine"
    @State private var outcome = "Miss"
    @State private var grade = "V5"
    @State private var highPoint = ""
    @State private var failureMode = ""
    @State private var arousal = 5
    @State private var cueWord = ""
    @State private var shoulderSensationChecked = false

    private let kinds = [("genuine", "Genuine"), ("rehearsal", "Rehearsal"), ("notGenuine", "Not genuine")]
    private let grades = ["V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10", "V11", "V12"]
    private let outcomes = ["Flash", "Send", "Start/Link", "Miss"]
    private let highPointChips = ["start", "crux", "lip", "top"]
    private let failureModeChips = ["popped", "foot slipped", "arrived wrong", "didn't commit", "pumped"]
    private let cueWordChips = ["left hip", "commit", "quiet feet", "breathe", "trust it"]

    private var sessionAttempts: [Attempt] {
        allAttempts
            .filter { $0.sessionLogID == sessionKey && $0.projectID == itemLabel }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var genuineCount: Int {
        sessionAttempts.filter { $0.kind == "genuine" }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(itemLabel).font(.headline)
                Spacer()
                if let budget = attemptBudget {
                    Text("Genuine \(genuineCount)/\(budget)")
                        .font(.caption)
                        .foregroundStyle(genuineCount >= budget ? .orange : .secondary)
                }
            }

            // Always visible, faster to press than to ignore.
            HStack(spacing: 8) {
                Button("Hot spot") { tripHotSpot() }
                    .buttonStyle(.borderedProminent).tint(.red)
                Button("Pop / click / sting") { tripPopClickSting() }
                    .buttonStyle(.borderedProminent).tint(.red)
            }
            .font(.caption.bold())
            .disabled(ended)

            Toggle(isOn: $shoulderSensationChecked) {
                Text("Shoulder sensation on that move")
                    .font(.caption)
            }
            .toggleStyle(CheckboxToggleStyle())
            .disabled(ended)
            .onChange(of: shoulderSensationChecked) { _, checked in
                if checked { logShoulderSensation() }
            }

            if shoulderSensationChecked {
                Text("Logged. Abandon that beta, don't repeat it.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if ended {
                Text("Over for this item. Logging is closed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                entryForm
            }

            if !sessionAttempts.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Log").font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(sessionAttempts.enumerated()), id: \.element.id) { idx, a in
                        HStack(alignment: .top) {
                            Text("\(idx + 1)").font(.caption.monospaced()).foregroundStyle(.secondary)
                            Text(kindShort(a.kind)).font(.caption.bold())
                            Text(a.highPointHold?.isEmpty == false ? a.highPointHold! : a.outcome)
                                .font(.caption)
                            Spacer()
                            if let mode = a.failureMode, !mode.isEmpty {
                                Text(mode).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(10)
    }

    private var entryForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Kind", selection: $kind) {
                ForEach(kinds, id: \.0) { k in Text(k.1).tag(k.0) }
            }
            .pickerStyle(.segmented)

            // Horizontal scroll rather than a plain HStack: fixedSize keeps each control's own
            // text from hyphen-wrapping, but that means the row's total width isn't clamped to
            // the parent's — inside a List/Form row (which sometimes centers oversized content
            // instead of clipping it) that bled off both edges of the screen. Scrolling contains
            // it instead.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    Picker("Grade", selection: $grade) {
                        ForEach(grades, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .lineLimit(1)

                    Picker("Outcome", selection: $outcome) {
                        ForEach(outcomes, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .lineLimit(1)

                    Stepper("Arousal \(arousal)", value: $arousal, in: 1...10)
                        .fixedSize()
                        .lineLimit(1)
                }
                .font(.subheadline)
            }

            chipField(title: "High point", text: $highPoint, chips: highPointChips)
            chipField(title: "Failure mode", text: $failureMode, chips: failureModeChips)
            chipField(title: "Cue word", text: $cueWord, chips: cueWordChips)

            Button("Log attempt") { logAttempt() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
    }

    private func chipField(title: String, text: Binding<String>, chips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(chips, id: \.self) { chip in
                        Button(chip) { text.wrappedValue = chip }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .tint(text.wrappedValue == chip ? .blue : .gray)
                    }
                }
            }
            TextField("Custom \(title.lowercased())", text: text)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
        }
    }

    private func kindShort(_ k: String) -> String {
        switch k {
        case "genuine": return "G"
        case "rehearsal": return "R"
        default: return "N"
        }
    }

    private func logAttempt() {
        let att = Attempt(
            sessionLogID: sessionKey,
            index: sessionAttempts.count,
            kind: kind,
            grade: grade,
            outcome: outcome
        )
        att.projectID = itemLabel
        att.highPointHold = highPoint.isEmpty ? nil : highPoint
        att.failureMode = failureMode.isEmpty ? nil : failureMode
        att.arousal1to10 = arousal
        att.cueWord = cueWord.isEmpty ? nil : cueWord
        modelContext.insert(att)
        try? modelContext.save()

        // Situational fields reset; kind/grade/outcome/arousal/cueWord carry forward since
        // they tend to be stable within a session and re-entering them costs taps for nothing.
        highPoint = ""
        failureMode = ""

        onLogged()
        checkDeclineRule()
    }

    /// This is a per-move flag, not a stop condition — Attempt Discipline / S2 / S5 all treat
    /// shoulder sensation on a boulder move as "abandon that beta, don't repeat it," distinct
    /// from the harder "exercise over" rule that applies to loaded modules like Weighted Pulls
    /// or Deadpoint Power (handled in `ExerciseSetEntryView` instead, since that's a full stop).
    private func logShoulderSensation() {
        if let log = allSessionLogs.first(where: { $0.key == sessionKey }) {
            log.logStopRuleEvent(rule: "shoulder-sensation-move", item: itemLabel, overridden: false)
            try? modelContext.save()
        }
    }

    /// Rule 3 heuristic: "3 consecutive attempts worse than the day's best." `highPointHold`
    /// is free text ("crux hold", "worked moves 1-3", ...) and not reliably orderable, so this
    /// compares by `outcome` rank instead (Flash > Send > Start/Link > Miss). Only "genuine"
    /// attempts count toward the streak — rehearsals and "not genuine" attempts are explicitly
    /// carved out by Attempt Discipline rule 3 and neither extend nor break it. "Best" is the
    /// running best *established before* the current attempt, so this tracks decline off a
    /// peak rather than flagging every attempt before the first send of the day.
    private func decliningStreak() -> Int {
        let genuineOutcomes = sessionAttempts.filter { $0.kind == "genuine" }.map(\.outcome)
        return AttemptStopRuleLogic.decliningStreak(genuineOutcomesInOrder: genuineOutcomes)
    }

    private func checkDeclineRule() {
        guard decliningStreak() >= 3 else { return }
        let quote = StopRuleText.quote(keyword: "consecutive", sessionStopRules: sessionStopRules, moduleID: moduleID ?? "Limit Bouldering")
        onTrip(StopRuleTrigger(
            rule: "3-consecutive-decline",
            scope: .session,
            headline: "Session over.",
            quote: quote,
            extra: nil,
            extraNoteToOpen: nil
        ))
    }

    private func tripHotSpot() {
        let quote = StopRuleText.quote(keyword: "hot spot", sessionStopRules: sessionStopRules, moduleID: moduleID ?? "Limit Bouldering")
        onTrip(StopRuleTrigger(
            rule: "hot-spot",
            scope: .session,
            headline: "Session over.",
            quote: quote,
            extra: nil,
            extraNoteToOpen: nil
        ))
    }

    private func tripPopClickSting() {
        let quote = StopRuleText.quote(keyword: "pop", sessionStopRules: sessionStopRules, moduleID: moduleID)
            ?? StopRuleText.bullet(containing: "pop", inModuleStopRules: SeedStore.shared.getModule(id: "Deadpoint Power")?.stopRules)
        onTrip(StopRuleTrigger(
            rule: "pop-click-sting",
            scope: .session,
            headline: "Session over.",
            quote: quote,
            extra: StopRuleText.tendonHealthWarningSigns,
            extraNoteToOpen: StopRuleText.tendonHealthNote
        ))
    }
}
