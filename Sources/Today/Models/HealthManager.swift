import Foundation
import HealthKit
import SwiftUI

@Observable
final class HealthManager {
    private let store = HKHealthStore()
    
    var hrvBaseline: Double?
    var latestHRV: Double?
    var rhrBaseline: Double?
    var latestRHR: Double?
    var latestSleepHours: Double?
    
    var hrvDataCount: Int = 0
    var rhrDataCount: Int = 0
    
    var isAuthorized: Bool = false
    
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        do {
            try await store.requestAuthorization(toShare: [], read: [hrvType, rhrType, sleepType])
            isAuthorized = true
            await fetchData()
        } catch {
            print("HealthKit authorization failed: \(error)")
        }
    }
    
    func fetchData() async {
        guard isAuthorized else { return }
        
        async let fetchedHRV = fetchHRV()
        async let fetchedRHR = fetchRHR()
        async let fetchedSleep = fetchSleep()
        
        let (hrv, rhr, sleep) = await (fetchedHRV, fetchedRHR, fetchedSleep)
        
        DispatchQueue.main.async {
            self.hrvBaseline = hrv.baseline
            self.latestHRV = hrv.latest
            self.hrvDataCount = hrv.count
            
            self.rhrBaseline = rhr.baseline
            self.latestRHR = rhr.latest
            self.rhrDataCount = rhr.count
            
            self.latestSleepHours = sleep
        }
    }
    
    private func fetchHRV() async -> (baseline: Double?, latest: Double?, count: Int) {
        let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        return await fetchBaselineAndLatest(for: type, unit: HKUnit.secondUnit(with: .milli))
    }
    
    private func fetchRHR() async -> (baseline: Double?, latest: Double?, count: Int) {
        let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        return await fetchBaselineAndLatest(for: type, unit: HKUnit.count().unitDivided(by: .minute()))
    }
    
    private func fetchBaselineAndLatest(for type: HKQuantityType, unit: HKUnit) async -> (baseline: Double?, latest: Double?, count: Int) {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -14, to: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                guard let quantities = samples as? [HKQuantitySample], !quantities.isEmpty else {
                    continuation.resume(returning: (nil, nil, 0))
                    return
                }
                
                // Group by day to find daily averages
                var dailyValues: [Date: [Double]] = [:]
                for sample in quantities {
                    let day = calendar.startOfDay(for: sample.endDate)
                    let val = sample.quantity.doubleValue(for: unit)
                    dailyValues[day, default: []].append(val)
                }
                
                let today = calendar.startOfDay(for: now)
                var latest: Double? = nil
                
                // If there's a value for today, that's the latest.
                if let todayVals = dailyValues[today], !todayVals.isEmpty {
                    latest = todayVals.reduce(0, +) / Double(todayVals.count)
                } else if let yesterdayVals = dailyValues[calendar.date(byAdding: .day, value: -1, to: today)!], !yesterdayVals.isEmpty {
                    // Fallback to yesterday if today hasn't recorded yet
                    latest = yesterdayVals.reduce(0, +) / Double(yesterdayVals.count)
                } else if let mostRecentDay = dailyValues.keys.max(), let vals = dailyValues[mostRecentDay] {
                    latest = vals.reduce(0, +) / Double(vals.count)
                }
                
                // Baseline is the average of the daily averages over the last 14 days
                let allAverages = dailyValues.values.map { $0.reduce(0, +) / Double($0.count) }
                let baseline = allAverages.reduce(0, +) / Double(allAverages.count)
                
                continuation.resume(returning: (baseline, latest, dailyValues.keys.count))
            }
            store.execute(query)
        }
    }
    
    private func fetchSleep() async -> Double? {
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.current
        let now = Date()
        // Look at the past 24 hours
        let start = calendar.date(byAdding: .hour, value: -24, to: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictEndDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Filter for "asleep" states
                let asleepSamples = categorySamples.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                }
                
                let totalDuration = asleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalDuration / 3600.0) // hours
            }
            store.execute(query)
        }
    }
}
