import SwiftUI
import SwiftData
import UserNotifications

/// Live, ordered walkthrough of a session template. Owns exactly one `SessionLog` for
/// (templateID, calendar day) — created lazily on first appearance — and hosts the rest timer,
/// attempt budget lock, stop-rule overlay, and per-item set/attempt entry.
struct SessionRunnerView: View {
    let sessionTemplate: SeedSession
    let blockId: String
    let weekNumber: Int
    let date: Date

    init(sessionTemplate: SeedSession, blockId: String, weekNumber: Int, date: Date = .now) {
        self.sessionTemplate = sessionTemplate
        self.blockId = blockId
        self.weekNumber = weekNumber
        self.date = date
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allSessionLogs: [SessionLog]
    @State private var sessionLog: SessionLog?

    @State private var isShortOnTime = false
    @State private var budgetDraft = ""
    @State private var restTimer = RestTimerController()
    @State private var activeStopRule: StopRuleTrigger?
    @State private var sessionEndedEarly = false
    @State private var endedItemLabels: Set<String> = []
    @State private var showingCompletion = false

    /// Modules with real quantities worth capturing as `ExerciseSet` rows. Everything else in
    /// the plan (Shoulder Protocol, mobility, skill work, Beta Lab, Limit Bouldering itself) is
    /// either a checklist item or logged through `AttemptLoggerView` instead.
    private let setBasedModules: Set<String> = [
        "Max Hangs", "MED Hangs", "Grip Specificity Block", "Recruitment Pulls",
        "Weighted Pulls", "Tension Circuit", "Deadpoint Power", "Contact Strength Ladder",
        "Antagonist and Wrist", "Lower Limb Resilience", "Repeaters",
        "One Arm Progression", "Deep Shoulder Positions"
    ]

    private var blockNumber: Int? { SeedStore.shared.blockNumber(for: blockId) }

    /// Attempt Discipline rule 2 only applies to sessions that actually contain attempts.
    private var needsAttemptBudget: Bool {
        sessionTemplate.items.contains {
            $0.moduleId == "Limit Bouldering" || $0.name.localizedCaseInsensitiveContains("attempt")
        }
    }

    private var visibleItems: [SeedSessionItem] {
        sessionTemplate.items.filter { item in
            if let blocks = item.blocks, let blockNumber, !blocks.contains(blockNumber) { return false }
            if isShortOnTime, item.cuttable == .yes { return false }
            return true
        }
    }

    var body: some View {
        ZStack {
            Group {
                if let log = sessionLog {
                    if needsAttemptBudget && !log.attemptBudgetLocked {
                        setupView(log: log)
                    } else {
                        runnerBody(log: log)
                    }
                } else {
                    ProgressView()
                }
            }

            if let trigger = activeStopRule {
                Color.black.opacity(0.35).ignoresSafeArea()
                StopRuleCardView(
                    trigger: trigger,
                    onEnd: { endFromCard(trigger) },
                    onOverride: { overrideFromCard(trigger) }
                )
            }
        }
        .navigationTitle(sessionTemplate.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let log = sessionLog, !needsAttemptBudget || log.attemptBudgetLocked {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(isShortOnTime ? "Full session" : "Short on time") { isShortOnTime.toggle() }
                        Button("Finish session") { showingCompletion = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onDisappear { restTimer.stop() }
        .task {
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            loadOrCreateSessionLog()
        }
        .sheet(isPresented: $showingCompletion) {
            if let log = sessionLog {
                SessionCompletionView(sessionLog: log) {
                    showingCompletion = false
                    dismiss()
                }
            }
        }
    }

    // MARK: - Session log lifecycle

    private func loadOrCreateSessionLog() {
        guard sessionLog == nil else { return }
        let day = Calendar.current.startOfDay(for: date)
        if let existing = allSessionLogs.first(where: {
            $0.templateID == sessionTemplate.id && Calendar.current.isDate($0.date, inSameDayAs: day)
        }) {
            sessionLog = existing
        } else {
            let new = SessionLog(date: date, templateID: sessionTemplate.id, blockID: blockId, weekNumber: weekNumber)
            modelContext.insert(new)
            try? modelContext.save()
            sessionLog = new
        }
    }

    // MARK: - Setup phase (attempt budget lock)

    private func setupView(log: SessionLog) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Before I start").font(.title2.bold())

                // Attempt Discipline rule 2, quoted verbatim.
                Text("Fixed attempt budget, decided before the session. Six to ten genuine attempts. Written down before I start. Deciding during means deciding while frustrated.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Attempt budget")
                    Spacer()
                    TextField("6-10", text: $budgetDraft)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                }

                if let preSession = sessionTemplate.preSession {
                    Text(MarkdownView.attributed(preSession)).font(.footnote).foregroundStyle(.secondary)
                }

                Button("Start session") { startSession(log: log) }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(Int(budgetDraft) == nil)

                Text("Locks once the session starts. Can't be changed mid-session.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private func startSession(log: SessionLog) {
        guard let budget = Int(budgetDraft) else { return }
        log.attemptBudget = budget
        log.attemptBudgetLocked = true
        try? modelContext.save()
    }

    // MARK: - Live runner

    private func runnerBody(log: SessionLog) -> some View {
        VStack(spacing: 0) {
            if restTimer.isRunning {
                restTimerBar
            }
            List {
                if blockNumber == 1, let variation = sessionTemplate.block1Variation {
                    Section {
                        Text(MarkdownView.attributed(variation)).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if let budget = log.attemptBudget {
                    Section {
                        HStack {
                            Text("Attempt budget").font(.caption)
                            Spacer()
                            Text("\(budget) genuine, locked").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section(header: Text(sessionTemplate.name)) {
                    ForEach(visibleItems) { item in
                        itemRow(item: item, log: log)
                    }
                }
                Section {
                    Button("Finish session") { showingCompletion = true }
                        .frame(maxWidth: .infinity)
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var restTimerBar: some View {
        HStack {
            Text("\(restTimer.label): \(restTimer.timeRemaining / 60):\(String(format: "%02d", restTimer.timeRemaining % 60))")
                .font(.headline)
                .foregroundStyle(.orange)
            Spacer()
            Button("Stop") { restTimer.stop() }
                .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
    }

    @ViewBuilder
    private func itemRow(item: SeedSessionItem, log: SessionLog) -> some View {
        let itemEnded = sessionEndedEarly || endedItemLabels.contains(item.name)
        let effectiveModuleID = resolvedModuleID(for: item)
        let module = effectiveModuleID.flatMap(SeedStore.shared.getModule)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(FingerMethodResolver.displayName(itemName: item.name, blockNumber: blockNumber)).font(.headline)
                if module?.isNonNegotiable == true {
                    Text("non-negotiable")
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
                if isCompleted(item, log: log) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }

            if let variation = item.variation {
                Text(MarkdownView.attributed(variation)).font(.subheadline).foregroundStyle(.secondary)
            }

            if isShortOnTime, item.cuttable == .lastSetOnly {
                Text("Short on time: the trailing sets are cuttable here. Keep the first three.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if let module, let dose = module.dose, !dose.isEmpty {
                Text(MarkdownView.attributed(dose)).font(.subheadline).foregroundStyle(.secondary)
            }

            if let moduleId = effectiveModuleID, setBasedModules.contains(moduleId) {
                ExerciseSetEntryView(
                    sessionKey: log.key,
                    moduleID: moduleId,
                    itemLabel: item.name,
                    sessionStopRules: sessionTemplate.stopRules,
                    minimumRequiredSets: minimumRequiredSets(for: item),
                    isShortOnTime: isShortOnTime,
                    ended: itemEnded,
                    onTrip: handleTrip
                )
            }

            if isAttemptItem(item) {
                AttemptLoggerView(
                    sessionKey: log.key,
                    itemLabel: item.name,
                    sessionStopRules: sessionTemplate.stopRules,
                    moduleID: item.moduleId,
                    attemptBudget: log.attemptBudget,
                    ended: itemEnded,
                    onLogged: { restTimer.start(minutes: isCruxItem(item) ? 5 : 3, label: item.name) },
                    onTrip: handleTrip
                )
            }

            HStack {
                let defaultMinutes = isCruxItem(item) ? 5 : 3
                ForEach([3, 4, 5], id: \.self) { m in
                    Button(m == defaultMinutes ? "\(m)m •" : "\(m)m") {
                        restTimer.start(minutes: m, label: item.name)
                    }
                    .tint(m == defaultMinutes ? .blue : .gray)
                }
                Spacer()
                Button(isCompleted(item, log: log) ? "Undo" : "Done") {
                    toggleCompleted(item, log: log)
                }
                .buttonStyle(.borderedProminent)
                .tint(isCompleted(item, log: log) ? .gray : .blue)
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .padding(.vertical, 4)
        .opacity(itemEnded ? 0.55 : 1.0)
    }

    // MARK: - Item helpers

    /// Resolves "Primary finger method" (S1 item 3, `moduleId: null` in sessions.json) to the
    /// actual per-block module — see `FingerMethodResolver`. So set entry (edge/added weight/
    /// duration/margin) actually has somewhere to go.
    private func resolvedModuleID(for item: SeedSessionItem) -> String? {
        item.moduleId ?? FingerMethodResolver.moduleID(forItemName: item.name, blockNumber: blockNumber)
    }

    private func isAttemptItem(_ item: SeedSessionItem) -> Bool {
        item.moduleId == "Limit Bouldering" || item.name.localizedCaseInsensitiveContains("attempt")
    }

    /// 5 min on crux work — the timer's own justification (PCr resynthesis is functionally
    /// complete at 3-5 min, ~85% of capacity at 60 s) makes the longer default appropriate
    /// wherever attempts are being logged at a limit, not only when the word "crux" appears.
    private func isCruxItem(_ item: SeedSessionItem) -> Bool {
        let text = (item.name + " " + (item.variation ?? "")).lowercased()
        if text.contains("crux") { return true }
        if item.moduleId == "Limit Bouldering" { return true }
        if item.name.localizedCaseInsensitiveContains("attempt") { return true }
        return false
    }

    /// Only "Primary finger method" is `.lastSetOnly` in the current seed data; 3 is its own
    /// documented minimum ("never cut the first three sets"). Any future `.lastSetOnly` item
    /// falls back to the same minimum absent more specific guidance.
    private func minimumRequiredSets(for item: SeedSessionItem) -> Int? {
        guard item.cuttable == .lastSetOnly else { return nil }
        return 3
    }

    private func isCompleted(_ item: SeedSessionItem, log: SessionLog) -> Bool {
        log.completedItems.contains(String(item.order))
    }

    private func toggleCompleted(_ item: SeedSessionItem, log: SessionLog) {
        let key = String(item.order)
        if let idx = log.completedItems.firstIndex(of: key) {
            log.completedItems.remove(at: idx)
        } else {
            log.completedItems.append(key)
        }
        try? modelContext.save()
    }

    // MARK: - Stop rule card actions

    private func handleTrip(_ trigger: StopRuleTrigger) {
        guard activeStopRule == nil else { return }
        activeStopRule = trigger
    }

    private func endFromCard(_ trigger: StopRuleTrigger) {
        sessionLog?.logStopRuleEvent(rule: trigger.rule, item: label(for: trigger), overridden: false)
        try? modelContext.save()
        switch trigger.scope {
        case .session:
            sessionEndedEarly = true
            restTimer.stop()
            activeStopRule = nil
            showingCompletion = true
        case .exercise(let name):
            endedItemLabels.insert(name)
            activeStopRule = nil
        }
    }

    private func overrideFromCard(_ trigger: StopRuleTrigger) {
        sessionLog?.logStopRuleEvent(rule: trigger.rule, item: label(for: trigger), overridden: true)
        try? modelContext.save()
        activeStopRule = nil
    }

    private func label(for trigger: StopRuleTrigger) -> String {
        switch trigger.scope {
        case .session: return "session"
        case .exercise(let name): return name
        }
    }
}
