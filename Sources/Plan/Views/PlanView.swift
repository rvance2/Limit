import SwiftUI
import SwiftData

// MARK: - Weekday / week-number / styling helpers

/// Plan-tab-specific display helpers (labels, colors). The weekday->template mapping and
/// week-number math live in `SessionScheduler` (shared with Today and the Log tab).
enum PlanScheduler {
    static func sessionTemplateId(forWeekday weekday: Int, weekNumber: Int) -> String {
        SessionScheduler.sessionTemplateId(forWeekday: weekday, weekNumber: weekNumber)
    }

    static func sessionTemplateId(for date: Date, startDate: Date) -> String {
        SessionScheduler.sessionTemplateId(for: date, startDate: startDate)
    }

    static func weekNumber(for date: Date, startDate: Date) -> Int {
        SessionScheduler.weekNumber(for: date, startDate: startDate)
    }

    static func weekdayLabel(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return ""
        }
    }

    static func shortLabel(forTemplateId id: String) -> String {
        switch id {
        case "Recovery", "Monday Recovery": return "Rec"
        case "S1 Finger Priority": return "S1"
        case "S2 Limit Boulder": return "S2"
        case "S3 Power and Contact": return "S3"
        case "S4 Volume and Skill": return "S4"
        case "S5 Outdoor Project Day": return "S5"
        case "S6 Skill and Pull": return "S6"
        case "Off": return "Off"
        default: return id
        }
    }

    static func color(forTemplateId id: String) -> Color {
        switch id {
        case "Recovery", "Monday Recovery": return .mint
        case "S1 Finger Priority": return .blue
        case "S2 Limit Boulder": return .indigo
        case "S3 Power and Contact": return .red
        case "S4 Volume and Skill": return .green
        case "S5 Outdoor Project Day": return .purple
        case "S6 Skill and Pull": return .teal
        default: return .gray // Off
        }
    }

    /// Border tint for non-training weeks so reduced/test/taper weeks read as visually
    /// distinct from ordinary training weeks on the calendar. nil = training (no border).
    /// `isReduced` takes priority over `kind` — week 12 is deliberately both a test week and
    /// a reduced week, and the reduced-volume training change is the one that matters for
    /// what today's session actually looks like.
    static func borderColor(forWeekKind kind: String, isReduced: Bool) -> Color? {
        if isReduced { return .orange }
        switch kind {
        case "test": return .cyan
        case "taper": return .purple
        default: return nil
        }
    }
}

// MARK: - Identifiable wrappers for sheet(item:)

struct DateWrapper: Identifiable, Equatable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

struct WeekWrapper: Identifiable, Equatable {
    let week: Int
    var id: Int { week }
}

// MARK: - PlanView

struct PlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appStates: [AppState]
    @Query private var dayLogs: [DayLog]
    @Query private var sessionLogs: [SessionLog]
    @Query private var attempts: [Attempt]

    @State private var selectedDay: DateWrapper?
    @State private var selectedWeek: WeekWrapper?

    var appState: AppState? { appStates.first }
    private var startDate: Date { appState?.startDate ?? .now }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let plan = SeedStore.shared.plan {
                    TimelineStripView(plan: plan, startDate: startDate)
                        .frame(height: 60)
                        .padding(.vertical, 8)
                        .background(Color(uiColor: .secondarySystemBackground))
                }

                ScrollView {
                    MonthCalendarView(
                        startDate: startDate,
                        dayLogs: dayLogs,
                        sessionLogs: sessionLogs,
                        selectedDay: $selectedDay,
                        selectedWeek: $selectedWeek
                    )
                    .padding(.vertical)
                }
            }
            .navigationTitle("Plan")
            .sheet(item: $selectedDay) { wrapper in
                NavigationStack {
                    DayDetailView(
                        date: wrapper.date,
                        startDate: startDate,
                        dayLogs: dayLogs,
                        sessionLogs: sessionLogs,
                        attempts: attempts
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { selectedDay = nil }
                        }
                    }
                }
            }
            .sheet(item: $selectedWeek) { wrapper in
                WeekDetailView(
                    weekNumber: wrapper.week,
                    startDate: startDate,
                    dayLogs: dayLogs,
                    sessionLogs: sessionLogs
                )
            }
        }
    }
}

