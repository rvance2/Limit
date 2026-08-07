import SwiftUI
import SwiftData
import PhotosUI

// MARK: - 1. Finger strength — 7-second two-arm max hang

struct FingerHangCard: View {
    let item: TestItem
    let weekNumber: Int
    let allResults: [TestResult]

    @Environment(\.modelContext) private var modelContext
    @State private var edge = "20mm"
    @State private var loadKG = ""
    @State private var notes = ""

    private let edges = ["18mm", "20mm", "22mm"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let protocolText = item.protocolText {
                Text(MarkdownView.attributed(protocolText))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Picker("Edge", selection: $edge) {
                ForEach(edges, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)

            TextField("Total load, kg (bodyweight + added)", text: $loadKG)
                .keyboardType(.decimalPad)

            TextField("Notes", text: $notes)

            Button("Log it") { save() }
                .buttonStyle(.borderedProminent)
        }
        .task(id: weekNumber) { load() }
    }

    private func load() {
        guard let existing = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: edge)
            ?? allResults.first(where: { $0.weekNumber == weekNumber && $0.testItemID == item.id }) else {
            loadKG = ""; notes = ""
            return
        }
        edge = existing.protocolVariant ?? "20mm"
        loadKG = existing.value.map { String($0) } ?? ""
        notes = existing.notes ?? ""
    }

    private func save() {
        TestResultStore.upsert(
            context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id,
            protocolVariant: edge, value: Double(loadKG), unit: "kg", notes: notes.isEmpty ? nil : notes
        )
        try? modelContext.save()
    }
}

// MARK: - 2. Pulling strength — 2RM weighted pull-up

struct PullUpCard: View {
    let item: TestItem
    let weekNumber: Int
    let allResults: [TestResult]

    @Environment(\.modelContext) private var modelContext
    @State private var loadKG = ""
    @State private var estimated1RM = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let protocolText = item.protocolText {
                Text(MarkdownView.attributed(protocolText))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // No shoulder modification — version one carried one on an assumed anterior
            // instability that doesn't match how the shoulder actually behaves. What's kept:
            // don't test a true 1RM, estimate it from the 2RM instead.
            Label("Do not test a true 1RM. Estimate it from this 2RM.", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Total load, kg (bodyweight + added)", text: $loadKG)
                .keyboardType(.decimalPad)
            TextField("Estimated 1RM, kg", text: $estimated1RM)
                .keyboardType(.decimalPad)

            Button("Log it") { save() }
                .buttonStyle(.borderedProminent)
        }
        .task(id: weekNumber) { load() }
    }

    private func load() {
        loadKG = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "2rm_kg")?.value.map { String($0) } ?? ""
        estimated1RM = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "estimated_1rm_kg")?.value.map { String($0) } ?? ""
    }

    private func save() {
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "2rm_kg", value: Double(loadKG), unit: "kg", notes: nil)
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "estimated_1rm_kg", value: Double(estimated1RM), unit: "kg", notes: nil)
        try? modelContext.save()
    }
}

// MARK: - 2b. One-arm lock-off hold time

struct OneArmLockoffCard: View {
    let item: TestItem
    let weekNumber: Int
    let allResults: [TestResult]

    @Environment(\.modelContext) private var modelContext

    private struct Angle: Identifiable {
        let id: String
        let label: String
    }
    private let angles: [Angle] = [
        .init(id: "full", label: "Full lock (chin at bar height)"),
        .init(id: "90", label: "90° elbow"),
        .init(id: "120", label: "120° elbow"),
    ]

