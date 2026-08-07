import Foundation

/// "Primary finger method" (S1 item 3) has `moduleId: null` in sessions.json — which module
/// actually applies is spelled out in its `variation` text instead: "B1: Max Hangs MAW 20mm ·
/// B2: MED Hangs · B3: Max Hangs + Grip Specificity Block · B4: Max Hangs 3 sets only". Shared
/// so Today, the session runner, and the Plan day detail all resolve and label it the same way
/// instead of showing the generic placeholder name.
enum FingerMethodResolver {
    static func moduleID(forItemName name: String, blockNumber: Int?) -> String? {
        guard name == "Primary finger method" else { return nil }
        switch blockNumber {
        case 2: return "MED Hangs"
        default: return "Max Hangs" // Blocks 1, 3, 4 all lead with Max Hangs per the variation text.
        }
    }

    /// "Primary finger method — Max Hangs" instead of the bare placeholder, so it's clear at a
    /// glance where hangs get logged without having to read the variation text.
    static func displayName(itemName: String, blockNumber: Int?) -> String {
        guard let resolved = moduleID(forItemName: itemName, blockNumber: blockNumber) else { return itemName }
        return "\(itemName): \(resolved)"
    }
}
