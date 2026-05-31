import Foundation
import HealthKit
import WhoopStore

// MARK: - HealthKitExporter
//
// Exports WHOOP biometric data to Apple Health:
//   HK-01 — Heart rate samples (HKQuantityType .heartRate) via highwater cursor
//   HK-02 — HRV RMSSD per sleep session (HKQuantityType .heartRateVariabilitySDNN) via avgHrv
//   HK-04 — Sleep sessions with stage mapping (HKCategoryType .sleepAnalysis) via delete+reinsert
//
// Concurrency: actor isolation ensures thread-safe access to the HKHealthStore and UserDefaults
// cursor state without @MainActor pinning (HealthKit calls are safe from any thread).

actor HealthKitExporter {

    // MARK: - UserDefaults cursor keys

    static let hrHighwaterKey  = "hk.hrHighwater"   // epoch seconds of last exported HR sample
    static let hrvHighwaterKey = "hk.hrvHighwater"  // epoch seconds of last exported HRV session end

    // MARK: - Properties

    private let store: HKHealthStore
    private let whoopStore: WhoopStore
    private let deviceId: String

    // MARK: - Init

    init(whoopStore: WhoopStore, deviceId: String) {
        self.store      = HKHealthStore()
        self.whoopStore = whoopStore
        self.deviceId   = deviceId
    }

    // MARK: - Authorization

    /// Request write-only HealthKit access for HR, HRV, and Sleep.
    /// Caller must check authorizationStatus separately if it needs to know whether denied.
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let typesToShare: Set<HKSampleType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKCategoryType(.sleepAnalysis)
        ]

        try await store.requestAuthorization(toShare: typesToShare, read: [])
    }

    // MARK: - Export entry point

    /// Export all three streams. One stream failure does not abort the others.
    func export() async {
        do { try await exportHR() }    catch { print("[HKExporter] HR export error: \(error)") }
        do { try await exportHRV() }   catch { print("[HKExporter] HRV export error: \(error)") }
        do { try await exportSleep() } catch { print("[HKExporter] Sleep export error: \(error)") }
    }

    // MARK: - HR Export (HK-01)

    private func exportHR() async throws {
        let since = Int(UserDefaults.standard.double(forKey: Self.hrHighwaterKey))
        let samples = try await whoopStore.hrSamples(deviceId: deviceId, since: since, limit: 5000)
        guard !samples.isEmpty else { return }

        let hrType = HKQuantityType(.heartRate)
        let unit   = HKUnit(from: "count/min")

        let hkSamples: [HKQuantitySample] = samples.map { s in
            let date = Date(timeIntervalSince1970: TimeInterval(s.ts))
            return HKQuantitySample(
                type: hrType,
                quantity: HKQuantity(unit: unit, doubleValue: Double(s.bpm)),
                start: date,
                end: date,
                metadata: [HKMetadataKeyWasUserEntered: false]
            )
        }

        try await store.save(hkSamples)

        if let lastTs = samples.last?.ts {
            UserDefaults.standard.set(Double(lastTs), forKey: Self.hrHighwaterKey)
        }
    }

    // MARK: - HRV Export (HK-02)

    private func exportHRV() async throws {
        let since    = Int(UserDefaults.standard.double(forKey: Self.hrvHighwaterKey))
        let sessions = try await whoopStore.sleepSessions(deviceId: deviceId)

        let pending = sessions.filter { $0.endTs > since && $0.avgHrv != nil }
        guard !pending.isEmpty else { return }

        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        let unit    = HKUnit.secondUnit(with: .milli)

        let hkSamples: [HKQuantitySample] = pending.compactMap { s in
            guard let hrv = s.avgHrv else { return nil }
            return HKQuantitySample(
                type: hrvType,
                quantity: HKQuantity(unit: unit, doubleValue: hrv),
                start: Date(timeIntervalSince1970: TimeInterval(s.startTs)),
                end:   Date(timeIntervalSince1970: TimeInterval(s.endTs)),
                metadata: [HKMetadataKeyWasUserEntered: false]
            )
        }

        try await store.save(hkSamples)

        if let maxEndTs = pending.map({ $0.endTs }).max() {
            UserDefaults.standard.set(Double(maxEndTs), forKey: Self.hrvHighwaterKey)
        }
    }

    // MARK: - Sleep Export (HK-04)

    private func exportSleep() async throws {
        let sessions = try await whoopStore.sleepSessions(deviceId: deviceId)
        guard !sessions.isEmpty else { return }

        let sleepType = HKCategoryType(.sleepAnalysis)

        for session in sessions {
            let sessionStart = Date(timeIntervalSince1970: TimeInterval(session.startTs))
            let sessionEnd   = Date(timeIntervalSince1970: TimeInterval(session.endTs))

            // Delete existing HK sleep samples for the exact session window (idempotent)
            let predicate = NSPredicate(
                format: "startDate >= %@ AND endDate <= %@",
                sessionStart as NSDate,
                sessionEnd   as NSDate
            )
            try await store.deleteObjects(of: sleepType, predicate: predicate)

            // Parse stage segments and create HK samples
            guard let stagesJSON = session.stagesJSON,
                  let data = stagesJSON.data(using: .utf8),
                  let segments = try? JSONDecoder().decode([SleepSegment].self, from: data),
                  !segments.isEmpty else { continue }

            let hkSamples: [HKCategorySample] = segments.compactMap { seg in
                guard let value = sleepStageValue(for: seg.stage) else {
                    print("[HKExporter] Unknown sleep stage '\(seg.stage)' — skipping")
                    return nil
                }
                return HKCategorySample(
                    type: sleepType,
                    value: value.rawValue,
                    start: Date(timeIntervalSince1970: TimeInterval(seg.start)),
                    end:   Date(timeIntervalSince1970: TimeInterval(seg.end)),
                    metadata: [HKMetadataKeyWasUserEntered: false]
                )
            }

            if !hkSamples.isEmpty {
                try await store.save(hkSamples)
            }
        }
    }

    // MARK: - Stage Mapping

    private func sleepStageValue(for stage: String) -> HKCategoryValueSleepAnalysis? {
        switch stage.lowercased() {
        case "light", "core": return .asleepCore
        case "deep":          return .asleepDeep
        case "rem":           return .asleepREM
        case "awake":         return .awake
        default:              return nil
        }
    }
}

// MARK: - SleepSegment (local decode model for stagesJSON)

private struct SleepSegment: Decodable {
    let start: Int
    let end:   Int
    let stage: String
}
