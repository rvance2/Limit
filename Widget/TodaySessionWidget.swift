import WidgetKit
import SwiftUI

struct SessionEntry: TimelineEntry {
    let date: Date
    let weekday: Int
    let weekNumber: Int
    let templateId: String
}

struct SessionTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SessionEntry {
        entry(for: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (SessionEntry) -> Void) {
        completion(entry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionEntry>) -> Void) {
        let now = Date.now
        let today = entry(for: now)
        // Today's session doesn't change until the calendar day does, so the only refresh this
        // needs is one at the next local midnight.
        let midnight = Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(86400)
        completion(Timeline(entries: [today], policy: .after(midnight)))
    }

    private func entry(for date: Date) -> SessionEntry {
        let weekday = Calendar.current.component(.weekday, from: date)
        let weekNumber = SessionScheduler.weekNumber(for: date, startDate: WidgetDisplay.planStartDate)
        let templateId = SessionScheduler.sessionTemplateId(forWeekday: weekday, weekNumber: weekNumber)
        return SessionEntry(date: date, weekday: weekday, weekNumber: weekNumber, templateId: templateId)
    }
}

/// The Home Screen families (`.systemSmall`/`.systemMedium`) get a real, saturated background —
/// `color.gradient` off the same session-color mapping `PlanScheduler` uses in the app itself, so
/// the widget reads as part of the same app rather than a generic system tile. The Lock Screen
/// accessory families deliberately get none: iOS renders those in its own vibrant/monochrome
/// style regardless of what's supplied, so fighting it with a custom color just adds noise
/// Apple's own renderer discards.
struct TodaySessionWidgetBackground: View {
    @Environment(\.widgetFamily) private var family
    let entry: SessionEntry

    var body: some View {
        switch family {
        case .accessoryRectangular, .accessoryCircular, .accessoryInline:
            Color.clear
        default:
            Rectangle().fill(WidgetDisplay.color(forTemplateId: entry.templateId).gradient)
        }
    }
}

struct TodaySessionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SessionEntry

    private var blockNumber: Int { WidgetDisplay.blockNumber(forWeek: entry.weekNumber) }
    private var icon: String { WidgetDisplay.icon(forTemplateId: entry.templateId) }
    private var shortLabel: String { WidgetDisplay.shortLabel(forTemplateId: entry.templateId) }
    private var displayName: String { WidgetDisplay.displayName(forTemplateId: entry.templateId) }

    var body: some View {
        switch family {
        case .systemSmall:
            small
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryCircular:
            accessoryCircular
        case .accessoryInline:
            accessoryInline
        default:
            medium
        }
    }

    // MARK: - Home Screen

    private var small: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: icon)
                .font(.system(size: 78))
                .foregroundStyle(.white.opacity(0.16))
                .offset(x: 20, y: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption2.weight(.semibold))
                    Spacer()
                    Image(systemName: icon)
                        .font(.caption2)
                }
                .foregroundStyle(.white.opacity(0.8))

                Spacer()

                Text(shortLabel)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var medium: some View {
        ZStack {
            Image(systemName: icon)
                .font(.system(size: 100))
                .foregroundStyle(.white.opacity(0.14))
                .offset(x: 110, y: 8)

            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(.white.opacity(0.22))
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                    Text(displayName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("Week \(entry.weekNumber) · \(WidgetDisplay.blockName(forNumber: blockNumber))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    // MARK: - Lock Screen

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(shortLabel, systemImage: icon)
                .font(.headline)
                .widgetAccentable()
            Text(displayName)
                .font(.caption)
                .lineLimit(1)
            Text("Week \(entry.weekNumber)")
                .font(.caption2)
        }
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(.caption)
                    .widgetAccentable()
                Text(shortLabel)
                    .font(.system(size: 15, weight: .bold))
            }
        }
    }

    private var accessoryInline: some View {
        Label(displayName, systemImage: icon)
    }
}

struct TodaySessionWidget: Widget {
    let kind = "TodaySessionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SessionTimelineProvider()) { entry in
            TodaySessionWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    TodaySessionWidgetBackground(entry: entry)
                }
        }
        .configurationDisplayName("Today's Session")
        .description("Shows today's session type at a glance, on the Home Screen or Lock Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}
