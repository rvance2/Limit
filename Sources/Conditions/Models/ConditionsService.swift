import Foundation

/// Open-Meteo dew-point fetch. Best-effort only — every call site treats a nil
/// result as "no forecast available, enter manually" with no error surfaced.
/// No API key, no account, nothing that leaves the device except a plain GET.
enum WeatherService {
    private struct OpenMeteoResponse: Decodable {
        struct Hourly: Decodable {
            let time: [String]
            let dewpoint_2m: [Double]
        }
        let hourly: Hourly
    }

    /// Returns nil on any failure — network unreachable, bad decode, no data for
    /// the current hour. Callers must not alarm the user; this is the offline path.
    static func fetchCurrentDewPointC(latitude: Double, longitude: Double) async -> Double? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "dewpoint_2m"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components?.url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            // Nearest hour to now, matched on the ISO-ish "yyyy-MM-ddTHH" prefix Open-Meteo returns.
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            let now = Date()
            var best: (Double, TimeInterval)?
            for (index, timeString) in decoded.hourly.time.enumerated() where index < decoded.hourly.dewpoint_2m.count {
                guard let date = formatter.date(from: timeString) else { continue }
                let delta = abs(date.timeIntervalSince(now))
                if best == nil || delta < best!.1 {
                    best = (decoded.hourly.dewpoint_2m[index], delta)
                }
            }
            return best?.0
        } catch {
            return nil
        }
    }
}

/// Conditions Forecasting logic (§6.7 / Conditions Forecasting.md). Everything
/// here reads thresholds out of SeedStore.shared.benchmarks.conditions rather
/// than re-deriving them, so the seed data stays the single source of truth.
enum ConditionsLogic {
    /// Rule 1, hard: rock temperature must exceed dew point or the hold is wet
    /// regardless of what the dew-point verdict table says.
    static func isWet(rockTempC: Double, dewPointC: Double) -> Bool {
        rockTempC <= dewPointC
    }

    /// Consults SeedStore's benchmark table — never reimplements the thresholds.
    /// If the rock is wet (rule 1), the verdict is overridden to "Wet — rock temp
    /// at or below dew point" regardless of what the table says (rule 2's ~15-16°C
    /// poor bucket is already the table's top row, so no separate check is needed).
    static func dewPointVerdict(dewPointC: Double, rockTempC: Double?) -> String {
        if let rockTempC, isWet(rockTempC: rockTempC, dewPointC: dewPointC) {
            return "Wet, rock temp at or below dew point"
        }
        guard let rows = SeedStore.shared.benchmarks?.conditions.rows else { return "Unknown" }
        if let row = rows.first(where: { row in
            guard row.range.count == 2 else { return false }
            return dewPointC >= row.range[0] && dewPointC < row.range[1]
        }) {
            return row.verdict
        }
        return "Unknown"
    }

    enum Spread: String {
        case drying = "Drying"
        case nearCondensing = "Near condensing"
        case neutral = "Neutral"
    }

    static func spread(rockTempC: Double, dewPointC: Double) -> (value: Double, description: Spread) {
        let rules = SeedStore.shared.benchmarks?.conditions.spreadRules
        let value = rockTempC - dewPointC
        guard let rules else { return (value, .neutral) }
        if value > rules.dryingAboveC {
            return (value, .drying)
        } else if value < rules.nearCondensingBelowC {
            return (value, .nearCondensing)
        }
        return (value, .neutral)
    }

    static func isReadinessBad(_ verdict: String?) -> Bool {
        guard let verdict else { return false }
        return verdict.contains("Rest") || verdict.contains("Skill and mobility only")
    }
}

/// Go/no-go, five inputs, three-of-five-bad recommends training instead.
/// This is a recommendation, not a hard verdict — ConditionsView must render
/// the five inputs and their individual bad/ok state, not a pass/fail badge.
struct GoNoGoInput: Identifiable {
    let id: String
    let label: String
    let detail: String
    let isBad: Bool
}

enum GoNoGoEvaluator {
    static func evaluate(
        dewPointC: Double?,
        rockTempC: Double?,
        windIsFavorable: Bool?,
        skinScore: Int?,
        readinessVerdict: String?
    ) -> (inputs: [GoNoGoInput], badCount: Int, recommendation: String) {
        var inputs: [GoNoGoInput] = []

        if let dewPointC {
            let verdict = ConditionsLogic.dewPointVerdict(dewPointC: dewPointC, rockTempC: rockTempC)
            let bad = dewPointC >= 10 || verdict.hasPrefix("Wet")
            inputs.append(GoNoGoInput(id: "dewPoint", label: "Dew point", detail: "\(dewPointC.formatted(.number.precision(.fractionLength(1))))°C, \(verdict)", isBad: bad))
        } else {
            inputs.append(GoNoGoInput(id: "dewPoint", label: "Dew point", detail: "Not entered", isBad: true))
        }

        if let rockTempC, let dewPointC {
            let wet = ConditionsLogic.isWet(rockTempC: rockTempC, dewPointC: dewPointC)
            inputs.append(GoNoGoInput(id: "rockTempAndAspect", label: "Rock temp and aspect", detail: wet ? "Wet, at or below dew point" : "\(rockTempC.formatted(.number.precision(.fractionLength(1))))°C, dry", isBad: wet))
        } else {
            inputs.append(GoNoGoInput(id: "rockTempAndAspect", label: "Rock temp and aspect", detail: "Not entered", isBad: true))
        }

        if let windIsFavorable {
            inputs.append(GoNoGoInput(id: "wind", label: "Wind", detail: windIsFavorable ? "Working for me" : "Not helping (none, or too strong to feel the crimp)", isBad: !windIsFavorable))
        } else {
            inputs.append(GoNoGoInput(id: "wind", label: "Wind", detail: "Not entered", isBad: true))
        }

        if let skinScore {
            inputs.append(GoNoGoInput(id: "skinScore", label: "Skin score", detail: "\(skinScore)/5", isBad: skinScore <= 2))
        } else {
            inputs.append(GoNoGoInput(id: "skinScore", label: "Skin score", detail: "Not logged today", isBad: true))
        }

        let readinessBad = ConditionsLogic.isReadinessBad(readinessVerdict)
        inputs.append(GoNoGoInput(id: "readinessVerdict", label: "Readiness", detail: readinessVerdict ?? "Not logged today", isBad: readinessVerdict == nil ? true : readinessBad))

        let badCount = inputs.filter { $0.isBad }.count
        let threshold = SeedStore.shared.benchmarks?.conditions.goNoGo.badThreshold ?? 3
        let recommendation = badCount >= threshold
            ? "\(badCount) of \(inputs.count) bad. Train instead, go tomorrow."
            : "\(badCount) of \(inputs.count) bad. Go."

        return (inputs, badCount, recommendation)
    }
}
