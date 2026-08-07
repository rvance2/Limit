import SwiftUI

enum LibraryDestination: Hashable {
    case export
}

struct FolderDestination: Hashable {
    /// Full path from the vault root, e.g. "01 Factors" or "01 Factors/Skill". Empty string
    /// is the root notes (00 START HERE, How To Use This Vault, Sources).
    let path: String
}

struct LibraryView: View {
    @State private var manager = VaultManager()
    @State private var searchText = ""
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if searchText.isEmpty {
                    FolderListView(path: "", manager: manager)
                } else {
                    List {
                        ForEach(manager.search(query: searchText)) { note in
                            NavigationLink(value: note) {
                                VStack(alignment: .leading) {
                                    Text(note.title)
                                        .font(.headline)
                                    Text(note.folder.isEmpty ? "Start" : note.folder)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search notes")
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(value: GraphDestination.graph) {
                        Image(systemName: "circle.grid.cross")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(value: LibraryDestination.export) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .navigationDestination(for: Note.self) { note in
                NoteView(note: note, manager: manager)
            }
            .navigationDestination(for: GraphDestination.self) { _ in
                GraphView()
            }
            .navigationDestination(for: LibraryDestination.self) { _ in
                ExportView()
            }
            .navigationDestination(for: FolderDestination.self) { dest in
                FolderListView(path: dest.path, manager: manager)
            }
            .onOpenURL { url in
                if url.scheme == "limit", url.host == "note" {
                    let noteId = url.lastPathComponent.removingPercentEncoding ?? ""
                    if let targetNote = manager.notes[noteId] {
                        path.append(targetNote)
                    }
                }
            }
        }
    }
}

/// One level of the vault's folder tree: subfolders first, then notes that live directly in
/// this folder (not in a deeper subfolder). Root (`path == ""`) is the 99-note vault's actual
/// top-level layout — 01 Factors, 02 Plan, 03 Modules, 04 Testing, 05 Constraints, plus the
/// three root notes (00 START HERE, How To Use This Vault, Sources) — instead of one long list.
struct FolderListView: View {
    let path: String
    let manager: VaultManager

    private var prefix: String { path.isEmpty ? "" : path + "/" }

    private var childFolders: [String] {
        let names: Set<String> = Set(manager.notes.values.compactMap { note -> String? in
            guard note.folder.hasPrefix(prefix), note.folder != path else { return nil }
            let remainder = note.folder.dropFirst(prefix.count)
            guard let first = remainder.split(separator: "/").first else { return nil }
            return prefix + first
        })
        return names.sorted()
    }

    private var directNotes: [Note] {
        manager.notes.values
            .filter { $0.folder == path }
            .sorted { $0.title < $1.title }
    }

    private func label(_ folderPath: String) -> String {
        String(folderPath.split(separator: "/").last ?? Substring(folderPath))
    }

    var body: some View {
        List {
            if !childFolders.isEmpty {
                Section {
                    ForEach(childFolders, id: \.self) { folder in
                        NavigationLink(value: FolderDestination(path: folder)) {
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundColor(.accentColor)
                                Text(label(folder))
                                Spacer()
                                Text("\(noteCount(under: folder))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            if !directNotes.isEmpty {
                Section(childFolders.isEmpty ? "" : "Notes") {
                    ForEach(directNotes) { note in
                        NavigationLink(value: note) {
                            Text(note.title)
                        }
                    }
                }
            }
        }
        .navigationTitle(path.isEmpty ? "Library" : label(path))
        .navigationBarTitleDisplayMode(path.isEmpty ? .large : .inline)
    }

    private func noteCount(under folder: String) -> Int {
        let p = folder + "/"
        return manager.notes.values.filter { $0.folder == folder || $0.folder.hasPrefix(p) }.count
    }
}
