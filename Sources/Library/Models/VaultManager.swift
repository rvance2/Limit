import Foundation
import SwiftUI

struct Note: Identifiable, Hashable {
    let id: String
    let title: String
    let content: String
    let folder: String
    let frontmatter: [String: String]
    let links: [String]
    let tags: [String]
    
    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }
}

@Observable
final class VaultManager {
    var notes: [String: Note] = [:]
    var backlinks: [String: [String]] = [:]
    
    init() {
        loadNotes()
    }
    
    private func loadNotes() {
        guard let vaultUrl = Bundle.main.url(forResource: "Vault", withExtension: nil) else {
            print("Vault folder not found in bundle")
            return
        }
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: vaultUrl, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return
        }
        
        var loadedNotes: [String: Note] = [:]
        
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "md" else { continue }
            
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let title = fileURL.deletingPathExtension().lastPathComponent
                
                // Get relative path for folder
                let relativePath = fileURL.path.replacingOccurrences(of: vaultUrl.path + "/", with: "")
                let folder = (relativePath as NSString).deletingLastPathComponent
                
                let parsed = parseMarkdown(content: content)
                
                let note = Note(
                    id: title,
                    title: title,
                    content: parsed.body,
                    folder: folder,
                    frontmatter: parsed.frontmatter,
                    links: parsed.links,
                    tags: parsed.tags
                )
                
                loadedNotes[title] = note
            } catch {
                print("Failed to read note \(fileURL): \(error)")
            }
        }
        
        self.notes = loadedNotes
        calculateBacklinks()
    }
    
    private func calculateBacklinks() {
        var newBacklinks: [String: [String]] = [:]
        
        for (id, note) in notes {
            for link in note.links {
                if newBacklinks[link] == nil {
                    newBacklinks[link] = []
                }
                if !newBacklinks[link]!.contains(id) {
                    newBacklinks[link]!.append(id)
                }
            }
        }
        
        self.backlinks = newBacklinks
    }
    
    private func parseMarkdown(content: String) -> (frontmatter: [String: String], body: String, links: [String], tags: [String]) {
        var frontmatter: [String: String] = [:]
        var body = content
        var tags: [String] = []
        
        // Parse frontmatter
        let lines = content.components(separatedBy: .newlines)
        if lines.count > 0 && lines[0].trimmingCharacters(in: .whitespaces) == "---" {
            var endIdx = -1
            for i in 1..<lines.count {
                if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                    endIdx = i
                    break
                }
            }
            if endIdx != -1 {
                for i in 1..<endIdx {
                    let parts = lines[i].split(separator: ":", maxSplits: 1).map(String.init)
                    if parts.count == 2 {
                        let key = parts[0].trimmingCharacters(in: .whitespaces)
                        let val = parts[1].trimmingCharacters(in: .whitespaces)
                        frontmatter[key] = val
                        
                        if key == "tags" {
                            // simple tag parsing: [hub, something]
                            let cleaned = val.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                            tags = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        }
                    }
                }
                body = lines[(endIdx + 1)...].joined(separator: "\n")
            }
        }
        
        // Extract wikilinks: [[Something]] or [[Something|Alias]].
        // Scan the *whole* raw content, not just `body` — some notes only reference a
        // related note from a frontmatter field (e.g. `trains: [[Finger Strength]]`), and
        // scanning body-only silently dropped those from both `links` and the derived
        // `backlinks` map. Across the vault this was 117 of 1,091 wikilinks (~11%).
        var links: [String] = []
        let pattern = "\\[\\[(.*?)\\]\\]"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsrange = NSRange(content.startIndex..<content.endIndex, in: content)
            let matches = regex.matches(in: content, options: [], range: nsrange)

            for match in matches {
                if let range = Range(match.range(at: 1), in: content) {
                    let linkContent = String(content[range])
                    let target = linkContent.components(separatedBy: "|").first!.trimmingCharacters(in: .whitespaces)
                    links.append(target)
                }
            }
        }

        return (frontmatter, body, Set(links).sorted(), tags)
    }
    
    func search(query: String) -> [Note] {
        guard !query.isEmpty else { return Array(notes.values).sorted(by: { $0.title < $1.title }) }
        let lower = query.lowercased()
        return notes.values.filter { note in
            note.title.lowercased().contains(lower) || note.content.lowercased().contains(lower)
        }.sorted(by: { $0.title < $1.title })
    }
}