    @State private var leftSeconds: [String: String] = [:]
    @State private var rightSeconds: [String: String] = [:]
    @State private var assisted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let protocolText = item.protocolText {
                Text(MarkdownView.attributed(protocolText))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Toggle("Assisted", isOn: $assisted)
                .font(.subheadline)

            ForEach(angles) { angle in
                VStack(alignment: .leading, spacing: 4) {
                    Text(angle.label).font(.subheadline.weight(.semibold))
                    HStack {
                        TextField("Left, s", text: bindingFor($leftSeconds, angle.id))
                            .keyboardType(.decimalPad)
                        TextField("Right, s", text: bindingFor($rightSeconds, angle.id))
                            .keyboardType(.decimalPad)
                    }
                    if let asym = asymmetry(angle.id) {
                        Text("Asymmetry: \(asym, specifier: "%.0f")%\(abs(asym) > 15 ? " (stop-progressing signal)" : "")")
                            .font(.caption2)
                            .foregroundStyle(abs(asym) > 15 ? .orange : .secondary)
                    }
                }
            }

            Button("Log it") { save() }
                .buttonStyle(.borderedProminent)
        }
        .task(id: weekNumber) { load() }
    }

    private func bindingFor(_ dict: Binding<[String: String]>, _ key: String) -> Binding<String> {
        Binding(get: { dict.wrappedValue[key] ?? "" }, set: { dict.wrappedValue[key] = $0 })
    }

    private func asymmetry(_ angleId: String) -> Double? {
        guard let l = Double(leftSeconds[angleId] ?? ""), let r = Double(rightSeconds[angleId] ?? ""), max(l, r) > 0 else { return nil }
        return (abs(l - r) / max(l, r)) * 100
    }

    private func load() {
        for angle in angles {
            leftSeconds[angle.id] = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "\(angle.id)_left_s")?.value.map { String($0) } ?? ""
            rightSeconds[angle.id] = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "\(angle.id)_right_s")?.value.map { String($0) } ?? ""
        }
        assisted = (TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "assisted")?.value ?? 0) == 1
    }

    private func save() {
        for angle in angles {
            TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "\(angle.id)_left_s", value: Double(leftSeconds[angle.id] ?? ""), unit: "s", notes: assisted ? "assisted" : nil)
            TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "\(angle.id)_right_s", value: Double(rightSeconds[angle.id] ?? ""), unit: "s", notes: assisted ? "assisted" : nil)
        }
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "assisted", value: assisted ? 1 : 0, unit: "bool", notes: nil)
        try? modelContext.save()
    }
}

// MARK: - 2c. Deep shoulder position capacity

struct DeepShoulderCapacityCard: View {
    let item: TestItem
    let weekNumber: Int
    let allResults: [TestResult]

    @Environment(\.modelContext) private var modelContext

    @State private var twoArmUnderclingS = ""
    @State private var singleArmUnderclingLeftS = ""
    @State private var singleArmUnderclingRightS = ""
    @State private var crossBodyLeftS = ""
    @State private var crossBodyRightS = ""
    @State private var crossBodyLoadedLeftS = ""
    @State private var crossBodyLoadedRightS = ""
    @State private var clickScore = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let protocolText = item.protocolText {
                Text(MarkdownView.attributed(protocolText))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("Track A: underclings").font(.subheadline.weight(.semibold))
            TextField("Two-arm undercling hold, s (target 30 s)", text: $twoArmUnderclingS).keyboardType(.decimalPad)
            HStack {
                TextField("Single-arm L, s", text: $singleArmUnderclingLeftS).keyboardType(.decimalPad)
                TextField("Single-arm R, s", text: $singleArmUnderclingRightS).keyboardType(.decimalPad)
            }

            Divider()

            Text("Track B: cross-body isolation").font(.subheadline.weight(.semibold))
            HStack {
                TextField("Unloaded L, s", text: $crossBodyLeftS).keyboardType(.decimalPad)
                TextField("Unloaded R, s", text: $crossBodyRightS).keyboardType(.decimalPad)
            }
            HStack {
                TextField("Opposing arm loaded L, s", text: $crossBodyLoadedLeftS).keyboardType(.decimalPad)
                TextField("Opposing arm loaded R, s", text: $crossBodyLoadedRightS).keyboardType(.decimalPad)
            }

            Divider()

            Stepper("Click score: \(clickScore) (\(clickLabel(clickScore)))", value: $clickScore, in: 0...3)
                .font(.subheadline)

            Button("Log it") { save() }
                .buttonStyle(.borderedProminent)
        }
        .task(id: weekNumber) { load() }
    }

    private func clickLabel(_ score: Int) -> String {
        switch score {
        case 0: return "none"
        case 1: return "faint"
        case 2: return "obvious"
        default: return "uncomfortable"
        }
    }

    private func load() {
        twoArmUnderclingS = value("two_arm_undercling_s")
        singleArmUnderclingLeftS = value("single_arm_undercling_left_s")
        singleArmUnderclingRightS = value("single_arm_undercling_right_s")
        crossBodyLeftS = value("cross_body_left_s")
        crossBodyRightS = value("cross_body_right_s")
        crossBodyLoadedLeftS = value("cross_body_loaded_left_s")
        crossBodyLoadedRightS = value("cross_body_loaded_right_s")
        clickScore = Int(TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "click_score")?.value ?? 0)
    }

    private func value(_ variant: String) -> String {
        TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: variant)?.value.map { String($0) } ?? ""
    }

    private func save() {
        let fields: [(String, String)] = [
            ("two_arm_undercling_s", twoArmUnderclingS),
            ("single_arm_undercling_left_s", singleArmUnderclingLeftS),
            ("single_arm_undercling_right_s", singleArmUnderclingRightS),
            ("cross_body_left_s", crossBodyLeftS),
            ("cross_body_right_s", crossBodyRightS),
            ("cross_body_loaded_left_s", crossBodyLoadedLeftS),
            ("cross_body_loaded_right_s", crossBodyLoadedRightS),
        ]
        for (variant, text) in fields {
            TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: variant, value: Double(text), unit: "s", notes: nil)
        }
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "click_score", value: Double(clickScore), unit: "0-3", notes: nil)
        try? modelContext.save()
    }
}

