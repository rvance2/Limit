import SwiftUI

private enum TimerPreset: String, CaseIterable, Identifiable {
    case maxHangs = "Max Hangs"
    case repeaters = "Repeaters"
    var id: String { rawValue }
}

/// Standalone interval timer for the two hangboard protocols that actually need one — Max
/// Hangs (sets of a single hang, long rest between) and Repeaters (sets of several short hangs,
/// a short rest between reps, a longer one between sets). Parameters default to the vault's
/// prescribed range and stay editable, since the real numbers shift week to week — see the
/// finger prescription card on Today/Plan for what today's actually calls for.
struct HangboardTimerView: View {
    @State private var preset: TimerPreset = .maxHangs
    @State private var engine = HangboardTimerEngine()

    // Max Hangs
    @State private var mhHang = 10
    @State private var mhRest = 180
    @State private var mhSets = 4

    // Repeaters
    @State private var rpHang = 8
    @State private var rpInterRepRest = 20
    @State private var rpReps = 5
    @State private var rpInterSetRest = 120
    @State private var rpSets = 4

    private var isConfiguring: Bool { engine.phases.isEmpty }

    var body: some View {
        Form {
            if isConfiguring {
                Section {
                    Picker("Protocol", selection: $preset) {
                        ForEach(TimerPreset.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section(preset == .maxHangs ? "Max Hangs" : "Repeaters") {
                    if preset == .maxHangs {
                        Stepper("Hang: \(mhHang) s", value: $mhHang, in: 3...20)
                        Stepper("Rest: \(mhRest / 60)m \(mhRest % 60)s", value: $mhRest, in: 30...360, step: 15)
                        Stepper("Sets: \(mhSets)", value: $mhSets, in: 1...8)
                        Text("Vault range: 7-12 s hang, 3-5 min rest, 3-5 sets.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Stepper("Hang: \(rpHang) s", value: $rpHang, in: 3...15)
                        Stepper("Rest between reps: \(rpInterRepRest) s", value: $rpInterRepRest, in: 5...60, step: 5)
                        Stepper("Reps per set: \(rpReps)", value: $rpReps, in: 1...10)
                        Stepper("Rest between sets: \(rpInterSetRest / 60)m \(rpInterSetRest % 60)s", value: $rpInterSetRest, in: 30...300, step: 15)
                        Stepper("Sets: \(rpSets)", value: $rpSets, in: 1...6)
                        Text("Vault range: 7-10 s hang, 20 s between reps, 4-5 reps, 2 min between sets, 3-4 sets.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Start") { loadAndStart() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
            } else {
                Section {
                    runningView
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    HStack(spacing: 12) {
                        Button(engine.isRunning ? "Pause" : "Resume") {
                            engine.isRunning ? engine.pause() : engine.start()
                        }
                        .buttonStyle(.bordered)
                        .disabled(engine.isFinished)
                        .frame(maxWidth: .infinity)

                        Button("Reset") { engine.stop() }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Timer")
        .onDisappear { engine.stop() }
    }

    private func loadAndStart() {
        let phases: [TimerPhase]
        switch preset {
        case .maxHangs:
            phases = HangboardTimerBuilder.maxHangs(hangSeconds: mhHang, restSeconds: mhRest, sets: mhSets)
        case .repeaters:
            phases = HangboardTimerBuilder.repeaters(
                hangSeconds: rpHang, interRepRestSeconds: rpInterRepRest,
                repsPerSet: rpReps, interSetRestSeconds: rpInterSetRest, sets: rpSets
            )
        }
        engine.load(phases)
        engine.start()
    }

    @ViewBuilder
    private var runningView: some View {
        if engine.isFinished {
            VStack(spacing: 12) {
                Text("Done").font(.largeTitle.bold())
                Text("\(preset.rawValue) complete.").foregroundStyle(.secondary)
            }
            .padding(.vertical, 40)
        } else if let phase = engine.currentPhase {
            VStack(spacing: 16) {
                TimelineView(.animation) { context in
                    ZStack {
                        Circle()
                            .stroke(Color(uiColor: .systemGray5), lineWidth: 14)
                        Circle()
                            .trim(from: 0, to: engine.progress(at: context.date))
                            .stroke(phaseColor(phase), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 4) {
                            Text(phase.kind == .hang ? "Hang" : "Rest")
                                .font(.headline)
                                .foregroundStyle(phaseColor(phase))
                            Text(timeString(engine.secondsRemaining(at: context.date)))
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                    }
                }
                .frame(width: 220, height: 220)
                .padding(.top, 12)

                Text(progressLabel(phase))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func phaseColor(_ phase: TimerPhase) -> Color {
        phase.kind == .hang ? .green : .blue
    }

    private func progressLabel(_ phase: TimerPhase) -> String {
        if let rep = phase.repNumber {
            return "Set \(phase.setNumber) of \(rpSets) · Rep \(rep) of \(rpReps)"
        }
        let totalSets = preset == .maxHangs ? mhSets : rpSets
        return "Set \(phase.setNumber) of \(totalSets)"
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview {
    NavigationStack { HangboardTimerView() }
}
