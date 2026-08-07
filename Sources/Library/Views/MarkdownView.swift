import SwiftUI

/// Renders vault note bodies: pipe tables and fenced code blocks as real SwiftUI content,
/// everything else falls back to `AttributedString(markdown:)` for inline formatting
/// (bold/italic/links) plus wikilink-to-`limit://note/` conversion — same as before, just
/// scoped to the non-table/non-code portions now.
struct MarkdownView: View {
    let content: String

    private var blocks: [MarkdownBlock] {
        MarkdownView.parseBlocks(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                render(block)
            }
        }
    }

    @ViewBuilder
    private func render(_ block: MarkdownBlock) -> some View {
        switch block {
        case .prose(let text):
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(MarkdownView.attributed(text))
                    .textSelection(.enabled)
            }
        case .heading(let level, let text):
            Text(MarkdownView.attributed(text))
                .font(headingFont(level))
                .fontWeight(.bold)
                .textSelection(.enabled)
                .padding(.top, level <= 2 ? 6 : 2)
        case .code(let language, let code):
            codeBlock(language: language, code: code)
        case .table(let header, let alignments, let rows):
            table(header: header, alignments: alignments, rows: rows)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        case 3: return .title3
        case 4: return .headline
        default: return .subheadline
        }
    }

    // MARK: - Code blocks

    private func codeBlock(language: String?, code: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let language, !language.isEmpty {
                Text(language)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Tables

    private func table(header: [String], alignments: [TextAlignment], rows: [[String]]) -> some View {
        let columnCount = header.count

        return ScrollView(.horizontal, showsIndicators: true) {
            Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    ForEach(Array(header.enumerated()), id: \.offset) { index, cell in
                        Text(MarkdownView.attributed(cell))
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: horizontalAlignment(index, alignments))
                    }
                }

                Divider()
                    .gridCellColumns(max(columnCount, 1))

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(0..<columnCount, id: \.self) { index in
                            Text(MarkdownView.attributed(index < row.count ? row[index] : ""))
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: horizontalAlignment(index, alignments))
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func horizontalAlignment(_ index: Int, _ alignments: [TextAlignment]) -> Alignment {
        guard index < alignments.count else { return .leading }
        switch alignments[index] {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    // MARK: - Shared text helpers

    /// Converts `[[Wikilinks]]` / `[[Wikilinks|Alias]]` to standard markdown links pointing at
    /// the app's `limit://note/<name>` URL scheme (same scheme NoteView's backlinks and this
    /// file already use), then parses the result as inline markdown.
    static func attributed(_ raw: String) -> AttributedString {
        let converted = convertWikilinks(raw)
        if let attrStr = try? AttributedString(
            markdown: converted,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attrStr
        }
        return AttributedString(converted)
    }

    static func convertWikilinks(_ text: String) -> String {
        var processed = text
        let pattern = "\\[\\[(.*?)\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return processed }

        let nsrange = NSRange(processed.startIndex..<processed.endIndex, in: processed)
        let matches = regex.matches(in: processed, options: [], range: nsrange).reversed()

        for match in matches {
            if let range = Range(match.range(at: 0), in: processed),
               let nameRange = Range(match.range(at: 1), in: processed) {
                let linkContent = String(processed[nameRange])
                let target = linkContent.components(separatedBy: "|").first!.trimmingCharacters(in: .whitespaces)
                let alias = linkContent.components(separatedBy: "|").last!.trimmingCharacters(in: .whitespaces)

                let urlEncoded = target.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? target
                let markdownLink = "[\(alias)](limit://note/\(urlEncoded))"
                processed.replaceSubrange(range, with: markdownLink)
            }
        }
        return processed
    }

    // MARK: - Block parsing

    enum MarkdownBlock {
        case prose(String)
        case heading(level: Int, text: String)
        case code(language: String?, code: String)
        case table(header: [String], alignments: [TextAlignment], rows: [[String]])
    }

    /// Splits raw markdown into prose / heading / fenced-code / pipe-table blocks, in document
    /// order. Wikilink conversion and inline formatting are deliberately *not* applied here —
    /// that happens per-block at render time so code blocks stay verbatim.
    static func parseBlocks(_ content: String) -> [MarkdownBlock] {
        let lines = content.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var proseBuffer: [String] = []
        var i = 0

        func flushProse() {
            if !proseBuffer.isEmpty {
                blocks.append(.prose(proseBuffer.joined(separator: "\n")))
                proseBuffer = []
            }
        }

        while i < lines.count {
            let rawLine = lines[i]
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            // ATX heading: 1-6 `#` followed by a space, e.g. "## Progression". A bare "#..."
            // with no following space (or inside a fenced code block, handled above) isn't one.
            if let heading = parseHeading(trimmed) {
                flushProse()
                blocks.append(.heading(level: heading.level, text: heading.text))
                i += 1
                continue
            }

            // Fenced code block: ```language ... ```
            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 } // consume closing fence
                flushProse()
                blocks.append(.code(language: language.isEmpty ? nil : language, code: codeLines.joined(separator: "\n")))
                continue
            }

            // Pipe table: a `| a | b |` row immediately followed by a `| --- | --- |` separator.
            if isTableRow(trimmed), i + 1 < lines.count, isTableSeparator(lines[i + 1].trimmingCharacters(in: .whitespaces)) {
                let headerCells = splitRow(trimmed)
                let alignments = parseAlignments(lines[i + 1].trimmingCharacters(in: .whitespaces))
                i += 2
                var rows: [[String]] = []
                while i < lines.count, isTableRow(lines[i].trimmingCharacters(in: .whitespaces)) {
                    rows.append(splitRow(lines[i].trimmingCharacters(in: .whitespaces)))
                    i += 1
                }
                flushProse()
                blocks.append(.table(header: headerCells, alignments: alignments, rows: rows))
                continue
            }

            proseBuffer.append(rawLine)
            i += 1
        }
        flushProse()
        return blocks
    }

    private static func parseHeading(_ trimmedLine: String) -> (level: Int, text: String)? {
        guard trimmedLine.hasPrefix("#") else { return nil }
        let hashes = trimmedLine.prefix(while: { $0 == "#" })
        guard hashes.count >= 1, hashes.count <= 6 else { return nil }
        let rest = trimmedLine.dropFirst(hashes.count)
        guard rest.hasPrefix(" ") else { return nil } // "#tag" isn't a heading
        let text = rest.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (hashes.count, text)
    }

    private static func isTableRow(_ line: String) -> Bool {
        line.hasPrefix("|") && line.count > 1
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        guard line.hasPrefix("|") else { return false }
        let cells = splitRow(line)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            guard !c.isEmpty, c.contains("-") else { return false }
            return c.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func splitRow(_ line: String) -> [String] {
        var parts = line.components(separatedBy: "|")
        if parts.first == "" { parts.removeFirst() }
        if parts.last == "" { parts.removeLast() }
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func parseAlignments(_ line: String) -> [TextAlignment] {
        splitRow(line).map { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            let left = c.hasPrefix(":")
            let right = c.hasSuffix(":")
            if left && right { return .center }
            if right { return .trailing }
            return .leading
        }
    }
}
