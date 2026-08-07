import SwiftUI

// MARK: - Navigation route (pushed from LibraryView's NavigationPath)

enum GraphDestination: Hashable {
    case graph
}

// MARK: - Layout model

/// A static, one-shot layout — computed once and never animated. An earlier version ran a
/// continuous force-directed physics simulation every frame; with 99 nodes packed close
/// together at the start it never settled cleanly and visibly jittered. This instead clusters
/// notes by their primary tag (the same categories the legend already shows) and arranges each
/// cluster in its own sector of the canvas, so related notes sit together without any runtime
/// simulation. No third-party graph library — first-party only, per the project's constraint.
/// "Doesn't need to be beautiful, needs to be navigable."
@Observable
final class GraphLayout {
    struct Node {
        let id: String
        var position: CGPoint
        let tags: [String]
    }

    private(set) var nodes: [String: Node] = [:]
    private(set) var order: [String] = []
    private(set) var edges: [(String, String)] = []
    private(set) var isBuilt = false

    /// Clusters nodes by primary tag around a ring of sector centers, then arranges each
    /// cluster's own notes on a small circle inside its sector. Deterministic — same vault,
    /// same layout, every launch. Also computes the (deduped, undirected) edge list from each
    /// note's forward `links`; only notes that resolve to a loaded note become edges.
    func build(from manager: VaultManager, canvasSize: CGSize) {
        guard !isBuilt else { return }
        isBuilt = true

        let allIDs = manager.notes.keys.sorted()
        order = allIDs

        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let clusterOrbitRadius = min(canvasSize.width, canvasSize.height) * 0.32

        var byCategory: [String: [String]] = [:]
        for id in allIDs {
            let category = manager.notes[id]?.tags.first ?? "other"
            byCategory[category, default: []].append(id)
        }
        let categories = GraphTagStyle.legend.map(\.label) + byCategory.keys.filter { key in
            !GraphTagStyle.legend.contains { $0.label == key }
        }.sorted()
        let presentCategories = categories.filter { byCategory[$0]?.isEmpty == false }

        for (categoryIndex, category) in presentCategories.enumerated() {
            let ids = (byCategory[category] ?? []).sorted()
            let sectorAngle = 2 * Double.pi * Double(categoryIndex) / Double(max(presentCategories.count, 1))
            let sectorCenter = CGPoint(
                x: center.x + clusterOrbitRadius * CGFloat(cos(sectorAngle)),
                y: center.y + clusterOrbitRadius * CGFloat(sin(sectorAngle))
            )
            // Cluster radius grows with the square root of member count, so a 30-note cluster
            // (Modules) doesn't overlap a 1-note cluster (Constraints) as densely.
            let clusterRadius = 24 + 9 * CGFloat(Double(ids.count).squareRoot())
            for (nodeIndex, id) in ids.enumerated() {
                if ids.count == 1 {
                    nodes[id] = Node(id: id, position: sectorCenter, tags: manager.notes[id]?.tags ?? [])
                    continue
                }
                let nodeAngle = 2 * Double.pi * Double(nodeIndex) / Double(ids.count)
                let position = CGPoint(
                    x: sectorCenter.x + clusterRadius * CGFloat(cos(nodeAngle)),
                    y: sectorCenter.y + clusterRadius * CGFloat(sin(nodeAngle))
                )
                nodes[id] = Node(id: id, position: position, tags: manager.notes[id]?.tags ?? [])
            }
        }

        var seenPairs = Set<String>()
        for id in allIDs {
            guard let note = manager.notes[id] else { continue }
            for target in note.links where target != id {
                guard manager.notes[target] != nil else { continue }
                let key = [id, target].sorted().joined(separator: "|||")
                if seenPairs.insert(key).inserted {
                    edges.append((id, target))
                }
            }
        }
    }
}

// MARK: - Tag coloring

enum GraphTagStyle {
    /// Primary category is always the first tag in the frontmatter `tags` array
    /// (factor / module / plan / hub / testing / constraint).
    static func color(forTags tags: [String]) -> Color {
        switch tags.first {
        case "factor": return .blue
        case "module": return .green
        case "plan": return .purple
        case "hub": return .yellow
        case "testing": return .red
        case "constraint": return .pink
        default: return .gray
        }
    }

