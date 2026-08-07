import SwiftUI
import SwiftData
import UIKit

/// Inline set entry for a single session item, persisted as real `ExerciseSet` rows (this
/// replaces the old dummy `.constant("")` text fields). Which fields are shown, and which
/// live stop-rule checks apply, are decided by the module ID rather than one fixed form —
/// Max Hangs and Recruitment Pulls have almost nothing in common.
struct ExerciseSetEntryView: View {
    let sessionKey: String
    let moduleID: String
    let itemLabel: String
    let sessionStopRules: [String]
    /// Present only for `.lastSetOnly` items ("Primary finger method"): sets at or past this
    /// index are the ones that become cuttable when short on time; earlier sets never are.
    let minimumRequiredSets: Int?
    let isShortOnTime: Bool
    let ended: Bool
    let onTrip: (StopRuleTrigger) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var allSets: [ExerciseSet]

    @State private var edge = ""
    @State private var addedKG = ""
    @State private var duration = ""
    @State private var margin = ""
    @State private var peakForce = ""
    @State private var note = ""
    @State private var gripChangedThisSet = false
    @State private var recentGripFlags: [Bool] = []

    private var module: SeedModule? { SeedStore.shared.getModule(id: moduleID) }

    private var sets: [ExerciseSet] {
        allSets
            .filter { $0.sessionLogID == sessionKey && $0.moduleID == moduleID }
            .sorted { $0.setIndex < $1.setIndex }
    }

