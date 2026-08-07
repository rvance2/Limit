import SwiftUI

struct NoteView: View {
    let note: Note
    let manager: VaultManager
    
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Frontmatter header
                if !note.frontmatter.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(note.frontmatter.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            HStack(alignment: .top) {
                                Text(key.uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                Text(value)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                // Content
                MarkdownView(content: note.content)
                
                // Backlinks
                if let links = manager.backlinks[note.id], !links.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                            .padding(.vertical)
                        Text("Linked to this note")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ForEach(links, id: \.self) { link in
                            Button(action: {
                                if let url = URL(string: "limit://note/\(link.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? link)") {
                                    openURL(url)
                                }
                            }) {
                                Text(link)
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(note.title)
    }
}
