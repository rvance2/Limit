import Foundation

/// Sources the exact wording used on stop-rule cards from the vault / seed data instead of
/// re-typing paraphrased copy. Per-session `stopRules` (sessions.json) are tried first since
/// they're already short, single-sentence bullets; module `stopRules` (modules.json) are the
/// fallback for exercise-level rules that aren't called out per-session.
enum StopRuleText {
    /// First bullet containing `keyword` (case-insensitive) from a session template's
    /// `stopRules` array.
    static func bullet(containing keyword: String, in bullets: [String]) -> String? {
        bullets.first { $0.localizedCaseInsensitiveContains(keyword) }
    }

    /// First `- ` bullet line containing `keyword` from a module's markdown `stopRules` blob.
    static func bullet(containing keyword: String, inModuleStopRules stopRules: String?) -> String? {
        guard let stopRules, !stopRules.isEmpty else { return nil }
        return stopRules
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.localizedCaseInsensitiveContains(keyword) }
            .map { line in
                var l = line
                if l.hasPrefix("- ") { l.removeFirst(2) }
                return l
            }
    }

    /// Looks for `keyword` in the session template's own stop rules first, then the given
    /// module's stop rules. Returns nil (check should stay silent) rather than inventing text.
    static func quote(keyword: String, sessionStopRules: [String], moduleID: String?) -> String? {
        if let hit = bullet(containing: keyword, in: sessionStopRules) { return hit }
        if let moduleID, let module = SeedStore.shared.getModule(id: moduleID) {
            return bullet(containing: keyword, inModuleStopRules: module.stopRules)
        }
        return nil
    }

    // MARK: - Tendon Health warning signs (surfaced verbatim on the pop/click/sting stop card)

    private static let vault = VaultManager()

    /// The "## Warning signs, in order" section of the Tendon Health note, quoted verbatim
    /// (list items 1-4, the ones referenced by the pop/click/sting stop rule). Falls back to
    /// nil if the vault note can't be located, in which case callers should fall back to the
    /// "Read full note" link only.
    static var tendonHealthWarningSigns: String? {
        guard let note = vault.notes["Tendon Health"] else { return nil }
        return section(named: "Warning signs, in order", in: note.content)
    }

    static var tendonHealthNote: Note? { vault.notes["Tendon Health"] }
    static var vaultManager: VaultManager { vault }

    /// Extracts the body of a "## <name>" markdown section verbatim, up to the next "## " heading.
    private static func section(named name: String, in content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        guard let startIdx = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "## \(name)"
        }) else { return nil }

        var body: [String] = []
        for line in lines[(startIdx + 1)...] {
            if line.hasPrefix("## ") { break }
            body.append(line)
        }
        return body
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
