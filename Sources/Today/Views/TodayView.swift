import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DayLog.date, order: .reverse) private var dayLogs: [DayLog]
    @Query private var appStates: [AppState]
    @Query private var sessionLogs: [SessionLog]

    @State private var showingSurvey = false
    @State private var showingSessionRunner = false
    @State private var showingSettings = false
    
    var appState: AppState? { appStates.first }
    
    var todayLog: DayLog? {
        let calendar = Calendar.current
        return dayLogs.first { calendar.isDateInToday($0.date) }
    }
    
    var currentWeek: Int {
        guard let state = appState else { return 0 }
        return SessionScheduler.weekNumber(for: .now, startDate: state.startDate)
    }

    var isReducedWeek: Bool {
        SeedStore.shared.getWeek(number: currentWeek)?.isReduced ?? false
    }

    var currentBlockNumber: Int? {
        SeedStore.shared.getWeek(number: currentWeek).flatMap { SeedStore.shared.blockNumber(for: $0.blockID) }
    }

    var sessionTemplateIdForToday: String {
        SessionScheduler.sessionTemplateId(forWeekday: Calendar.current.component(.weekday, from: .now), weekNumber: currentWeek)
    }

    /// Whether today's session was already opened — `SessionRunnerView` creates this the
    /// moment it first appears, before anything's actually logged, so its presence just means
    /// "started," not "has entries." Existing either way, since the close button now lets
    /// someone step away mid-session without finishing it.
    var todaySessionLog: SessionLog? {
        sessionLogs.first {
            $0.templateID == sessionTemplateIdForToday && Calendar.current.isDateInToday($0.date)
        }
    }

    private let nonNegotiables: [(label: String, noteTitle: String?)] = [
        ("Shoulder Protocol", "Shoulder Protocol"),
        ("Visualization Protocol ×2", "Visualization Protocol"),
        ("Skin Programme", "Skin Programme"),
        ("Tendon Nutrition Timing (60m before)", "Tendon Nutrition Timing"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let weekInfo = SeedStore.shared.getWeek(number: currentWeek),
                           let blockInfo = SeedStore.shared.getBlock(id: weekInfo.blockID) {
                            HStack {
                                Text("Week \(currentWeek)")
                                    .font(.title2.bold())
                                Text("•")
                                Text(blockInfo.name)
                                    .font(.title3)
                                Spacer()
                            }

                            if let session = SeedStore.shared.getSessionTemplate(id: sessionTemplateIdForToday) {
                                Text(session.name)
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(PlanScheduler.color(forTemplateId: sessionTemplateIdForToday).opacity(0.18))
                                    .foregroundColor(PlanScheduler.color(forTemplateId: sessionTemplateIdForToday))
                                    .cornerRadius(6)
                            }

                            if isReducedWeek {
                                Text("REDUCED WEEK")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Morning Survey
                    VStack(alignment: .leading) {
                        if let log = todayLog, let count = log.flagCount, let verdict = log.verdict {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Readiness")
                                        .font(.headline)
                                    Text("\(count) Flags • \(verdict)")
                                        .font(.subheadline)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        } else {
                            Button(action: { showingSurvey = true }) {
                                HStack {
                                    Text("Morning Survey Required")
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Today's Session — gated behind the morning survey so the verdict is seen first.
                    if let session = SeedStore.shared.getSessionTemplate(id: sessionTemplateIdForToday), todayLog != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today's Session")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(session.name)
                                    .font(.title3.bold())
                                
                                ForEach(visibleItems(for: session)) { item in
                                    let resolvedModuleID = item.moduleId ?? FingerMethodResolver.moduleID(forItemName: item.name, blockNumber: currentBlockNumber)
                                    HStack(alignment: .top) {
                                        Text("•")
                                        VaultLinkedRow(noteTitle: resolvedModuleID) {
                                            VStack(alignment: .leading) {
                                                Text(FingerMethodResolver.displayName(itemName: item.name, blockNumber: currentBlockNumber))
                                                    .foregroundStyle(.primary)
                                                if let time = item.time {
                                                    Text(time)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                }

                                // Finger prescription for this week, resolved from plan.json
                                if session.items.contains(where: { $0.name == "Primary finger method" || $0.moduleId == "Max Hangs" || $0.moduleId == "MED Hangs" }),
                                   let prescription = SeedStore.shared.getWeek(number: currentWeek)?.fingerPrescription {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(prescription.notation)
                                            .font(.caption.monospaced())
                                        Text(prescription.plainLanguage)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Button(todaySessionLog != nil ? "Resume Session" : "Start Session") {
                                    showingSessionRunner = true
                                }
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 8)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Stop Rules — always visible, pulled from today's session template.
                    if let session = SeedStore.shared.getSessionTemplate(id: sessionTemplateIdForToday), !session.stopRules.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stop Rules")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(session.stopRules, id: \.self) { rule in
                                    Text("• \(rule)")
                                }
                            }
                            .font(.subheadline)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }

                    // Non-negotiables — never skippable, persist through reduced weeks.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Non-negotiables")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(nonNegotiables, id: \.label) { item in
                                HStack(alignment: .top) {
                                    Text("•")
                                    VaultLinkedRow(noteTitle: item.noteTitle) {
                                        Text(item.label).foregroundStyle(.primary)
                                    }
                                }
                            }
                        }
                        .font(.subheadline)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)

                    // Tools — standalone features not on the main 5 tabs.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tools")
                            .font(.headline)

                        VStack(spacing: 0) {
                            if [0, 11, 22].contains(currentWeek) {
                                NavigationLink(destination: TestBatteryView()) {
                                    toolRow("Test Battery", systemImage: "gauge.with.dots.needle.67percent")
                                }
                                Divider()
                            }
                            NavigationLink(destination: HangboardTimerView()) {
                                toolRow("Timer", systemImage: "timer")
                            }
                            Divider()
                            NavigationLink(destination: SkinView()) {
                                toolRow("Skin", systemImage: "hand.raised")
                            }
                            Divider()
                            NavigationLink(destination: ConditionsView()) {
                                toolRow("Conditions", systemImage: "cloud.sun")
                            }
                            Divider()
                            NavigationLink(destination: BetaLabView()) {
                                toolRow("Beta Lab", systemImage: "figure.climbing")
                            }
                        }
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Limit")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(for: Note.self) { note in
                NoteView(note: note, manager: StopRuleText.vaultManager)
            }
            .sheet(isPresented: $showingSurvey) {
                MorningSurveyView {
                    // refresh if needed
                }
            }
            .sheet(isPresented: $showingSettings) {
                if let appState {
                    SettingsView(appState: appState)
                }
            }
            .fullScreenCover(isPresented: $showingSessionRunner) {
                if let session = SeedStore.shared.getSessionTemplate(id: sessionTemplateIdForToday),
                   let weekInfo = SeedStore.shared.getWeek(number: currentWeek),
                   todayLog != nil {
                    NavigationStack {
                        SessionRunnerView(sessionTemplate: session, blockId: weekInfo.blockID, weekNumber: currentWeek, date: .now)
                    }
                } else if todayLog == nil {
                    // Force them to do the morning survey first
                    VStack {
                        Text("Please complete the Morning Survey first.")
                        Button("Dismiss") { showingSessionRunner = false }
                    }
                }
            }
            .onAppear {
                if appStates.isEmpty {
                    let newState = AppState(startDate: AppState.planStartDate)
                    modelContext.insert(newState)
                }
            }
        }
    }

    private func visibleItems(for session: SeedSession) -> [SeedSessionItem] {
        session.items.filter { SessionScheduler.itemVisible(blocks: $0.blocks, blockNumber: currentBlockNumber) }
    }

    private func toolRow(_ title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .frame(width: 24)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .foregroundColor(.primary)
    }
}