// MARK: - 3. Critical force — load cell only

struct CriticalForceCard: View {
    let item: TestItem
    let weekNumber: Int
    let allResults: [TestResult]

    @Environment(\.modelContext) private var modelContext
    @State private var criticalForceKG = ""
    @State private var impulseAbove = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let protocolText = item.protocolText {
                Text(MarkdownView.attributed(protocolText))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text("Fatigue marker, not target. A drop of 8%+ from baseline means accumulating fatigue faster than clearing it.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Critical force, kg (mean end-test)", text: $criticalForceKG)
                .keyboardType(.decimalPad)
            TextField("Impulse above critical force", text: $impulseAbove)
                .keyboardType(.decimalPad)

            Button("Log it") { save() }
                .buttonStyle(.borderedProminent)
        }
        .task(id: weekNumber) { load() }
    }

    private func load() {
        if let cf = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "mean_end_test_force_kg") {
            criticalForceKG = cf.value.map { String($0) } ?? ""
        } else {
            criticalForceKG = ""
        }
        if let imp = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "impulse_above_kg") {
            impulseAbove = imp.value.map { String($0) } ?? ""
        } else {
            impulseAbove = ""
        }
    }

    private func save() {
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "mean_end_test_force_kg", value: Double(criticalForceKG), unit: "kg", notes: nil)
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "impulse_above_kg", value: Double(impulseAbove), unit: "kg", notes: nil)
        try? modelContext.save()
    }
}

// MARK: - 4. Mobility

struct MobilityCard: View {
    let item: TestItem
    let weekNumber: Int
    let allResults: [TestResult]

    @Environment(\.modelContext) private var modelContext
    @AppStorage("heightCM") private var heightCM: Double = 0

    @State private var boxSplitCM = ""
    @State private var ankleLeftCM = ""
    @State private var ankleRightCM = ""
    @State private var hipLeftDeg = ""
    @State private var hipRightDeg = ""

    // Exact protocolVariant convention — Charts (built in parallel) reads these.
    private let vBoxSplit = "box_split_cm"
    private let vBoxSplitNorm = "box_split_normalized"
    private let vAnkleLeft = "ankle_dorsiflexion_left_cm"
    private let vAnkleRight = "ankle_dorsiflexion_right_cm"
    private let vHipLeft = "hip_rotation_left_deg"
    private let vHipRight = "hip_rotation_right_deg"

    private var normalizedBoxSplit: Double? {
        guard let raw = Double(boxSplitCM), heightCM > 0 else { return nil }
        return raw / heightCM
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Height, cm (used to normalize box split)")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Height (cm)", value: $heightCM, format: .number)
                .keyboardType(.decimalPad)

            Divider()

            Text("Box split. Against a wall, toes and stomach touching, feet moving wider while contact is maintained. Heel-to-heel, cm.")
                .font(.footnote).foregroundStyle(.secondary)
            TextField("Box split, heel-to-heel (cm)", text: $boxSplitCM)
                .keyboardType(.decimalPad)
            if let normalized = normalizedBoxSplit {
                Text("Normalized: \(normalized, specifier: "%.3f") (× height)")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            Text("Ankle dorsiflexion. Knee-to-wall, toe-to-wall, cm.")
                .font(.footnote).foregroundStyle(.secondary)
            TextField("Left (cm)", text: $ankleLeftCM).keyboardType(.decimalPad)
            TextField("Right (cm)", text: $ankleRightCM).keyboardType(.decimalPad)

            Divider()

            Text("90/90 hip rotation, both directions, degrees.")
                .font(.footnote).foregroundStyle(.secondary)
            TextField("Left (deg)", text: $hipLeftDeg).keyboardType(.decimalPad)
            TextField("Right (deg)", text: $hipRightDeg).keyboardType(.decimalPad)

            Button("Log it") { save() }
                .buttonStyle(.borderedProminent)
        }
        .task(id: weekNumber) { load() }
    }

    private func load() {
        boxSplitCM = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: vBoxSplit)?.value.map { String($0) } ?? ""
        ankleLeftCM = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: vAnkleLeft)?.value.map { String($0) } ?? ""
        ankleRightCM = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: vAnkleRight)?.value.map { String($0) } ?? ""
        hipLeftDeg = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: vHipLeft)?.value.map { String($0) } ?? ""
        hipRightDeg = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: vHipRight)?.value.map { String($0) } ?? ""
    }

    private func save() {
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: vBoxSplit, value: Double(boxSplitCM), unit: "cm", notes: nil)
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: vBoxSplitNorm, value: normalizedBoxSplit, unit: "x height", notes: nil)
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: vAnkleLeft, value: Double(ankleLeftCM), unit: "cm", notes: nil)
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: vAnkleRight, value: Double(ankleRightCM), unit: "cm", notes: nil)
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: vHipLeft, value: Double(hipLeftDeg), unit: "deg", notes: nil)
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: vHipRight, value: Double(hipRightDeg), unit: "deg", notes: nil)
        try? modelContext.save()
    }
}

