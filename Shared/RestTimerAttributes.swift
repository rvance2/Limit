import Foundation
import ActivityKit

public struct RestTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var endTime: Date
    }
    
    public var duration: Int // minutes
    public init(duration: Int) {
        self.duration = duration
    }
}