// MARK: - Timeline strip (23-week overview, unchanged behavior)

struct TimelineStripView: View {
    let plan: SeedPlan
    let startDate: Date

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(plan.weeks, id: \.week) { week in
                    VStack {
                        Text("\(week.week)")
                            .font(.caption2)
                            .foregroundColor(week.isReduced ? .orange : (week.kind == "test" ? .blue : .primary))

                        Rectangle()
                            .fill(colorForBlock(id: week.blockID))
                            .frame(width: 20, height: 20)
                            .border(Color.secondary, width: week.kind != "training" ? 2 : 0)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    func colorForBlock(id: String) -> Color {
        switch id {
        case "Block 0": return .gray
        case "Block 1": return .blue
        case "Block 2": return .red
        case "Block 3": return .purple
        case "Block 4": return .green
        default: return .clear
        }
    }
}

// MARK: - Month calendar grid

struct MonthCalendarView: View {
    let startDate: Date
    let dayLogs: [DayLog]
    let sessionLogs: [SessionLog]

    @Binding var selectedDay: DateWrapper?
    @Binding var selectedWeek: WeekWrapper?

    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: .now)

    private let calendar = Calendar.current

    private var weeks: [[Date?]] {
        let days = daysInMonthGrid(for: displayedMonth)
        return stride(from: 0, to: days.count, by: 7).map { start in
            Array(days[start..<min(start + 7, days.count)])
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { shiftMonth(-1) }) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                Spacer()
                Button(action: { shiftMonth(1) }) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)

            HStack(spacing: 4) {
                Text("Wk")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 26)
                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)

