import Foundation

struct ReadinessResult {
    let flagCount: Int
    let verdict: String
    let activeFlags: [String]
    let isDegraded: Bool
}

class ReadinessManager {
    static func evaluate(
        hrvLatest: Double?, hrvBaseline: Double?, hrvDays: Int,
        rhrLatest: Double?, rhrBaseline: Double?,
        sleepHours: Double?,
        motivation: Int?,
        fingerStiff: Bool?
    ) -> ReadinessResult {
        
        var flags: [String] = []
        var hrvAvailable = false
        
        // 1. HRV
        if let latest = hrvLatest, let baseline = hrvBaseline, hrvDays >= 7 {
            hrvAvailable = true
            // HRV more than ~10% below baseline
            if latest < (baseline * 0.9) {
                flags.append("HRV >10% below baseline")
            }
        }
        
        // 2. Sleep
        if let sleep = sleepHours {
            if sleep < 7.0 {
                flags.append("Sleep under 7 hours")
            }
        }
        
        // 3. Resting HR
        if let latest = rhrLatest, let baseline = rhrBaseline {
            if latest > (baseline + 5.0) {
                flags.append("RHR >5 bpm above baseline")
            }
        }
        
        // 4. Motivation
        if let mot = motivation {
            if mot <= 2 {
                flags.append("Motivation flat (≤2)")
            }
        }
        
        // 5. Finger Stiff
        if let stiff = fingerStiff, stiff {
            flags.append("Finger stiff on waking")
        }
        
        let count = flags.count
        let verdict: String
        
        if hrvAvailable {
            switch count {
            case 0...1: verdict = "As prescribed"
            case 2: verdict = "Downgrade: keep the session, cut top-end intensity 10-15%, drop the last set of everything"
            case 3: verdict = "Skill and mobility only: Movement Efficiency Drills, Footwork Precision, Hip and Ankle Mobility"
            default: verdict = "Rest: Visualization Protocol and Shoulder Protocol only"
            }
        } else {
            // Degraded 4-flag scale
            switch count {
            case 0...1: verdict = "As prescribed"
            case 2: verdict = "Downgrade: keep the session, cut top-end intensity 10-15%, drop the last set of everything"
            case 3: verdict = "Skill and mobility only: Movement Efficiency Drills, Footwork Precision, Hip and Ankle Mobility"
            default: verdict = "Rest: Visualization Protocol and Shoulder Protocol only" // 4 flags
            }
        }
        
        return ReadinessResult(flagCount: count, verdict: verdict, activeFlags: flags, isDegraded: !hrvAvailable)
    }
}