    private var showsEdgeAndHang: Bool {
        ["Max Hangs", "MED Hangs", "Grip Specificity Block"].contains(moduleID)
    }
    private var showsGripToggle: Bool { showsEdgeAndHang }
    private var showsPeakForce: Bool { moduleID == "Recruitment Pulls" }
    private var showsCatchQualityButton: Bool { moduleID == "Deadpoint Power" }
    private var showsShoulderButton: Bool { ["Weighted Pulls", "Deadpoint Power", "Contact Strength Ladder"].contains(moduleID) }
    private var showsFingerHazardButtons: Bool { ["Max Hangs", "MED Hangs", "Grip Specificity Block", "Recruitment Pulls", "Contact Strength Ladder"].contains(moduleID) }
    private var showsAddedKG: Bool { ["Weighted Pulls"].contains(moduleID) || showsEdgeAndHang }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !sets.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(sets) { s in
                        HStack(spacing: 8) {
                            Text("Set \(s.setIndex + 1)").font(.caption.monospaced()).foregroundStyle(.secondary)
                            if let e = s.edgeMM { Text("\(e)mm") }
                            if let a = s.addedKG { Text("+\(a, specifier: "%.1f")kg") }
                            if let d = s.durationSec { Text("\(d)s") }
                            if let m = s.marginSec { Text("margin \(m)s") }
                            if let p = s.peakForceKG { Text("peak \(p, specifier: "%.1f")kg") }
                            if isCuttable(s.setIndex) {
                                Text("cuttable").foregroundStyle(.orange)
                            }
                        }
                        .font(.caption)
                    }
                }
            }

            if showsFingerHazardButtons && !ended {
                HStack(spacing: 8) {
                    Button("Hot spot") { tripHotSpot() }
                        .buttonStyle(.borderedProminent).tint(.red)
                    Button("Pop / click / sting") { tripPopClickSting() }
                        .buttonStyle(.borderedProminent).tint(.red)
                }
                .font(.caption2.bold())
            }

            if showsShoulderButton && !ended {
                Button("Shoulder sensation") { tripShoulder() }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .tint(.orange)
            }

            if showsCatchQualityButton && !ended {
                Button("Catch quality dropped") { tripCatchQuality() }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .tint(.orange)
            }

            if ended {
                Text("Over for this exercise. Logging is closed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                setEntryRow
            }

            // The prescribed dose (when non-empty) is already rendered by the caller above
            // this view; when it's blank, offer the full vault note instead of nothing.
            if module?.dose?.isEmpty != false {
                VaultNoteLinkButton(noteTitle: moduleID)
            }
        }
    }

    private var setEntryRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if showsEdgeAndHang {
                    labeledField("Edge mm", text: $edge, keyboard: .numberPad, width: 60)
                }
                if showsAddedKG {
                    labeledField("+KG", text: $addedKG, keyboard: .decimalPad, width: 55)
                }
                if showsEdgeAndHang {
                    labeledField("Sec", text: $duration, keyboard: .numberPad, width: 45)
                    labeledField("Margin", text: $margin, keyboard: .numberPad, width: 55)
                }
                if showsPeakForce {
                    labeledField("Peak kg", text: $peakForce, keyboard: .decimalPad, width: 65)
                }
            }
            if showsGripToggle {
                Toggle("Grip changed mid-hang", isOn: $gripChangedThisSet)
                    .font(.caption)
                    .toggleStyle(.button)
            }
            HStack {
                TextField("Note (optional)", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                Button("Add set") { addSet() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, keyboard: UIKeyboardType, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            TextField("-", text: text)
                .keyboardType(keyboard)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
        }
    }

    private func isCuttable(_ setIndex: Int) -> Bool {
        guard isShortOnTime, let minimum = minimumRequiredSets else { return false }
        return setIndex >= minimum
    }

    private func addSet() {
        let set = ExerciseSet(sessionLogID: sessionKey, moduleID: moduleID, setIndex: sets.count)
        set.edgeMM = Int(edge)
        set.addedKG = Double(addedKG)
        set.durationSec = Int(duration)
        set.marginSec = Int(margin)
        set.peakForceKG = Double(peakForce)
        set.note = note.isEmpty ? nil : note
        modelContext.insert(set)
        try? modelContext.save()

        if showsPeakForce, let newPeak = set.peakForceKG {
            checkRecruitmentPullsDrop(newPeak: newPeak, priorSets: sets)
        }
        if showsGripToggle {
            checkGripChangeStreak()
        }

        edge = ""; addedKG = ""; duration = ""; margin = ""; peakForce = ""; note = ""
        gripChangedThisSet = false
    }

    /// Peak-force drop check needs load-cell data (`peakForceKG`). If nothing's been entered
    /// yet, there's no session best to compare against, so this stays silent rather than
    /// firing on incomplete data — per spec, inactive/hidden when there's no load cell, not
    /// an error state.
    private func checkRecruitmentPullsDrop(newPeak: Double, priorSets: [ExerciseSet]) {
        let priorPeaks = priorSets.compactMap { $0.peakForceKG }
        guard let sessionBest = priorPeaks.max() else { return }
        if newPeak < sessionBest * 0.95 {
            let quote = StopRuleText.bullet(containing: "peak", inModuleStopRules: module?.stopRules)
            onTrip(StopRuleTrigger(
                rule: "recruitment-pulls-peak-drop",
                scope: .exercise(itemLabel),
                headline: "\(itemLabel): over.",
                quote: quote,
                extra: nil,
                extraNoteToOpen: nil
            ))
        }
    }

    private func checkGripChangeStreak() {
        recentGripFlags.append(gripChangedThisSet)
        if Array(recentGripFlags.suffix(2)) == [true, true] {
            let quote = StopRuleText.quote(keyword: "grip", sessionStopRules: sessionStopRules, moduleID: moduleID)
            onTrip(StopRuleTrigger(
                rule: "grip-change-twice",
                scope: .exercise(itemLabel),
                headline: "\(itemLabel): over.",
                quote: quote,
                extra: nil,
                extraNoteToOpen: nil
            ))
        }
    }

    private func tripShoulder() {
        let quote = StopRuleText.quote(keyword: "shoulder", sessionStopRules: sessionStopRules, moduleID: moduleID)
        onTrip(StopRuleTrigger(
            rule: "shoulder-sensation",
            scope: .exercise(itemLabel),
            headline: "\(itemLabel): over for the day.",
            quote: quote,
            extra: nil,
            extraNoteToOpen: nil
        ))
    }

    private func tripCatchQuality() {
        let quote = StopRuleText.bullet(containing: "landing", inModuleStopRules: module?.stopRules)
            ?? StopRuleText.bullet(containing: "catch", inModuleStopRules: module?.stopRules)
        onTrip(StopRuleTrigger(
            rule: "catch-quality-dropped",
            scope: .exercise(itemLabel),
            headline: "\(itemLabel): over.",
            quote: quote,
            extra: nil,
            extraNoteToOpen: nil
        ))
    }

    private func tripHotSpot() {
        let quote = StopRuleText.quote(keyword: "hot spot", sessionStopRules: sessionStopRules, moduleID: "Limit Bouldering")
        onTrip(StopRuleTrigger(
            rule: "hot-spot",
            scope: .session,
            headline: "Session over.",
            quote: quote,
            extra: nil,
            extraNoteToOpen: nil
        ))
    }

    private func tripPopClickSting() {
        let quote = StopRuleText.quote(keyword: "pop", sessionStopRules: sessionStopRules, moduleID: moduleID)
            ?? StopRuleText.bullet(containing: "pop", inModuleStopRules: SeedStore.shared.getModule(id: "Deadpoint Power")?.stopRules)
        onTrip(StopRuleTrigger(
            rule: "pop-click-sting",
            scope: .session,
            headline: "Session over.",
            quote: quote,
            extra: StopRuleText.tendonHealthWarningSigns,
            extraNoteToOpen: StopRuleText.tendonHealthNote
        ))
    }
}
