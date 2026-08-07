import SwiftUI
import SwiftData

/// Backfill: create or edit a `SessionLog` (with its `ExerciseSet`s and `Attempt`s) for a day
/// that already happened. Reached from a picker of past dates plus a "new manual entry" option.
/// Every numeric field is optional — a half-filled log is more useful than an abandoned one.
struct AdHocEntryView: View {
    @Query(sort: \SessionLog.date, order: .reverse) private var allLogs: [SessionLog]
    @Query private var appStates: [AppState]

    @State private var showingNewEntry = false

    private var appState: AppState? { appStates.first }

    var body: some View {
        List {
            if allLogs.isEmpty {
                Text("No sessions logged yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(allLogs) { log in
                NavigationLink {
                    SessionLogBackfillEditor(sessionLog: log)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(log.date.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                            Spacer()
                            if let rpe = log.sessionRPE1to10 {
                                Text("RPE \(rpe)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text(log.templateID).font(.subheadline).foregroundStyle(.secondary)
                        if let note = log.oneLineNote, !note.isEmpty {
                            Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
        }
        .navigationTitle("Backfill")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNewEntry = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            NewBackfillEntrySheet(appState: appState)
        }
    }
}

/// Date + optional template picker for a brand new backfilled entry. Creates the `SessionLog`
/// and hands off to the same editor used for existing logs.
private struct NewBackfillEntrySheet: View {
    let appState: AppState?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allLogs: [SessionLog]

    @State private var date = Date.now
    @State private var templateID = "Manual Entry"
    @State private var createdLog: SessionLog?

    private var templateOptions: [String] {
        ["Manual Entry"] + SeedStore.shared.sessions.map(\.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                Picker("Template", selection: $templateID) {
                    ForEach(templateOptions, id: \.self) { Text($0).tag($0) }
                }
            }
            .navigationTitle("New entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                }
            }
            .navigationDestination(item: $createdLog) { log in
                SessionLogBackfillEditor(sessionLog: log)
            }
        }
    }

    private func create() {
        let day = Calendar.current.startOfDay(for: date)
        if let existing = allLogs.first(where: {
            $0.templateID == templateID && Calendar.current.isDate($0.date, inSameDayAs: day)
        }) {
            createdLog = existing
            return
        }
        let weekNumber = defaultWeekNumber(for: day)
        let blockID = SeedStore.shared.getWeek(number: weekNumber)?.blockID ?? "Block 1"
        let log = SessionLog(date: day, templateID: templateID, blockID: blockID, weekNumber: weekNumber)
        modelContext.insert(log)
        try? modelContext.save()
        createdLog = log
    }

    // Same week-from-start-date arithmetic as `TodayView.currentWeek`.
    private func defaultWeekNumber(for date: Date) -> Int {
        guard let appState else { return 0 }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: appState.startDate),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0
        return max(0, days / 7)
    }
}

/// Full editor for one `SessionLog`: header fields, sets (grouped by module), and attempts.
/// Reuses `ExerciseSetEntryView` / `AttemptLoggerView` for consistency with the live runner,
/// but with stop-rule trips logged silently (no interrupting card) — enforcement is a live-
/// session concern; backfill is just recording what already happened.
struct SessionLogBackfillEditor: View {
    @Bindable var sessionLog: SessionLog

    @Environment(\.modelContext) private var modelContext
    @Query private var allSets: [ExerciseSet]

    @State private var showingAddModule = false

    private var template: SeedSession? { SeedStore.shared.getSessionTemplate(id: sessionLog.templateID) }

    private var loggedModuleIDs: [String] {
        Array(Set(allSets.filter { $0.sessionLogID == sessionLog.key }.map(\.moduleID))).sorted()
    }

    var body: some View {
        Form {
            Section(header: Text("Session"), footer: Text("Load units = session RPE × duration in minutes. It's computed from those two fields automatically for the charts. Only set it directly if backfilling without one of them.")) {
                DatePicker("Date", selection: $sessionLog.date, in: ...Date.now, displayedComponents: .date)
                HStack {
                    Text("Week"); Spacer()
                    Stepper("\(sessionLog.weekNumber)", value: $sessionLog.weekNumber, in: 0...22)
                }
                TextField("Block", text: $sessionLog.blockID)
                optionalIntField("Planned duration (min)", value: $sessionLog.plannedDuration)
                optionalIntField("Actual duration (min)", value: $sessionLog.actualDuration)
                optionalIntField("Session RPE (1-10)", value: $sessionLog.sessionRPE1to10)
                optionalIntField("Load units", value: $sessionLog.loadUnits)
                optionalIntField("Foot slips", value: $sessionLog.footSlips)
                TextField("One-line note", text: Binding(
                    get: { sessionLog.oneLineNote ?? "" },
                    set: { sessionLog.oneLineNote = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
            }

            if let template {
                Section(header: Text("Completed items")) {
                    ForEach(template.items) { item in
                        let key = String(item.order)
                        Toggle(item.name, isOn: Binding(
                            get: { sessionLog.completedItems.contains(key) },
                            set: { on in
                                if on { sessionLog.completedItems.append(key) }
                                else { sessionLog.completedItems.removeAll { $0 == key } }
                                save()
                            }
                        ))
                        .font(.caption)
                    }
                }
            }

            Section(header: Text("Sets")) {
                ForEach(loggedModuleIDs, id: \.self) { moduleID in
                    ExerciseSetEntryView(
                        sessionKey: sessionLog.key,
                        moduleID: moduleID,
                        itemLabel: moduleID,
                        sessionStopRules: template?.stopRules ?? [],
                        minimumRequiredSets: nil,
                        isShortOnTime: false,
                        ended: false,
                        onTrip: logSilently
                    )
                }
                Button("Add module") { showingAddModule = true }
                    .font(.caption)
            }

            Section(header: Text("Attempts")) {
                AttemptLoggerView(
                    sessionKey: sessionLog.key,
                    itemLabel: sessionLog.templateID,
                    sessionStopRules: template?.stopRules ?? [],
                    moduleID: nil,
                    attemptBudget: sessionLog.attemptBudget,
                    ended: false,
                    onLogged: {},
                    onTrip: logSilently
                )
            }

            if !sessionLog.stopRuleEvents.isEmpty {
                Section(header: Text("Stop rule events")) {
                    ForEach(sessionLog.stopRuleEvents, id: \.self) { event in
                        Text(event).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(sessionLog.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: sessionLog.date) { _, _ in save() }
        .onChange(of: sessionLog.weekNumber) { _, _ in save() }
        .onChange(of: sessionLog.blockID) { _, _ in save() }
        .onChange(of: sessionLog.plannedDuration) { _, _ in save() }
        .onChange(of: sessionLog.actualDuration) { _, _ in save() }
        .onChange(of: sessionLog.sessionRPE1to10) { _, _ in save() }
        .onChange(of: sessionLog.loadUnits) { _, _ in save() }
        .onChange(of: sessionLog.footSlips) { _, _ in save() }
        .onChange(of: sessionLog.oneLineNote) { _, _ in save() }
        .onDisappear { save() }
        .confirmationDialog("Add module", isPresented: $showingAddModule, titleVisibility: .visible) {
            ForEach(SeedStore.shared.modules.map(\.id).filter { !loggedModuleIDs.contains($0) }, id: \.self) { id in
                Button(id) { addPlaceholderSet(moduleID: id) }
            }
        }
    }

    private func optionalIntField(_ label: String, value: Binding<Int?>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("-", text: Binding(
                get: { value.wrappedValue.map(String.init) ?? "" },
                set: { value.wrappedValue = Int($0) }
            ))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 70)
        }
    }

    /// Adding a module creates one empty set so it shows up in the "Sets" section above —
    /// the user fills in the actual numbers (or doesn't; every field there is optional too).
    private func addPlaceholderSet(moduleID: String) {
        let set = ExerciseSet(sessionLogID: sessionLog.key, moduleID: moduleID, setIndex: 0)
        modelContext.insert(set)
        save()
    }

    private func logSilently(_ trigger: StopRuleTrigger) {
        let item: String
        switch trigger.scope {
        case .session: item = "session"
        case .exercise(let name): item = name
        }
        sessionLog.logStopRuleEvent(rule: trigger.rule, item: item, overridden: false)
        save()
    }

    private func save() {
        try? modelContext.save()
    }
}
