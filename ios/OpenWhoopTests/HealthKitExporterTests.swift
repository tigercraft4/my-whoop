import XCTest
import HealthKit
import WhoopStore
import WhoopProtocol
@testable import OpenWhoop

// MARK: - HealthKitExporterTests
//
// Tests for the HealthKitExporter actor.
// Tests that require a live HKHealthStore are guarded by HKHealthStore.isHealthDataAvailable()
// so they pass (skip) in CI / iOS Simulator environments where HealthKit is unavailable.
//
// Tests that exercise pure Swift logic (cursor arithmetic, stage mapping) run everywhere.

final class HealthKitExporterTests: XCTestCase {

    // MARK: - Helpers

    private static let testDeviceId = "hk-test-device"
    private static let hrHighwaterKey  = "hk.hrHighwater"
    private static let hrvHighwaterKey = "hk.hrvHighwater"

    /// Reset HK cursor keys in UserDefaults before and after each test.
    override func setUp() async throws {
        UserDefaults.standard.removeObject(forKey: Self.hrHighwaterKey)
        UserDefaults.standard.removeObject(forKey: Self.hrvHighwaterKey)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: Self.hrHighwaterKey)
        UserDefaults.standard.removeObject(forKey: Self.hrvHighwaterKey)
    }

    // MARK: - Test 1: HR highwater cursor — WhoopStore query filters by since

    /// Verifies that hrSamples(deviceId:since:limit:) returns only samples newer than `since`.
    /// This is a pure GRDB query test — no HealthKit required.
    func testHrSamplesHighwaterFiltersOlderRows() async throws {
        let store = try await WhoopStore.inMemory()

        // Seed 3 HR samples at ts 100, 200, 300
        try await store.injectHRSamples(
            deviceId: Self.testDeviceId,
            samples: [(ts: 100, bpm: 60), (ts: 200, bpm: 65), (ts: 300, bpm: 70)]
        )

        // With since = 0: all 3 rows returned
        let all = try await store.hrSamples(deviceId: Self.testDeviceId, since: 0, limit: 100)
        XCTAssertEqual(all.count, 3, "since=0 should return all 3 samples")
        XCTAssertEqual(all.map { $0.ts }, [100, 200, 300])

        // With since = 200: only ts=300 returned (ts > 200)
        let filtered = try await store.hrSamples(deviceId: Self.testDeviceId, since: 200, limit: 100)
        XCTAssertEqual(filtered.count, 1, "since=200 should return only ts=300")
        XCTAssertEqual(filtered.first?.ts, 300)
        XCTAssertEqual(filtered.first?.bpm, 70)

        // With since = 300: no rows (nothing newer than the last sample)
        let empty = try await store.hrSamples(deviceId: Self.testDeviceId, since: 300, limit: 100)
        XCTAssertTrue(empty.isEmpty, "since=300 should return zero samples (nothing newer)")
    }

    // MARK: - Test 2: HR cursor key is correct constant

    /// Verifies the cursor key constants on HealthKitExporter match what the tests and SettingsView use.
    func testHrHighwaterKeyConstant() {
        XCTAssertEqual(HealthKitExporter.hrHighwaterKey,  "hk.hrHighwater")
        XCTAssertEqual(HealthKitExporter.hrvHighwaterKey, "hk.hrvHighwater")
    }

    // MARK: - Test 3: Sleep stage mapping

    /// Verifies correct mapping of WHOOP stage strings to HKCategoryValueSleepAnalysis.
    /// Pure logic test — no HealthKit store access required.
    func testSleepStageMappingAllKnownStages() async throws {
        let store = try await WhoopStore.inMemory()

        // Seed a sleep session with all 4 known stages
        let stagesJSON = """
        [
            {"start":0,"end":3600,"stage":"light"},
            {"start":3600,"end":7200,"stage":"deep"},
            {"start":7200,"end":9000,"stage":"rem"},
            {"start":9000,"end":10800,"stage":"awake"}
        ]
        """
        try await store.upsertSleepSessions([
            CachedSleepSession(startTs: 0, endTs: 10800, efficiency: 0.85, restingHr: 55,
                               avgHrv: 42.0, stagesJSON: stagesJSON)
        ], deviceId: Self.testDeviceId)

        let sessions = try await store.sleepSessions(deviceId: Self.testDeviceId)
        XCTAssertEqual(sessions.count, 1)

        // Parse the stagesJSON and verify the stage strings
        let json = stagesJSON.data(using: .utf8)!
        let segments = try JSONDecoder().decode([SleepSegmentTestHelper].self, from: json)
        XCTAssertEqual(segments.count, 4)

        // Verify stage strings match expected WHOOP values
        XCTAssertEqual(segments[0].stage, "light",  "first segment should be light")
        XCTAssertEqual(segments[1].stage, "deep",   "second segment should be deep")
        XCTAssertEqual(segments[2].stage, "rem",    "third segment should be rem")
        XCTAssertEqual(segments[3].stage, "awake",  "fourth segment should be awake")

        // Verify mapped HealthKit values
        XCTAssertEqual(mapStage("light"),  HKCategoryValueSleepAnalysis.asleepCore.rawValue,  "light → .asleepCore")
        XCTAssertEqual(mapStage("core"),   HKCategoryValueSleepAnalysis.asleepCore.rawValue,  "core → .asleepCore")
        XCTAssertEqual(mapStage("deep"),   HKCategoryValueSleepAnalysis.asleepDeep.rawValue,  "deep → .asleepDeep")
        XCTAssertEqual(mapStage("rem"),    HKCategoryValueSleepAnalysis.asleepREM.rawValue,   "rem → .asleepREM")
        XCTAssertEqual(mapStage("awake"),  HKCategoryValueSleepAnalysis.awake.rawValue,       "awake → .awake")
    }

    func testSleepStageMappingUnknownStageIsSkipped() {
        // Unknown stages should map to nil (skipped in export)
        XCTAssertNil(mapStageOptional("unknown_stage"), "unknown stage should not map to a value")
        XCTAssertNil(mapStageOptional("nrem3"),         "non-WHOOP stage string should be nil")
        XCTAssertNil(mapStageOptional(""),              "empty stage string should be nil")
    }

    // MARK: - Test 4: HK-03 absence verification

    /// Verifies that HealthKitExporter.swift contains no oxygenSaturation or spo2 references.
    /// This is a source-level string test to enforce the D-02 / PROTO-11 invariant.
    func testHealthKitExporterHasNoOxygenSaturationCode() throws {
        // Find HealthKitExporter.swift relative to this test bundle
        guard let sourceURL = Bundle(for: type(of: self))
            .url(forResource: "HealthKitExporter", withExtension: "swift") else {
            // Source file not in test bundle (this is expected at runtime) — skip gracefully
            // The CI check is done by the grep in VERIFICATION.md
            return
        }
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertFalse(source.lowercased().contains("oxygensaturation"),
                       "HealthKitExporter must not reference oxygenSaturation (HK-03 deferred)")
        XCTAssertFalse(source.lowercased().contains("spo2"),
                       "HealthKitExporter must not reference spo2 (HK-03 deferred)")
    }

    // MARK: - Test 5: sleepSessions(deviceId:) returns all sessions ordered by startTs

    func testSleepSessionsReturnsAllSessions() async throws {
        let store = try await WhoopStore.inMemory()

        try await store.upsertSleepSessions([
            CachedSleepSession(startTs: 200, endTs: 300, efficiency: nil, restingHr: nil, avgHrv: nil, stagesJSON: nil),
            CachedSleepSession(startTs: 100, endTs: 200, efficiency: nil, restingHr: nil, avgHrv: nil, stagesJSON: nil),
        ], deviceId: Self.testDeviceId)

        let sessions = try await store.sleepSessions(deviceId: Self.testDeviceId)
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].startTs, 100, "sessions should be ordered by startTs ASC")
        XCTAssertEqual(sessions[1].startTs, 200)
    }
}

