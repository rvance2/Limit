import SwiftUI
import SwiftData

// Standalone Conditions entry point. Expected to be linked from: Today (project
// day decision) and Plan (Block 4, conditions-led scheduling). Parameterless.
// The only networked feature in the app — every network path fails silently
// into manual entry, which is always available regardless of network state.
struct ConditionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appStates: [AppState]
    @Query(sort: \DayLog.date, order: .reverse) private var dayLogs: [DayLog]

    @State private var dewPointText = ""
    @State private var rockTempText = ""
    @State private var windFavorable = true
    @State private var windDescription = ""
    @State private var aspect = ""
    @State private var isFetching = false
    @State private var forecastNote: String?

    private var appState: AppState? { appStates.first }

    private var todayLog: DayLog? {
        dayLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    private var dewPointC: Double? { Double(dewPointText) }
    private var rockTempC: Double? { Double(rockTempText) }

    private var goNoGo: (inputs: [GoNoGoInput], badCount: Int, recommendation: String) {
        GoNoGoEvaluator.evaluate(
            dewPointC: dewPointC,
            rockTempC: rockTempC,
            windIsFavorable: windDescription.isEmpty ? nil : windFavorable,
            skinScore: todayLog?.skinScore1to5,
            readinessVerdict: todayLog?.verdict
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Crag") {
                    if let name = appState?.cragName {
                        Text(name)
                    } else {
                        Text("No saved crag location. Set one in Plan settings to enable the forecast lookup.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Dew point") {
                    if appState?.cragLatitude != nil && appState?.cragLongitude != nil {
                        Button {
                            fetchForecast()
                        } label: {
                            if isFetching {
                                ProgressView()
                            } else {
                                Label("Fetch forecast dew point", systemImage: "cloud.sun")
                            }
                        }
                        .disabled(isFetching)
                    }
                    if let forecastNote {
                        Text(forecastNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    TextField("Dew point (°C), manual entry always works", text: $dewPointText)
                        .keyboardType(.numbersAndPunctuation)
                    if let dewPointC {
                        Text(ConditionsLogic.dewPointVerdict(dewPointC: dewPointC, rockTempC: rockTempC))
                            .font(.subheadline.weight(.semibold))
                    }
                }

                Section("Rock temperature") {
                    TextField("Rock temp (°C), infrared thermometer, always manual", text: $rockTempText)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Aspect", text: $aspect)
                    if let dewPointC, let rockTempC {
                        let s = ConditionsLogic.spread(rockTempC: rockTempC, dewPointC: dewPointC)
                        Text("Spread: \(s.value.formatted(.number.precision(.fractionLength(1))))°C, \(s.description.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Wind") {
                    Toggle("Wind is working for me", isOn: $windFavorable)
                    TextField("Wind note", text: $windDescription)
                    Text("Exposed boulders on humid days. Sheltered forest boulders are the worst option. If I can't feel the crimp edge, the friction gain is irrelevant.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    ForEach(goNoGo.inputs) { input in
                        HStack(alignment: .top) {
                            Image(systemName: input.isBad ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(input.isBad ? .red : .green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(input.label).font(.subheadline.weight(.semibold))
                                Text(input.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text(goNoGo.recommendation)
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 4)
                } header: {
                    Text("Go / no-go")
                } footer: {
                    Text("Three of five bad recommends training instead. This is a reasoning tool, not a verdict. I still decide.")
                }

                Section {
                    Button("Log it") { save() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Conditions")
        }
    }

    private func fetchForecast() {
        guard let lat = appState?.cragLatitude, let lon = appState?.cragLongitude else { return }
        isFetching = true
        forecastNote = nil
        Task {
            let result = await WeatherService.fetchCurrentDewPointC(latitude: lat, longitude: lon)
            await MainActor.run {
                isFetching = false
                if let result {
                    dewPointText = String(format: "%.1f", result)
                    forecastNote = "Forecast dew point loaded. Overwrite if I have a better local read."
                } else {
                    forecastNote = "No forecast available, enter manually."
                }
            }
        }
    }

    private func save() {
        let log = ConditionsLog(date: .now)
        log.airTempC = nil
        log.rockTempC = rockTempC
        log.dewPointC = dewPointC
        log.aspect = aspect.isEmpty ? nil : aspect
        log.windDescription = windDescription.isEmpty ? nil : windDescription
        log.skinScore = todayLog?.skinScore1to5
        log.readinessVerdictUsed = todayLog?.verdict
        log.goNoGoScore = goNoGo.badCount
        log.decision = goNoGo.recommendation
        modelContext.insert(log)
        try? modelContext.save()
    }
}

#Preview {
    ConditionsView()
        .modelContainer(for: [ConditionsLog.self, AppState.self, DayLog.self], inMemory: true)
}
