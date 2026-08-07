import Foundation
import ActivityKit
import UserNotifications
import Observation
import UIKit

/// Rest timer shared by the whole runner (one timer, one Live Activity, at a time) instead of
/// being reimplemented per item. Presets are 3 / 4 / 5 minutes; the default preset is decided
/// by the caller (5 min on items judged "crux", see `SessionRunnerView.isCruxItem`) — PCr
/// resynthesis is functionally complete at 3-5 minutes, and at 60 seconds attempt quality is
/// roughly 85% of capacity, so there's no "feel ready" shortcut here.
@Observable
final class RestTimerController {
    private(set) var timeRemaining: Int = 0
    private(set) var totalDuration: Int = 0
    private(set) var label: String = ""

    private var activity: Activity<RestTimerAttributes>?
    private var tickTimer: Timer?

    var isRunning: Bool { timeRemaining > 0 }

    func start(minutes: Int, label: String = "Rest") {
        stop()

        self.label = label
        let durationSecs = minutes * 60
        timeRemaining = durationSecs
        totalDuration = durationSecs
        let endTime = Date.now.addingTimeInterval(TimeInterval(durationSecs))

        let attributes = RestTimerAttributes(duration: minutes)
        let state = RestTimerAttributes.ContentState(endTime: endTime)

        do {
            activity = try Activity<RestTimerAttributes>.request(
                attributes: attributes,
                contentState: state,
                pushType: nil
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "\(minutes)-minute rest is up."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(durationSecs), repeats: false)
        let request = UNNotificationRequest(identifier: "RestTimer", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)

        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
                if self.timeRemaining == 0 {
                    // Haptic on completion.
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } else {
                self.stop()
            }
        }
    }

    func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        timeRemaining = 0
        totalDuration = 0

        Task { [activity] in
            if let activity {
                let finalState = RestTimerAttributes.ContentState(endTime: Date.now)
                await activity.end(using: finalState, dismissalPolicy: .immediate)
            }
        }
        activity = nil

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["RestTimer"])
    }
}
