import SwiftUI
import SwiftData

// Standalone Skin entry point. Expected to be linked from: Today (as part of
// the daily flow, alongside the morning survey) and Plan (project-day skin
// readiness, via SkinReadiness.projectedReadiness). Parameterless.
struct SkinView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DayLog.date, order: .reverse) private var dayLogs: [DayLog]

    @State private var skinScore = 3
    @State private var condition: SkinCondition = .correct
    @State private var antihydralApplied = false

    private var todayLog: DayLog? {
        dayLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    private var recentLogs: [DayLog] {
        Array(dayLogs.filter { $0.skinCondition != nil || $0.skinScore1to5 != nil }.prefix(10))
    }

    private var showWarning: Bool {
        SkinReadiness.shouldWarn(logs: dayLogs)
    }

    var body: some View {
        NavigationStack {
            Form {
                if showWarning {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Moisturise while using it. The step I'd skip and why I'd split.")
                                .font(.subheadline.weight(.semibold))
                            Text("Off the finger creases. Repeated application there causes splitting over time.")
                                .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                        .foregroundStyle(.red)
                    } header: {
                        Text("Warning")
                    }
                }

                Section("Today") {
                    Picker("Skin score (1-5)", selection: $skinScore) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    Text("Five is fresh and perfect, one is destroyed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Condition", selection: $condition) {
                        ForEach(SkinCondition.allCases) { c in
                            Text(c.label).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Antihydral applied", isOn: $antihydralApplied)

                    Button("Log it") { save() }
                        .buttonStyle(.borderedProminent)
                }

                Section("Schedule (Friday project day)") {
                    ForEach(SkinScheduleDay.allCases) { day in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.rawValue).font(.subheadline.weight(.semibold))
                            Text(day.action).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    Text("Escalate only if Thursday reads still sweaty.")
                        .font(.caption.weight(.semibold))
                }

                if !recentLogs.isEmpty {
                    Section("Recent log") {
                        ForEach(recentLogs) { log in
                            HStack {
                                Text(log.date.formatted(date: .abbreviated, time: .omitted))
                                Spacer()
                                if let score = log.skinScore1to5 {
                                    Text("\(score)/5")
                                }
                                if let cond = log.skinCondition {
                                    Text(cond).foregroundStyle(.secondary)
                                }
                                if log.antihydralApplied == true {
                                    Image(systemName: "drop.fill").foregroundStyle(.blue).imageScale(.small)
                                }
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Skin")
            .onAppear { loadToday() }
        }
    }

    private func loadToday() {
        guard let log = todayLog else { return }
        skinScore = log.skinScore1to5 ?? 3
        condition = SkinCondition(rawValue: log.skinCondition ?? "") ?? .correct
        antihydralApplied = log.antihydralApplied ?? false
    }

    private func save() {
        let log = todayLog ?? DayLog(date: .now)
        log.skinScore1to5 = skinScore
        log.skinCondition = condition.rawValue
        log.antihydralApplied = antihydralApplied
        if todayLog == nil {
            modelContext.insert(log)
        }
        try? modelContext.save()
    }
}

#Preview {
    SkinView()
        .modelContainer(for: [DayLog.self], inMemory: true)
}