            ForEach(weeks.indices, id: \.self) { rowIndex in
                weekRow(weeks[rowIndex])
            }
        }
    }

    @ViewBuilder
    private func weekRow(_ row: [Date?]) -> some View {
        let firstDay = row.compactMap { $0 }.first
        let rowWeekNumber = firstDay.map { PlanScheduler.weekNumber(for: $0, startDate: startDate) }

        HStack(spacing: 4) {
            Button {
                if let rowWeekNumber {
                    selectedWeek = WeekWrapper(week: rowWeekNumber)
                }
            } label: {
                Text(rowWeekNumber.map(String.init) ?? "")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .frame(width: 26)
            }
            .buttonStyle(.plain)
            .disabled(rowWeekNumber == nil)

            ForEach(0..<7, id: \.self) { col in
                if col < row.count, let day = row[col] {
                    DayCell(date: day, startDate: startDate, isLogged: isLogged(day))
                        .onTapGesture { selectedDay = DateWrapper(date: day) }
                } else {
                    Color.clear.frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
        .padding(.horizontal)
    }

    private func isLogged(_ day: Date) -> Bool {
        dayLogs.contains { calendar.isDate($0.date, inSameDayAs: day) } ||
        sessionLogs.contains { calendar.isDate($0.date, inSameDayAs: day) }
    }

    private func shiftMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    /// Builds a Monday-first grid of the given month, padded with nils so every row has 7 slots.
    private func daysInMonthGrid(for monthDate: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else { return [] }

        var days: [Date?] = []
        let firstOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) // 1=Sun...7=Sat
        let leadingEmpty = (firstWeekday + 5) % 7 // convert to Monday-first offset
        days.append(contentsOf: Array(repeating: nil, count: leadingEmpty))

        var current = firstOfMonth
        while current < monthInterval.end {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}

struct DayCell: View {
    let date: Date
    let startDate: Date
    let isLogged: Bool

    private var weekday: Int { Calendar.current.component(.weekday, from: date) }
    private var templateId: String { PlanScheduler.sessionTemplateId(forWeekday: weekday, weekNumber: weekNumber) }
    private var weekNumber: Int { PlanScheduler.weekNumber(for: date, startDate: startDate) }
    private var weekKind: String { SeedStore.shared.getWeek(number: weekNumber)?.kind ?? "training" }
    private var weekIsReduced: Bool { SeedStore.shared.getWeek(number: weekNumber)?.isReduced ?? false }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    private var dayNumber: Int { Calendar.current.component(.day, from: date) }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(dayNumber)")
                .font(.caption2)
                .fontWeight(isToday ? .bold : .regular)

            Text(PlanScheduler.shortLabel(forTemplateId: templateId))
                .font(.system(size: 9, weight: .semibold))
                .padding(.horizontal, 3)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity)
                .background(PlanScheduler.color(forTemplateId: templateId).opacity(0.22))
                .foregroundColor(PlanScheduler.color(forTemplateId: templateId))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(PlanScheduler.borderColor(forWeekKind: weekKind, isReduced: weekIsReduced) ?? .clear, lineWidth: 1.5)
                )

            Circle()
                .fill(isLogged ? Color.primary : Color.clear)
                .frame(width: 4, height: 4)
        }
        .padding(4)
        .background(isToday ? Color.accentColor.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - Day detail (plan-only for today/future, actual log for past days)

struct DayDetailView: View {
    let date: Date
    let startDate: Date
    let dayLogs: [DayLog]
    let sessionLogs: [SessionLog]
    let attempts: [Attempt]

    private var isPastDay: Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        Group {
            if isPastDay {
                LoggedDayView(date: date, dayLogs: dayLogs, sessionLogs: sessionLogs, attempts: attempts)
            } else {
                SessionDetailView(date: date, startDate: startDate)
            }
        }
    }
}

/// Read-only view of the plan for a given date: the resolved SeedSession for that weekday.
struct SessionDetailView: View {
    let date: Date
    let startDate: Date

    private var weekday: Int { Calendar.current.component(.weekday, from: date) }
    private var templateId: String { PlanScheduler.sessionTemplateId(forWeekday: weekday, weekNumber: weekNumber) }
    private var weekNumber: Int { PlanScheduler.weekNumber(for: date, startDate: startDate) }
    private var weekInfo: PlanWeek? { SeedStore.shared.getWeek(number: weekNumber) }
    private var session: SeedSession? { SeedStore.shared.getSessionTemplate(id: templateId) }

    var body: some View {
        List {
            Section {
                LabeledContent("Week", value: "\(weekNumber)")
                if let weekInfo, let block = SeedStore.shared.getBlock(id: weekInfo.blockID) {
                    LabeledContent("Block", value: block.name)
                }
                if let weekInfo, weekInfo.kind != "training" {
                    LabeledContent("Week type", value: weekInfo.kind)
                }
            }

            if let session {
                let blockNumber = weekInfo.flatMap { SeedStore.shared.blockNumber(for: $0.blockID) }

                Section(session.name) {
                    if let duration = session.duration {
                        LabeledContent("Duration", value: duration)
                    }
                    if let pre = session.preSession, !pre.isEmpty {
                        Text(MarkdownView.attributed(pre))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Items") {
                    ForEach(session.items.sorted(by: { $0.order < $1.order })) { item in
                        let resolvedModuleId = item.moduleId ?? FingerMethodResolver.moduleID(forItemName: item.name, blockNumber: blockNumber)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(FingerMethodResolver.displayName(itemName: item.name, blockNumber: blockNumber))
                                .font(.headline)
                            if let variation = item.variation {
                                Text(MarkdownView.attributed(variation))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            if let time = item.time {
                                Text(time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let resolvedModuleId,
                               let module = SeedStore.shared.getModule(id: resolvedModuleId),
                               let dose = module.dose, !dose.isEmpty {
                                Text(MarkdownView.attributed(dose))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if item.cuttable.isCuttable {
                                Text("cuttable")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Finger prescription for this week, resolved from plan.json — same trigger
                // condition TodayView uses for today's session.
                if session.items.contains(where: {
                    $0.name == "Primary finger method" || $0.moduleId == "Max Hangs" || $0.moduleId == "MED Hangs"
                }), let prescription = weekInfo?.fingerPrescription {
                    Section("Finger prescription") {
                        Text(prescription.notation)
                            .font(.subheadline.monospaced())
                        Text(prescription.plainLanguage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !session.stopRules.isEmpty {
                    Section("Stop rules") {
                        ForEach(session.stopRules, id: \.self) { rule in
                            Text(MarkdownView.attributed(rule))
                        }
                    }
                }
            } else {
                Section {
                    Text("No session template found for this day.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Actual logged data for a past day: DayLog (readiness), SessionLog (completion), Attempts.
struct LoggedDayView: View {
    let date: Date
    let dayLogs: [DayLog]
    let sessionLogs: [SessionLog]
    let attempts: [Attempt]

    private let calendar = Calendar.current

    private var dayLog: DayLog? {
        dayLogs.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    private var sessionLog: SessionLog? {
        sessionLogs.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    private var dayAttempts: [Attempt] {
        attempts.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }

    var body: some View {
        List {
            if dayLog == nil && sessionLog == nil && dayAttempts.isEmpty {
                Section {
                    Text("No log for this day.")
                        .foregroundColor(.secondary)
                }
            }

            if let dayLog {
                Section("Readiness") {
                    if let count = dayLog.flagCount, let verdict = dayLog.verdict {
                        LabeledContent("Flags", value: "\(count), \(verdict)")
                    }
                    if let hrv = dayLog.hrv {
                        LabeledContent("HRV", value: "\(Int(hrv)) ms")
                    }
                    if let rhr = dayLog.restingHR {
                        LabeledContent("Resting HR", value: "\(Int(rhr)) bpm")
                    }
                    if let sleep = dayLog.sleepHours {
                        LabeledContent("Sleep", value: String(format: "%.1f hrs", sleep))
                    }
                    if let skin = dayLog.skinScore1to5 {
                        LabeledContent("Skin", value: "\(skin)/5")
                    }
                }
            }

            if let sessionLog {
                Section("Session") {
                    LabeledContent("Template", value: sessionLog.templateID)
                    if let rpe = sessionLog.sessionRPE1to10 {
                        LabeledContent("RPE", value: "\(rpe)/10")
                    }
                    if let note = sessionLog.oneLineNote, !note.isEmpty {
                        Text(note)
                    }
                    ForEach(sessionLog.completedItems, id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle")
                    }
                }
            }

            if !dayAttempts.isEmpty {
                Section("Attempts") {
                    ForEach(dayAttempts.sorted(by: { $0.index < $1.index }), id: \.index) { attempt in
                        HStack {
                            Text(attempt.grade)
                            Spacer()
                            Text(attempt.outcome)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Week detail

struct WeekDetailView: View {
    let weekNumber: Int
    let startDate: Date
    let dayLogs: [DayLog]
    let sessionLogs: [SessionLog]

    @Environment(\.dismiss) private var dismiss

    private var weekInfo: PlanWeek? { SeedStore.shared.getWeek(number: weekNumber) }

    /// The 7 dates in this plan week, in whatever weekday order they actually fall on —
    /// each date's own weekday drives its session-template lookup, so this stays correct
    /// even if `startDate` isn't a Monday.
    private var weekDates: [Date] {
        let cal = Calendar.current
        guard let weekStart = cal.date(byAdding: .day, value: weekNumber * 7, to: cal.startOfDay(for: startDate)) else {
            return []
        }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let weekInfo, let block = SeedStore.shared.getBlock(id: weekInfo.blockID) {
                    Section {
                        LabeledContent("Block", value: block.name)
                        if weekInfo.kind != "training" {
                            LabeledContent("Week type", value: weekInfo.kind)
                        }
                    }
                }

                Section("Sessions") {
                    ForEach(weekDates, id: \.self) { day in
                        let weekday = Calendar.current.component(.weekday, from: day)
                        let templateId = PlanScheduler.sessionTemplateId(forWeekday: weekday, weekNumber: weekNumber)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(PlanScheduler.weekdayLabel(weekday)) \(day.formatted(.dateTime.month().day()))")
                                    .font(.subheadline)
                                Text(templateId)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if isCompleted(day) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Week \(weekNumber)")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func isCompleted(_ day: Date) -> Bool {
        let cal = Calendar.current
        return sessionLogs.contains { cal.isDate($0.date, inSameDayAs: day) } ||
               dayLogs.contains { cal.isDate($0.date, inSameDayAs: day) }
    }
}
