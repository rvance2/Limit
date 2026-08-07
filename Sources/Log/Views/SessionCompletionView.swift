import SwiftUI
import SwiftData

/// Session RPE and one-line note, written straight to `SessionLog` on save. Everything here
/// is optional except RPE — a half-filled log beats an abandoned one, but RPE is cheap enough
/// (one tap) that defaulting it and letting it be skipped isn't worth the ambiguity.
struct SessionCompletionView: View {
    @Bindable var sessionLog: SessionLog
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var rpe: Int
    @State private var note: String
    @State private var durationText: String
    @State private var footSlipsText: String

    init(sessionLog: SessionLog, onDone: @escaping () -> Void) {
        self.sessionLog = sessionLog
        self.onDone = onDone
        _rpe = State(initialValue: sessionLog.sessionRPE1to10 ?? 5)
        _note = State(initialValue: sessionLog.oneLineNote ?? "")
        _durationText = State(initialValue: sessionLog.actualDuration.map(String.init) ?? "")
        _footSlipsText = State(initialValue: sessionLog.footSlips.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("RPE")) {
                    Stepper("Session RPE: \(rpe)/10", value: $rpe, in: 1...10)
                }
                Section(header: Text("Note")) {
                    TextField("One line", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
                Section(header: Text("Optional")) {
                    HStack {
                        Text("Actual duration (min)")
                        Spacer()
                        TextField("-", text: $durationText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    HStack {
                        Text("Foot slips")
                        Spacer()
                        TextField("-", text: $footSlipsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }
                if !sessionLog.stopRuleEvents.isEmpty {
                    Section(header: Text("Stop rule events")) {
                        ForEach(sessionLog.stopRuleEvents, id: \.self) { event in
                            Text(event).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Log it")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        sessionLog.sessionRPE1to10 = rpe
        sessionLog.oneLineNote = note.isEmpty ? nil : note
        sessionLog.actualDuration = Int(durationText)
        sessionLog.footSlips = Int(footSlipsText)
        try? modelContext.save()
        onDone()
    }
}
