import SwiftUI
import SwiftData
import Charts

/// Chart 1 — 7 s two-arm max hang test results, in kg and as % bodyweight, with the
/// `twoArm7sHang` benchmark grade bands as horizontal reference lines.
///
/// kg vs %BW is a toggle rather than a dual-axis chart: Swift Charts has no clean two-scale
/// y-axis, and the benchmark rows are published in %BW, so the reference lines only overlay
/// cleanly in that view. Falls back to kg-only, no picker, when no bodyweight is logged.
struct FingerStrengthChart: View {
    @Query(sort: \TestResult.date) private var allTests: [TestResult]
    @Query private var appStates: [AppState]

    private enum Unit: String, CaseIterable { case kg = "kg", pctBW = "% bodyweight" }
    @State private var unit: Unit = .pctBW

    private var startDate: Date { appStates.first?.startDate ?? .now }

    private var hangResults: [TestResult] {
        allTests.filter { $0.testItemID == "7s_max_hang" && $0.value != nil }
    }

    private var bodyweight: Double? {
        ChartDataHelpers.mostRecentBodyweightKG(from: allTests)
    }

    /// Forces kg when no bodyweight is logged, regardless of the picker's stored state.
    private var effectiveUnit: Unit { bodyweight == nil ? .kg : unit }

    private var benchmarkRows: [BenchmarkRow] {
        SeedStore.shared.benchmarks?.twoArm7sHang.rows ?? []
    }

    private func plottedValue(_ result: TestResult) -> Double {
        guard let raw = result.value else { return 0 }
        if effectiveUnit == .pctBW, let bw = bodyweight, bw > 0 {
            return raw / bw * 100
        }
        return raw
    }

    var body: some View {
        ChartCard(
            title: "Finger strength: 7 s max hang",
            caption: "Interpolated benchmark grades (dashed) are inference, not measurement. Only V4, V7 and V11 are Lattice's published points (solid); the rest assume roughly 6% per grade. (Benchmarks.md)"
        ) {
            if hangResults.isEmpty {
                ChartEmptyState(message: "No 7 s max hang results logged yet.")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    if bodyweight != nil {
                        Picker("Unit", selection: $unit) {
                            ForEach(Unit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Text("No bodyweight logged, showing kg only.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Chart {
                        ForEach(hangResults, id: \.persistentModelID) { result in
                            LineMark(
                                x: .value("Date", result.date),
                                y: .value(effectiveUnit.rawValue, plottedValue(result))
                            )
                            .symbol(.circle)
                            .foregroundStyle(.blue)
                        }
                        if effectiveUnit == .pctBW {
                            ForEach(benchmarkRows) { row in
                                RuleMark(y: .value("Grade", row.percentBW))
                                    .foregroundStyle(Color.gray.opacity(0.6))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: row.isPublished ? [] : [4, 3]))
                                    .annotation(position: .top, alignment: .trailing) {
                                        Text(row.grade)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                            }
                        }
                        planDateAnnotations(startDate: startDate)
                    }
                    .frame(height: 220)

                    if effectiveUnit == .pctBW {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Rectangle().fill(Color.gray).frame(width: 14, height: 2)
                                Text("Published").font(.caption2).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 4) {
                                Rectangle().fill(Color.gray).frame(width: 14, height: 2)
                                    .overlay(
                                        // Rough dashed swatch to echo the RuleMark dash style above.
                                        Rectangle().stroke(style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                                            .foregroundStyle(Color.gray)
                                    )
                                Text("Interpolated").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}
