import SwiftUI
import Charts

/// Card chrome shared by all nine charts: title, chart content, and a one-sentence caption
/// pulled from the relevant vault note. Keeps ChartsTabView a plain list of chart views.
struct ChartCard<Content: View>: View {
    let title: String
    let caption: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
        .padding(.horizontal)
    }
}

/// Empty-state placeholder shown inside a chart's frame when there's nothing to plot yet.
/// Every chart in this folder must render sensibly with zero data points — this is how.
struct ChartEmptyState: View {
    let message: String

    var body: some View {
        VStack {
            Image(systemName: "chart.xyaxis.line")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
}

/// Plan-week annotations for charts whose x-axis is a raw Int week number (0...22): colored
/// RuleMarks for reduced/test/taper weeks, neutral dashed RuleMarks at block boundaries.
/// Color convention matches `TimelineStripView` in PlanView.swift (reduced = orange, test =
/// blue, taper = purple) so the same week reads the same way across tabs.
@ChartContentBuilder
func planWeekAnnotations() -> some ChartContent {
    ForEach(ChartDataHelpers.nonTrainingWeeks) { annotation in
        RuleMark(x: .value("Week", annotation.week))
            .foregroundStyle(ChartDataHelpers.color(forWeekKind: annotation.kind, isReduced: annotation.isReduced).opacity(0.35))
            .lineStyle(StrokeStyle(lineWidth: 1))
    }
    ForEach(ChartDataHelpers.blockBoundaryWeeks, id: \.self) { week in
        RuleMark(x: .value("Week", week))
            .foregroundStyle(Color.secondary.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }
}

/// Same annotations as `planWeekAnnotations()`, for charts whose x-axis is a Date rather than
/// a raw Int week number (plan weeks are converted to approximate calendar dates via
/// `ChartDataHelpers.date(forWeek:startDate:)`).
@ChartContentBuilder
func planDateAnnotations(startDate: Date) -> some ChartContent {
    ForEach(ChartDataHelpers.nonTrainingWeeks) { annotation in
        RuleMark(x: .value("Date", ChartDataHelpers.date(forWeek: annotation.week, startDate: startDate)))
            .foregroundStyle(ChartDataHelpers.color(forWeekKind: annotation.kind, isReduced: annotation.isReduced).opacity(0.35))
            .lineStyle(StrokeStyle(lineWidth: 1))
    }
    ForEach(ChartDataHelpers.blockBoundaryWeeks, id: \.self) { week in
        RuleMark(x: .value("Date", ChartDataHelpers.date(forWeek: week, startDate: startDate)))
            .foregroundStyle(Color.secondary.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }
}