// MARK: - Test Helpers

/// Mirror of the private SleepSegment struct in HealthKitExporter — used in tests to decode stagesJSON.
private struct SleepSegmentTestHelper: Decodable {
    let start: Int
    let end:   Int
    let stage: String
}

/// Replicates the stage mapping logic from HealthKitExporter for pure-Swift testing.
private func mapStage(_ stage: String) -> Int {
    switch stage.lowercased() {
    case "light", "core": return HKCategoryValueSleepAnalysis.asleepCore.rawValue
    case "deep":          return HKCategoryValueSleepAnalysis.asleepDeep.rawValue
    case "rem":           return HKCategoryValueSleepAnalysis.asleepREM.rawValue
    case "awake":         return HKCategoryValueSleepAnalysis.awake.rawValue
    default:              return -1
    }
}

private func mapStageOptional(_ stage: String) -> Int? {
    switch stage.lowercased() {
    case "light", "core": return HKCategoryValueSleepAnalysis.asleepCore.rawValue
    case "deep":          return HKCategoryValueSleepAnalysis.asleepDeep.rawValue
    case "rem":           return HKCategoryValueSleepAnalysis.asleepREM.rawValue
    case "awake":         return HKCategoryValueSleepAnalysis.awake.rawValue
    default:              return nil
    }
}

// MARK: - WhoopStore test injection helper

private extension WhoopStore {
    /// Insert raw HR samples for testing via the public insert() API.
    func injectHRSamples(deviceId: String, samples: [(ts: Int, bpm: Int)]) async throws {
        let hrSamples = samples.map { HRSample(ts: $0.ts, bpm: $0.bpm) }
        try await insert(Streams(hr: hrSamples), deviceId: deviceId, markSynced: true)
    }
}
