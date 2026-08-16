import Foundation
import Observation
import UIKit

enum TimerPhaseKind: String {
    case hang = "Hang"
    case rest = "Rest"
    case setRest = "Rest between sets"

    var color: String {
        switch self {
        case .hang: return "green"
        case .rest, .setRest: return "blue"
        }
    }
}

struct TimerPhase: Identifiable {
    let kind: TimerPhaseKind
    let duration: Int // seconds
    let setNumber: Int
    let repNumber: Int?

    var id: String { "\(kind.rawValue)-\(setNumber)-\(repNumber ?? 0)-\(duration)" }
}

/// Builds the flat phase sequence for each preset. Both protocols are in the vault
/// (Max Hangs, Repeaters) — this just turns "3-4 x 4-5 x MED IntHangs x 7"-10" :20"/2'"-style
/// prose into a steppable timeline instead of the climber doing that arithmetic mid-session.
enum HangboardTimerBuilder {
    static func maxHangs(hangSeconds: Int, restSeconds: Int, sets: Int) -> [TimerPhase] {
        var phases: [TimerPhase] = []
        for s in 1...max(sets, 1) {
            phases.append(TimerPhase(kind: .hang, duration: hangSeconds, setNumber: s, repNumber: nil))
            if s < sets {
                phases.append(TimerPhase(kind: .rest, duration: restSeconds, setNumber: s, repNumber: nil))
            }
        }
        return phases
    }

    static func repeaters(hangSeconds: Int, interRepRestSeconds: Int, repsPerSet: Int, interSetRestSeconds: Int, sets: Int) -> [TimerPhase] {
        var phases: [TimerPhase] = []
        for s in 1...max(sets, 1) {
            for r in 1...max(repsPerSet, 1) {
                phases.append(TimerPhase(kind: .hang, duration: hangSeconds, setNumber: s, repNumber: r))
                if r < repsPerSet {
                    phases.append(TimerPhase(kind: .rest, duration: interRepRestSeconds, setNumber: s, repNumber: r))
                }
            }
            if s < sets {
                phases.append(TimerPhase(kind: .setRest, duration: interSetRestSeconds, setNumber: s, repNumber: nil))
            }
        }
        return phases
    }
}

@Observable
final class HangboardTimerEngine {
    private(set) var phases: [TimerPhase] = []
    private(set) var currentIndex = 0
    private(set) var isRunning = false
    private(set) var isFinished = false
    private(set) var phaseEndDate = Date.now

    private var pausedRemaining: TimeInterval?
    private var checkTimer: Timer?
    private var lastHapticSecond: Int?

    var currentPhase: TimerPhase? { phases.indices.contains(currentIndex) ? phases[currentIndex] : nil }
    var totalPhases: Int { phases.count }

    /// Whole seconds left in the current phase, for the countdown text. Recomputed from
    /// `phaseEndDate` on every call rather than stored, so the display and the ring can never
    /// drift apart from each other.
    func secondsRemaining(at date: Date = .now) -> Int {
        max(0, Int(ceil(phaseEndDate.timeIntervalSince(date))))
    }

    /// 0 at phase start, exactly 1 at phase end — continuous, not quantized to whole seconds,
    /// so the ring actually closes instead of topping out at "duration minus one second."
    func progress(at date: Date = .now) -> Double {
        guard let phase = currentPhase, phase.duration > 0 else { return 0 }
        let elapsed = Double(phase.duration) - phaseEndDate.timeIntervalSince(date)
        return min(1, max(0, elapsed / Double(phase.duration)))
    }

    func load(_ phases: [TimerPhase]) {
        stop()
        self.phases = phases
        if let first = phases.first {
            phaseEndDate = Date.now.addingTimeInterval(TimeInterval(first.duration))
        }
    }

    func start() {
        guard !phases.isEmpty, !isFinished else { return }
        isRunning = true
        UIApplication.shared.isIdleTimerDisabled = true
        // Resume picks up exactly where it paused rather than restarting the phase.
        if let remaining = pausedRemaining {
            phaseEndDate = Date.now.addingTimeInterval(remaining)
            pausedRemaining = nil
        }
        lastHapticSecond = nil
        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    func pause() {
        isRunning = false
        pausedRemaining = phaseEndDate.timeIntervalSinceNow
        checkTimer?.invalidate()
        checkTimer = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func reset() {
        pause()
        currentIndex = 0
        pausedRemaining = nil
        isFinished = false
        if let first = phases.first {
            phaseEndDate = Date.now.addingTimeInterval(TimeInterval(first.duration))
        }
    }

    func stop() {
        pause()
        phases = []
        currentIndex = 0
        pausedRemaining = nil
        isFinished = false
    }

    private func check() {
        let remaining = secondsRemaining()
        if remaining <= 2, remaining >= 1, remaining != lastHapticSecond {
            lastHapticSecond = remaining
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        guard Date.now >= phaseEndDate else { return }
        advancePhase()
    }

    private func advancePhase() {
        guard currentIndex + 1 < phases.count else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isFinished = true
            pause()
            return
        }
        currentIndex += 1
        // Advance from the previous end time, not `.now` — a check that lands a few tens of
        // milliseconds late shouldn't push every later phase back by that same amount.
        phaseEndDate = phaseEndDate.addingTimeInterval(TimeInterval(phases[currentIndex].duration))
        lastHapticSecond = nil
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