// MARK: - 5. Shoulder screen

private struct ShoulderScreenItem: Identifiable {
    let id: String
    let text: String
}

// Matches Shoulder Protocol.md's current 8-item session exactly.
private let shoulderProtocolItems: [ShoulderScreenItem] = [
    .init(id: "item_1", text: "Half-kneeling banded or cable external rotation at 90° abduction. 3 × 8-10 each side, heavy enough that rep 10 is hard."),
    .init(id: "item_2", text: "Prone or bench external rotation with a dumbbell at 90°. 3 × 8 each side. Slow eccentric."),
    .init(id: "item_3", text: "Bottoms-up kettlebell press or hold. 3 × 20-30 s each side."),
    .init(id: "item_4", text: "Loaded serratus punch or wall slide with resistance. 3 × 10."),
    .init(id: "item_5", text: "Prone lower-trap raise at 120°, weighted. 3 × 10."),
    .init(id: "item_6", text: "Scap pull-ups. 3 × 8, weighted once bodyweight is easy."),
    .init(id: "item_7", text: "Overhead carry or waiter's walk, 3 × 30 m each side."),
    .init(id: "item_8", text: "Controlled articular rotations, 3 slow circles each direction, end range."),
]

struct ShoulderScreenCard: View {
    let item: TestItem
    let weekNumber: Int
    let allResults: [TestResult]

    @Environment(\.modelContext) private var modelContext
    @State private var clickScores: [String: Int] = [:]
    @State private var underclingClickLoadKG = ""
    @State private var crossBodyClickLoadKG = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Run Shoulder Protocol at working load, not zero resistance. Note which items lack control and the click score 0-3 per item.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Not medical advice. I have never had this assessed and should. Nothing here is a diagnosis. But a painless, positional, functionally silent click does not justify pausing training while I wait for an appointment.")
                .font(.caption)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .foregroundStyle(.orange)
                .cornerRadius(6)

            ForEach(shoulderProtocolItems) { entry in
                Stepper(
                    "\(entry.text)  ·  click \(clickScores[entry.id] ?? 0)",
                    value: Binding(
                        get: { clickScores[entry.id] ?? 0 },
                        set: { clickScores[entry.id] = $0 }
                    ),
                    in: 0...3
                )
                .font(.subheadline)
            }

            Divider()

            Text("Also test both provocative positions deliberately. Record the load at which the click first appears. That number rising over 22 weeks is the outcome wanted.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("Loaded undercling, click onset kg", text: $underclingClickLoadKG)
                .keyboardType(.decimalPad)
            TextField("Cross-body isolation, click onset kg", text: $crossBodyClickLoadKG)
                .keyboardType(.decimalPad)

            Button("Log it") { save() }
                .buttonStyle(.borderedProminent)
        }
        .task(id: weekNumber) { load() }
    }

    private func load() {
        var loaded: [String: Int] = [:]
        for entry in shoulderProtocolItems {
            loaded[entry.id] = Int(TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: entry.id)?.value ?? 0)
        }
        clickScores = loaded
        underclingClickLoadKG = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "undercling_click_onset_kg")?.value.map { String($0) } ?? ""
        crossBodyClickLoadKG = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "cross_body_click_onset_kg")?.value.map { String($0) } ?? ""
    }

    private func save() {
        for entry in shoulderProtocolItems {
            let score = clickScores[entry.id] ?? 0
            TestResultStore.upsert(
                context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id,
                protocolVariant: entry.id, value: Double(score), unit: "0-3",
                notes: score >= 2 ? "lacking control" : nil
            )
        }
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "undercling_click_onset_kg", value: Double(underclingClickLoadKG), unit: "kg", notes: nil)
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "cross_body_click_onset_kg", value: Double(crossBodyClickLoadKG), unit: "kg", notes: nil)
        try? modelContext.save()
    }
}

