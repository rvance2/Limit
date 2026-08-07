import SwiftUI

/// What a stop-rule check found. `scope` decides whether the whole session ends or just one
/// exercise/item.
struct StopRuleTrigger: Identifiable {
    enum Scope: Equatable {
        case session
        case exercise(String)
    }

    let id = UUID()
    /// Stable machine key written into `SessionLog.stopRuleEvents`, e.g. "hot-spot".
    let rule: String
    let scope: Scope
    /// Short heading, e.g. "Session over." / "Recruitment Pulls: over."
    let headline: String
    /// Vault/session-sourced quote explaining the rule. Verbatim where available.
    let quote: String?
    /// Extra long-form text (used for the Tendon Health warning-sign list on pop/click/sting).
    let extra: String?
    let extraNoteToOpen: Note?
}

/// Full-width, non-dismissible-by-accident card for a tripped stop rule. This is deliberately
/// not a `.alert` — those are too easy to reflex-dismiss. The "stop" action is the large,
/// prominent, filled button; "override and continue" is present (the rule is enforced but not
/// mandatory) but styled small and plain so it isn't the path of least resistance. Overriding
/// still writes to `SessionLog.stopRuleEvents` with `overridden:true`, so the data shows it happened.
struct StopRuleCardView: View {
    let trigger: StopRuleTrigger
    let onEnd: () -> Void
    let onOverride: () -> Void

    @State private var showingNote = false
    @State private var confirmingOverride = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .foregroundStyle(.red)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(scopeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(trigger.headline)
                        .font(.title3.bold())
                }
                Spacer()
            }

            if let quote = trigger.quote {
                Text(MarkdownView.attributed(quote))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let extra = trigger.extra {
                Text(MarkdownView.attributed(extra))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .background(Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let note = trigger.extraNoteToOpen {
                Button("Read Tendon Health") { showingNote = true }
                    .font(.footnote)
                    .sheet(isPresented: $showingNote) {
                        NavigationStack {
                            NoteView(note: note, manager: StopRuleText.vaultManager)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("Close") { showingNote = false }
                                    }
                                }
                        }
                    }
            }

            Button(action: onEnd) {
                Text(endButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            if confirmingOverride {
                HStack {
                    Text("Logged as overridden either way.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Confirm override") {
                        onOverride()
                    }
                    .font(.caption)
                }
            } else {
                Button("Override and continue") {
                    confirmingOverride = true
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 8)
        .padding()
        // No swipe-to-dismiss, no tap-outside-to-dismiss: the two buttons above are the only exits.
    }

    private var scopeLabel: String {
        switch trigger.scope {
        case .session: return "Stop rule, session"
        case .exercise(let name): return "Stop rule, \(name)"
        }
    }

    private var endButtonTitle: String {
        switch trigger.scope {
        case .session: return "End session"
        case .exercise: return "End exercise"
        }
    }
}
