import SwiftUI
import SwiftData

/// Lets the plan start date move. Everything else (week number, block, which session runs on
/// which day) is already computed from `AppState.startDate` at read time via `SessionScheduler`,
/// so changing it here is the only piece of state that needs to move.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var appState: AppState

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { appState.startDate },
            set: { newValue in
                appState.startDate = Self.mondayOfWeek(containing: newValue)
                try? modelContext.save()
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Plan start date", selection: startDateBinding, displayedComponents: .date)
                    Text("Week 0 begins the Monday of whatever week I pick. Changing this recalculates which week, block, and session applies to every day, past and future.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Plan")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    static func mondayOfWeek(containing date: Date) -> Date {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date) // 1=Sun...7=Sat
        let daysFromMonday = (weekday + 5) % 7 // Mon=0, Tue=1, ... Sun=6
        return cal.date(byAdding: .day, value: -daysFromMonday, to: cal.startOfDay(for: date)) ?? date
    }
}
