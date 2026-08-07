import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Local file storage for media picked via PhotosPicker (test battery benchmark
/// videos, Beta Lab media refs). Copies the picked file into
/// Documents/LocalMedia/<uuid>.<ext> and hands back a relative path string —
/// that relative path is what gets stored in TestResult.mediaRef / Project.mediaRefs.
/// Nothing here touches network or cloud; it's a same-device file reference.
enum MediaFileStore {
    static var mediaDirectory: URL {
        let dir = URL.documentsDirectory.appending(path: "LocalMedia", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Resolve a stored relative reference (e.g. "LocalMedia/xyz.mov") to a full file URL.
    static func resolve(_ ref: String?) -> URL? {
        guard let ref, !ref.isEmpty else { return nil }
        let url = URL.documentsDirectory.appending(path: ref)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

/// Transferable wrapper so PhotosPicker can hand us a video or photo without
/// loading the whole thing into memory — it copies the file straight into
/// local storage and reports back the relative ref to save on the model.
struct PickedMediaFile: Transferable {
    let relativeRef: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            try Self.importFile(received.file)
        }
        FileRepresentation(importedContentType: .image) { received in
            try Self.importFile(received.file)
        }
    }

    private static func importFile(_ received: URL) throws -> PickedMediaFile {
        let ext = received.pathExtension.isEmpty ? "mov" : received.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let dest = MediaFileStore.mediaDirectory.appending(path: filename)
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: received, to: dest)
        return PickedMediaFile(relativeRef: "LocalMedia/\(filename)")
    }
}