    static let legend: [(label: String, color: Color)] = [
        ("factor", .blue),
        ("module", .green),
        ("plan", .purple),
        ("hub", .yellow),
        ("testing", .red),
        ("constraint", .pink)
    ]
}

// MARK: - GraphView

/// Static clustered map of all 99 vault notes. Not meant to be beautiful — meant to be
/// navigable: pinch to zoom, drag to pan, tap a node to open the note. The layout is computed
/// once (see `GraphLayout.build`) and never animates.
struct GraphView: View {
    @State private var manager = VaultManager()
    @State private var layout = GraphLayout()
    @State private var canvasSize: CGSize = CGSize(width: 900, height: 900)

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @Environment(\.openURL) private var openURL

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                drawEdges(in: context)
                drawNodes(in: context)
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .contentShape(Rectangle())
            // Gestures live on this transformed view itself (not an outer container) so
            // `.local` gesture coordinates come back pre-scale/pre-offset — i.e. already in
            // the same world space the node positions are computed in. Tapping and panning
            // both stay accurate at any zoom level as long as the touch lands within the
            // (possibly off-screen-extending, once zoomed in) canvas bounds.
            .gesture(dragGesture)
            .gesture(magnifyGesture)
            .scaleEffect(scale)
            .offset(offset)
            .onChange(of: geo.size, initial: true) { _, newSize in
                if !layout.isBuilt {
                    canvasSize = CGSize(width: max(newSize.width, 400), height: max(newSize.height, 400))
                    layout.build(from: manager, canvasSize: canvasSize)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .clipped()
        .overlay(alignment: .bottomLeading) {
            legendView
        }
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
            } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title2)
            }
            .padding()
        }
        .navigationTitle("Graph")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Drawing

    private func drawEdges(in context: GraphicsContext) {
        var path = Path()
        for (a, b) in layout.edges {
            guard let pa = layout.nodes[a]?.position, let pb = layout.nodes[b]?.position else { continue }
            path.move(to: pa)
            path.addLine(to: pb)
        }
        context.stroke(path, with: .color(.secondary.opacity(0.18)), lineWidth: 0.6)
    }

    private func drawNodes(in context: GraphicsContext) {
        for id in layout.order {
            guard let node = layout.nodes[id] else { continue }
            let color = GraphTagStyle.color(forTags: node.tags)
            let radius: CGFloat = 6
            let rect = CGRect(x: node.position.x - radius, y: node.position.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color))
            context.stroke(Path(ellipseIn: rect), with: .color(color.opacity(0.6)), lineWidth: 1)

            let label = Text(shortLabel(id))
                .font(.system(size: 6.5))
                .foregroundColor(.primary)
            context.draw(label, at: CGPoint(x: node.position.x, y: node.position.y + radius + 6), anchor: .top)
        }
    }

    private func shortLabel(_ title: String) -> String {
        title.count > 18 ? String(title.prefix(17)) + "…" : title
    }

    // MARK: Gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                if abs(value.translation.width) < 2 && abs(value.translation.height) < 2 {
                    handleTap(at: value.location)
                }
                lastOffset = offset
            }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 0.2), 4.0)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private func handleTap(at point: CGPoint) {
        // `point` arrives in the gesture's local coordinate space, which — because the
        // gesture is attached to the same view the scaleEffect/offset are applied to — is
        // already in the canvas's untransformed world space, matching node positions.
        let hitRadius: CGFloat = 18
        var best: (id: String, dist: CGFloat)?
        for id in layout.order {
            guard let pos = layout.nodes[id]?.position else { continue }
            let dx = pos.x - point.x
            let dy = pos.y - point.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < hitRadius, best == nil || dist < best!.dist {
                best = (id, dist)
            }
        }
        if let id = best?.id {
            openNote(id)
        }
    }

    private func openNote(_ id: String) {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        if let url = URL(string: "limit://note/\(encoded)") {
            openURL(url)
        }
    }

    private var legendView: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(GraphTagStyle.legend, id: \.label) { entry in
                HStack(spacing: 6) {
                    Circle().fill(entry.color).frame(width: 8, height: 8)
                    Text(entry.label).font(.caption2)
                }
            }
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding()
    }
}
