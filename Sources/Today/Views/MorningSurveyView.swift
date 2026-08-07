import SwiftUI
import SwiftData

struct MorningSurveyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var healthManager = HealthManager()
    
    @State private var motivation = 3
    @State private var fingerStiff = false
    @State private var stiffWhichFinger = ""
    @State private var skinScore = 3
    @State private var antihydralApplied = false
    
    // Manual fallbacks
    @State private var manualHRV: String = ""
    @State private var manualRHR: String = ""
    @State private var manualSleep: String = ""
    
    let onComplete: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Subjective")) {
                    Picker("Motivation (1-5)", selection: $motivation) {
                        ForEach(1...5, id: \.self) { val in
                            Text("\(val)").tag(val)
                        }
                    }
                    
                    Toggle("Finger stiff on waking?", isOn: $fingerStiff)
                    if fingerStiff {
                        TextField("Which finger?", text: $stiffWhichFinger)
                    }
                }
                
                Section(header: Text("Skin")) {
                    Picker("Skin Score (1-5)", selection: $skinScore) {
                        ForEach(1...5, id: \.self) { val in
                            Text("\(val)").tag(val)
                        }
                    }
                    Toggle("Antihydral applied last night?", isOn: $antihydralApplied)
                }
                
                Section(header: Text("Health Data (14-day baseline)")) {
                    if healthManager.isAuthorized && (healthManager.latestHRV != nil || healthManager.latestRHR != nil || healthManager.latestSleepHours != nil) {
                        if let hrv = healthManager.latestHRV, let base = healthManager.hrvBaseline {
                            HStack {
                                Text("HRV")
                                Spacer()
                                Text("\(Int(hrv)) ms (Base: \(Int(base)))")
                            }
                        } else {
                            TextField("Manual HRV (ms)", text: $manualHRV)
                                .keyboardType(.numberPad)
                        }
                        
                        if let rhr = healthManager.latestRHR, let base = healthManager.rhrBaseline {
                            HStack {
                                Text("Resting HR")
                                Spacer()
                                Text("\(Int(rhr)) bpm (Base: \(Int(base)))")
                            }
                        } else {
                            TextField("Manual Resting HR (bpm)", text: $manualRHR)
                                .keyboardType(.numberPad)
                        }
                        
                        if let sleep = healthManager.latestSleepHours {
                            HStack {
                                Text("Sleep")
                                Spacer()
                                Text(String(format: "%.1f hrs", sleep))
                            }
                        } else {
                            TextField("Manual Sleep (hrs)", text: $manualSleep)
                                .keyboardType(.decimalPad)
                        }
                    } else {
                        // Fallback completely
                        TextField("Manual HRV (ms)", text: $manualHRV).keyboardType(.numberPad)
                        TextField("Manual Resting HR (bpm)", text: $manualRHR).keyboardType(.numberPad)
                        TextField("Manual Sleep (hrs)", text: $manualSleep).keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Morning Survey")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await healthManager.requestAuthorization()
            }
        }
    }
    
    private func save() {
        let hrv = healthManager.latestHRV ?? Double(manualHRV)
        let rhr = healthManager.latestRHR ?? Double(manualRHR)
        let sleep = healthManager.latestSleepHours ?? Double(manualSleep)
        
        let result = ReadinessManager.evaluate(
            hrvLatest: hrv,
            hrvBaseline: healthManager.hrvBaseline,
            hrvDays: healthManager.hrvDataCount,
            rhrLatest: rhr,
            rhrBaseline: healthManager.rhrBaseline,
            sleepHours: sleep,
            motivation: motivation,
            fingerStiff: fingerStiff
        )
        
        let log = DayLog(date: .now)
        log.hrv = hrv
        log.restingHR = rhr
        log.sleepHours = sleep
        log.motivation1to5 = motivation
        log.fingerStiffOnWaking = fingerStiff
        log.stiffWhichFinger = stiffWhichFinger
        log.skinScore1to5 = skinScore
        log.antihydralApplied = antihydralApplied
        log.flagCount = result.flagCount
        log.verdict = result.verdict
        
        modelContext.insert(log)
        try? modelContext.save()
        
        onComplete()
        dismiss()
    }
}
