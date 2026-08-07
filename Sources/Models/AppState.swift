import Foundation
import SwiftData

@Model
final class AppState {
    var startDate: Date
    // Saved crag location for the optional Conditions weather lookup (§6.7).
    var cragName: String?
    var cragLatitude: Double?
    var cragLongitude: Double?

    init(startDate: Date = .now) {
        self.startDate = startDate
    }

    /// Week 0 of the plan starts Monday, August 10, 2026.
    static var planStartDate: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 10
        return Calendar.current.date(from: components) ?? .now
    }
}