// MARK: - 6. Skill markers

struct SkillMarkersCard: View {
    let item: TestItem
    let weekNumber: Int
    let allResults: [TestResult]

    @Environment(\.modelContext) private var modelContext

    @State private var footSlips = ""
    @State private var attemptsToSend = ""
    @State private var hipPathNote = ""

    @State private var flashPicker: PhotosPickerItem?
    @State private var solidLimitPicker: PhotosPickerItem?
    @State private var doneOncePicker: PhotosPickerItem?

    @State private var flashRef: String?
    @State private var solidLimitRef: String?
    @State private var doneOnceRef: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Benchmark video, three boulders: flash level, solid limit, done-once. Side-on. Same three each test point, or as close as gym resetting allows.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            videoRow(label: "Flash level", picker: $flashPicker, ref: $flashRef)
            videoRow(label: "Solid limit", picker: $solidLimitPicker, ref: $solidLimitRef)
            videoRow(label: "Done-once", picker: $doneOncePicker, ref: $doneOnceRef)

            Divider()

            TextField("Foot slips (counted across the whole session)", text: $footSlips)
                .keyboardType(.numberPad)
            TextField("Attempts-to-send, done-once benchmark, from cold", text: $attemptsToSend)
                .keyboardType(.numberPad)
            TextField("Hip path note (total path length vs vertical gain)", text: $hipPathNote, axis: .vertical)

            Button("Log it") { save() }
                .buttonStyle(.borderedProminent)
        }
        .task(id: weekNumber) { load() }
        .onChange(of: flashPicker) { _, new in importVideo(new) { flashRef = $0 } }
        .onChange(of: solidLimitPicker) { _, new in importVideo(new) { solidLimitRef = $0 } }
        .onChange(of: doneOncePicker) { _, new in importVideo(new) { doneOnceRef = $0 } }
    }

    private func videoRow(label: String, picker: Binding<PhotosPickerItem?>, ref: Binding<String?>) -> some View {
        HStack {
            Text(label)
            Spacer()
            if ref.wrappedValue != nil {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            PhotosPicker(selection: picker, matching: .videos) {
                Label(ref.wrappedValue == nil ? "Attach clip" : "Replace clip", systemImage: "video.badge.plus")
            }
        }
    }

    private func importVideo(_ item: PhotosPickerItem?, completion: @escaping (String) -> Void) {
        guard let item else { return }
        Task {
            if let picked = try? await item.loadTransferable(type: PickedMediaFile.self) {
                completion(picked.relativeRef)
            }
        }
    }

    private func load() {
        flashRef = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "video_flash")?.mediaRef
        solidLimitRef = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "video_solid_limit")?.mediaRef
        doneOnceRef = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "video_done_once")?.mediaRef
        footSlips = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "foot_slips")?.value.map { String(Int($0)) } ?? ""
        attemptsToSend = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "attempts_to_send")?.value.map { String(Int($0)) } ?? ""
        hipPathNote = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "hip_path_note")?.notes ?? ""
    }

    private func save() {
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "video_flash", mediaRef: flashRef)
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "video_solid_limit", mediaRef: solidLimitRef)
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "video_done_once", mediaRef: doneOnceRef)
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "foot_slips", value: Double(footSlips), unit: "count", notes: nil)
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "attempts_to_send", value: Double(attemptsToSend), unit: "count", notes: nil)
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: "hip_path_note", notes: hipPathNote.isEmpty ? nil : hipPathNote)
        try? modelContext.save()
    }
}

// MARK: - 7. Body composition — bodyweight only

struct BodyweightCard: View {
    let item: TestItem
    let weekNumber: Int
    let allResults: [TestResult]

    @Environment(\.modelContext) private var modelContext
    @State private var bodyweightKG = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Bodyweight (kg)", text: $bodyweightKG)
                .keyboardType(.decimalPad)
            Text("Bodyweight only. No skinfolds, no body-fat estimates. Anthropometric factors explain a tiny fraction of grade variance and tracking them invites the failure mode in Energy.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Log it") { save() }
                .buttonStyle(.borderedProminent)
        }
        .task(id: weekNumber) { load() }
    }

    private func load() {
        bodyweightKG = TestResultStore.find(in: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: nil)?.value.map { String($0) } ?? ""
    }

    private func save() {
        TestResultStore.upsert(context: modelContext, existing: allResults, weekNumber: weekNumber, testItemID: item.id, protocolVariant: nil, value: Double(bodyweightKG), unit: "kg", notes: nil)
        try? modelContext.save()
    }
}
