import SwiftUI
import SwiftData

// Standalone Export entry point. Expected to be linked from: Library or a
// settings surface — wherever the owning tab wants a "get my data out"
// action. Parameterless.
struct ExportView: View {
    @Query private var dayLogs: [DayLog]
    @Query private var sessionLogs: [SessionLog]
    @Query private var attempts: [Attempt]
    @Query private var testResults: [TestResult]
    @Query private var conditionsLogs: [ConditionsLog]
    @Query private var projects: [Project]

    @State private var markdownURL: URL?
    @State private var csvURLs: [URL] = []
    @State private var isPreparing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Dumps the log (day log, sessions, attempts, test results, conditions, Beta Lab) to a file for Obsidian or Numbers. Nothing leaves the device except through the share sheet I choose.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Markdown, for Obsidian") {
                    Button {
                        prepareMarkdown()
                    } label: {
                        Label("Prepare markdown export", systemImage: "doc.text")
                    }
                    if let markdownURL {
                        ShareLink(item: markdownURL) {
                            Label("Share limit-export.md", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                Section("CSV, for Numbers") {
                    Button {
                        prepareCSV()
                    } label: {
                        Label("Prepare CSV export (one file per table)", systemImage: "tablecells")
                    }
                    if !csvURLs.isEmpty {
                        ShareLink(items: csvURLs) {
                            Label("Share \(csvURLs.count) CSV files", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                Section {
                    counts
                } header: {
                    Text("What's in the log")
                }
            }
            .navigationTitle("Export")
        }
    }

    private var counts: some View {
        VStack(alignment: .leading, spacing: 4) {
            row("Day logs", dayLogs.count)
            row("Sessions", sessionLogs.count)
            row("Attempts", attempts.count)
            row("Test results", testResults.count)
            row("Conditions logs", conditionsLogs.count)
            row("Beta Lab projects", projects.count)
        }
        .font(.subheadline)
    }

    private func row(_ label: String, _ count: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(count)").foregroundStyle(.secondary)
        }
    }

    private func prepareMarkdown() {
        let content = ExportService.markdown(
            dayLogs: dayLogs, sessionLogs: sessionLogs, attempts: attempts,
            testResults: testResults, conditionsLogs: conditionsLogs, projects: projects
        )
        markdownURL = ExportService.writeTempFile(name: "limit-export.md", contents: content)
    }

    private func prepareCSV() {
        var urls: [URL] = []
        let files: [(String, String)] = [
            ("day_log.csv", ExportService.dayLogCSV(dayLogs)),
            ("sessions.csv", ExportService.sessionLogCSV(sessionLogs)),
            ("attempts.csv", ExportService.attemptCSV(attempts)),
            ("test_results.csv", ExportService.testResultCSV(testResults)),
            ("conditions_log.csv", ExportService.conditionsLogCSV(conditionsLogs)),
            ("beta_lab_projects.csv", ExportService.projectCSV(projects)),
        ]
        for (name, content) in files {
            if let url = ExportService.writeTempFile(name: name, contents: content) {
                urls.append(url)
            }
        }
        csvURLs = urls
    }
}

#Preview {
    ExportView()
        .modelContainer(for: [DayLog.self, SessionLog.self, Attempt.self, TestResult.self, ConditionsLog.self, Project.self], inMemory: true)
}
