import SwiftUI
import SwiftData
import Charts

/// Chart 9 — box split (raw cm and normalized to height) and ankle dorsiflexion, from
/// TestResult rows with testItemID == "mobility".
///
/// See `ChartDataHelpers.MobilityVariant` for the row convention this chart reads
/// (`protocolVariant` values like "box_split_cm", "ankle_dorsiflexion_left", etc.) — that
/// convention is provisional and needs reconciling with the Tests-battery logging UI being
/// built in parallel elsewhere.
struct MobilityChart: View {
    @Query(sort: \TestResult.date) private var allTests: [TestResult]
    @Query private var appStates: [AppState]

    private var startDate: Date { appStates.first?.startDate ?? .now }

    private var mobilityResults: [TestResult] { allTests.filter { $0.testItemID == "mobility" } }

    private func series(_ variant: ChartDataHelpers.MobilityVariant) -> [TestResult] {
        mobilityResults.filter { $0.protocolVariant == variant.rawValue && $0.value != nil }
    }

    var body: some View {
        ChartCard(
            title: "Mobility: box split and ankle dorsiflexion",
            caption: "Box split explains about 2% of grade variance and nothing within ability groups: no meaningful benchmark. The point is not losing week-0 range, not chasing a number. (Flexibility and Mobility.md)"
        ) {
            if mobilityResults.isEmpty {
                ChartEmptyState(message: "No mobility test results logged yet.")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Box split, heel-to-heel (cm)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Chart {
                        ForEach(series(.boxSplitCM), id: \.persistentModelID) { t in
                            LineMark(
                                x: .value("Date", t.date, unit: .day),
                                y: .value("cm", t.value ?? 0)
                            )
                            .foregroundStyle(.pink)
                            .symbol(.circle)
                        }
                        planDateAnnotations(startDate: startDate)
                    }
                    .frame(height: 90)

                    Text("Ankle dorsiflexion, knee-to-wall (cm), both sides")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Chart {
                        ForEach(series(.ankleDorsiflexionLeft), id: \.persistentModelID) { t in
                            LineMark(
                                x: .value("Date", t.date, unit: .day),
                                y: .value("cm", t.value ?? 0),
                                series: .value("Side", "Left")
                            )
                            .foregroundStyle(.orange)
                        }
                        ForEach(series(.ankleDorsiflexionRight), id: \.persistentModelID) { t in
                            LineMark(
                                x: .value("Date", t.date, unit: .day),
                                y: .value("cm", t.value ?? 0),
                                series: .value("Side", "Right")
                            )
                            .foregroundStyle(.blue)
                        }
                        planDateAnnotations(startDate: startDate)
                    }
                    .frame(height: 90)

                    HStack(spacing: 12) {
                        Label("Left", systemImage: "circle.fill").foregroundStyle(.orange).font(.caption2)
                        Label("Right", systemImage: "circle.fill").foregroundStyle(.blue).font(.caption2)
                    }
                }
            }
        }
    }
}
