import SwiftUI
import SwiftData

// Standalone Beta Lab entry point. Expected to be linked from: Today (project
// session) and Plan (Blocks 2-4, "within project sessions"). Parameterless.
struct BetaLabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var showingNewProject = false
    @State private var newName = ""
    @State private var newGrade = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("A procedure for not committing to the sequence I invented while I knew least about the boulder. Session 1 on any new project: no full attempts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(projects) { project in
                    NavigationLink {
                        ProjectDetailView(project: project)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(project.name).font(.headline)
                                Spacer()
                                Text(project.grade).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 8) {
                                if let rock = project.rock {
                                    Text(rock)
                                }
                                if let aspect = project.aspect {
                                    Text(aspect)
                                }
                                if let committed = project.sessionsCommitted {
                                    Text("Session \(project.sessionsUsed)/\(committed)")
                                } else {
                                    Text("\(project.sessionsUsed) sessions")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteProjects)
            }
            .navigationTitle("Beta Lab")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewProject) {
                NavigationStack {
                    Form {
                        TextField("Name", text: $newName)
                        TextField("Grade", text: $newGrade)
                    }
                    .navigationTitle("New project")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") { addProject() }
                                .disabled(newName.isEmpty || newGrade.isEmpty)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingNewProject = false }
                        }
                    }
                }
            }
        }
    }

    private func addProject() {
        let project = Project(name: newName, grade: newGrade)
        modelContext.insert(project)
        try? modelContext.save()
        newName = ""
        newGrade = ""
        showingNewProject = false
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(projects[index])
        }
        try? modelContext.save()
    }
}

#Preview {
    BetaLabView()
        .modelContainer(for: [Project.self], inMemory: true)
}
