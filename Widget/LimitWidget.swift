import WidgetKit
import SwiftUI
import ActivityKit

@main
struct LimitWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodaySessionWidget()
        RestTimerLiveActivity()
    }
}

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Lock screen / Banner UI
            VStack {
                Text("Resting (\(context.attributes.duration) min)")
                    .font(.headline)
                Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                    .font(.title)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(Color.orange)
        } dynamicIsland: { context in
            // Dynamic Island
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Rest")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 50)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("\(context.attributes.duration)m Timer")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    //
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(.orange)
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.endTime, countsDown: true)
                    .frame(maxWidth: 30)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(.orange)
            }
        }
    }
}
