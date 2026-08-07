import SwiftUI
import SwiftData
import PhotosUI

struct ProjectDetailView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext

    @State private var newSequence = ""
    @State private var newVector = ""
    @State private var mediaPicker: PhotosPickerItem?

    // From Beta Lab.md — the five standard vector experiments to run before
    // concluding a move needs more strength, not the wrong angle.
    private let standardVectors = [
        "Hip rotation",
        "Shoulder drop",
        "Foot swap",
        "Foot 2 cm adjustment",
        "Weighting order",
    ]

    var body: some View {
        Form {
            Section("Project") {
                TextField("Name", text: $project.name)
                TextField("Grade", text: $project.grade)
                TextField("Rock", text: Binding(get: { project.rock ?? "" }, set: { project.rock = $0.isEmpty ? nil : $0 }))
                TextField("Aspect", text: Binding(get: { project.aspect ?? "" }, set: { project.aspect = $0.isEmpty ? nil : $0 }))
                TextField("Approach notes", text: Binding(get: { project.approachNotes ?? "" }, set: { project.approachNotes = $0.isEmpty ? nil : $0 }), axis: .vertical)
            }

            Section {
                Stepper("Sessions committed: \(project.sessionsCommitted.map(String.init) ?? "not set")", value: Binding(
                    get: { project.sessionsCommitted ?? 3 },
                    set: { project.sessionsCommitted = $0 }
                ), in: 1...10)
                Stepper("Sessions used: \(project.sessionsUsed)", value: $project.sessionsUsed, in: 0...50)
            } footer: {
                Text("Choose one sequence and give it three sessions. Don't re-open the question inside those three.")
            }

            Section {
                Text("Session 1 on any new project: no full attempts. Work the boulder in sections, top down. Per crux, write three sequences before trying any properly, one assuming a shorter body, one assuming more flexibility. Try each at least twice, score possible / possible on a good day / not possible.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Protocol")
            }

            Section("Beta sequences") {
                ForEach(Array(project.betaSequences.enumerated()), id: \.offset) { index, sequence in
                    TextField("Sequence", text: Binding(
                        get: { project.betaSequences[index] },
                        set: { project.betaSequences[index] = $0 }
                    ))
                }
                .onDelete { offsets in
                    project.betaSequences.remove(atOffsets: offsets)
                }
                HStack {
                    TextField("New sequence, words not memory", text: $newSequence)
                    Button {
                        guard !newSequence.isEmpty else { return }
                        project.betaSequences.append(newSequence)
                        newSequence = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }

            Section {
                ForEach(Array(project.vectorExperimentsTried.enumerated()), id: \.offset) { index, vector in
                    TextField("Vector", text: Binding(
                        get: { project.vectorExperimentsTried[index] },
                        set: { project.vectorExperimentsTried[index] = $0 }
                    ))
                }
                .onDelete { offsets in
                    project.vectorExperimentsTried.remove(atOffsets: offsets)
                }
                HStack {
                    TextField("New vector experiment", text: $newVector)
                    Button {
                        guard !newVector.isEmpty else { return }
                        project.vectorExperimentsTried.append(newVector)
                        newVector = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                ForEach(standardVectors.filter { !project.vectorExperimentsTried.contains($0) }, id: \.self) { vector in
                    Button {
                        project.vectorExperimentsTried.append(vector)
                    } label: {
                        Label("Add \"\(vector)\"", systemImage: "plus")
                    }
                    .font(.caption)
                }
            } header: {
                Text("Vector experiments tried")
            } footer: {
                Text("Before concluding a move needs more strength, run these. Most \"too hard\" moves were the wrong angle.")
            }

            Section {
                ForEach(project.mediaRefs, id: \.self) { ref in
                    Text(ref.components(separatedBy: "/").last ?? ref)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onDelete { offsets in
                    project.mediaRefs.remove(atOffsets: offsets)
                }
                PhotosPicker(selection: $mediaPicker, matching: .any(of: [.videos, .images])) {
                    Label("Attach photo or clip", systemImage: "camera.badge.plus")
                }
            } header: {
                Text("Media")
            } footer: {
                Text("Two angles if possible, side-on and three-quarter. Side-on shows the hip path. Watch it that evening, not at the crag.")
            }
        }
        .navigationTitle(project.name)
        .onChange(of: mediaPicker) { _, newItem in
            guard let newItem else { return }
            Task {
                if let picked = try? await newItem.loadTransferable(type: PickedMediaFile.self) {
                    await MainActor.run {
                        project.mediaRefs.append(picked.relativeRef)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProjectDetailView(project: Project(name: "Sample", grade: "V7"))
            .modelContainer(for: [Project.self], inMemory: true)
    }
}
