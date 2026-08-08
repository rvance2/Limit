import SwiftUI

/// Wraps arbitrary row content in a `NavigationLink` to the matching vault note when one
/// exists, falling back to plain content otherwise. The destination pushes onto the caller's
/// own `NavigationStack` (native back arrow to return) rather than presenting a sheet, so it
/// requires `.navigationDestination(for: Note.self)` registered somewhere above it — see
/// `TodayView`.
///
/// A single small book glyph, tertiary-colored, is the only visual cue. Deliberately not an
/// underline or accent-colored text: a session list or a non-negotiables list with five
/// underlined links reads like a web page, not a training log.
struct VaultLinkedRow<Content: View>: View {
    let noteTitle: String?
    @ViewBuilder var content: () -> Content

    private var note: Note? {
        noteTitle.flatMap { StopRuleText.vaultManager.notes[$0] }
    }

    var body: some View {
        if let note {
            NavigationLink(value: note) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    content()
                    Image(systemName: "book.closed")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        } else {
            content()
        }
    }
}
