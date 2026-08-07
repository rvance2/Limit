import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasSeenDisclaimer") private var hasSeenDisclaimer = false

    var body: some View {
        TabView {
            TodayView()
            .tabItem {
                Label("Today", systemImage: "sun.max")
            }

            PlanView()
            .tabItem {
                Label("Plan", systemImage: "calendar")
            }

            LogTabView()
            .tabItem {
                Label("Log", systemImage: "pencil.and.list.clipboard")
            }

            ChartsTabView()
            .tabItem {
                Label("Charts", systemImage: "chart.xyaxis.line")
            }

            LibraryView()
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }
        }
        .fullScreenCover(isPresented: .constant(!hasSeenDisclaimer)) {
            DisclaimerView { hasSeenDisclaimer = true }
        }
    }
}
