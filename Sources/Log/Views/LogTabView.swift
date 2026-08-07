import SwiftUI
import SwiftData

/// Root of the Log tab: a segmented control between the live session runner for today and
/// backfill (create/edit a past `SessionLog`). Parameterless and internal so `ContentView`
/// (owned by another process) can drop in `LogTabView()` directly.
struct LogTabView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case today = "Today's Session"
        case backfill = "Backfill"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .today

    @Query(sort: \DayLog.date, order: .reverse) private var dayLogs: [DayLog]
    @Query private var appStates: [AppState]

    @State private var showingSurvey = false

    private var appState: AppState? { appStates.first }

    private var todayLog: DayLog? {
        dayLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    private var currentWeek: Int {
        guard let appState else { return 0 }
        return SessionScheduler.weekNumber(for: .now, startDate: appState.startDate)
    }

    private var sessionTemplateIdForToday: String {
        SessionScheduler.sessionTemplateId(forWeekday: Calendar.current.component(.weekday, from: .now), weekNumber: currentWeek)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                switch mode {
                case .today: todayContent
                case .backfill: AdHocEntryView()
                }
            }
            .navigationTitle("Log")
            .sheet(isPresented: $showingSurvey) {
                MorningSurveyView { }
            }
        }
    }

    @ViewBuilder
    private var todayContent: some View {
        if todayLog == nil {
            VStack(spacing: 12) {
                Spacer()
                Text("Readiness isn't logged for today yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Morning survey") { showingSurvey = true }
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding()
        } else if let session = SeedStore.shared.getSessionTemplate(id: sessionTemplateIdForToday),
                  let weekInfo = SeedStore.shared.getWeek(number: currentWeek) {
            SessionRunnerView(sessionTemplate: session, blockId: weekInfo.blockID, weekNumber: currentWeek, date: .now)
        } else {
            Spacer()
            Text("Nothing scheduled today.")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
