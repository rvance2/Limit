import SwiftUI

/// Many modules have empty `dose`/`stopRules` strings because the vault notes don't use a
/// uniform header (per the product spec). Rather than show a blank line, offer a way to open
/// the full vault note — reusing the Library tab's `NoteView` the same way `limit://note/<name>`
/// links do inside `MarkdownView`, but presented locally as a sheet so it doesn't depend on the
/// Library tab's own `onOpenURL` handler (which is scoped to that tab's `NavigationStack` and
/// won't switch tabs to catch a cross-tab URL).
struct VaultNoteLinkButton: View {
    let noteTitle: String

    @State private var showingNote = false

    var body: some View {
        if let note = StopRuleText.vaultManager.notes[noteTitle] {
            Button {
                showingNote = true
            } label: {
                Label("Open \"\(noteTitle)\" note", systemImage: "book")
                    .font(.caption)
            }
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
    }
}
