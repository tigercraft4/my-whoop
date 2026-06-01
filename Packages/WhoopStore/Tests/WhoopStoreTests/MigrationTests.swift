import XCTest
import GRDB
@testable import WhoopStore

final class MigrationTests: XCTestCase {
    func testInMemoryRunsMigrations() async throws {
        let store = try await WhoopStore.inMemory()
        let tables = try await store.tableNames()
        for t in ["device", "hrSample", "rrInterval", "event", "battery", "rawBatch"] {
            XCTAssertTrue(tables.contains(t), "missing table \(t)")
        }
    }

    func testFileInitRunsMigrations() async throws {
        let path = NSTemporaryDirectory() + "whoopstore-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try await WhoopStore(path: path)
        let tables = try await store.tableNames()
        XCTAssertTrue(tables.contains("hrSample"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }

    func testHrSamplePrimaryKeyIsDeviceIdTs() async throws {
        let store = try await WhoopStore.inMemory()
        let cols = try await store.primaryKeyColumns("hrSample")
        XCTAssertEqual(cols, ["deviceId", "ts"])
    }

    func testRrIntervalPrimaryKeyIncludesRrMs() async throws {
        let store = try await WhoopStore.inMemory()
        let cols = try await store.primaryKeyColumns("rrInterval")
        XCTAssertEqual(cols, ["deviceId", "ts", "rrMs"])
    }

    /// v5 adds a `synced` column to all 8 decoded tables.
    func testV5AddsSyncedColumnToDecodedTables() async throws {
        let store = try await WhoopStore.inMemory()
        for table in ["hrSample", "rrInterval", "event", "battery",
                      "spo2Sample", "skinTempSample", "respSample", "gravitySample"] {
            let cols = try await store.columnNamesForTest(table: table)
            XCTAssertTrue(cols.contains("synced"), "\(table) missing synced column")
        }
        XCTAssertEqual(WhoopStoreInfo.schemaVersion, 5)
    }

    /// v10 purges RR intervals outside the physiological range [200, 2000] ms and
    /// clears all cached avgHrv values (which were derived from corrupt RR data).
    ///
    /// BUGFIX-03 — D-08, D-09
    func testMigrationV10PurgesInvalidRRAndClearsAvgHrv() throws {
        // Use a raw DatabaseQueue so we can control migration sequencing:
        // apply migrations up to v9, insert test data, then apply v10 and verify.
        let queue = try DatabaseQueue()
        let migrator = WhoopStore.makeMigrator()

        // Step 1: Apply all migrations up to (and including) v9 — stop before v10.
        // GRDB DatabaseMigrator.migrate(_:upTo:) runs migrations whose identifier
        // is <= the given target, in registration order.
        try migrator.migrate(queue, upTo: "v9")

        // Step 2: Insert test data into the v9 schema.
        try queue.write { db in
            // rrInterval rows — primary key (deviceId, ts, rrMs)
            // Invalid: rrMs below 200 (physiologically impossible — below 30 bpm equivalent)
            try db.execute(
                sql: "INSERT INTO rrInterval (deviceId, ts, rrMs) VALUES (?, ?, ?)",
                arguments: ["test", 1000, 50]
            )
            // Invalid: rrMs above 2000 (physiologically impossible — below 30 bpm equivalent)
            try db.execute(
                sql: "INSERT INTO rrInterval (deviceId, ts, rrMs) VALUES (?, ?, ?)",
                arguments: ["test", 1001, 65535]
            )
            // Valid: rrMs = 800 (75 bpm, within [200, 2000])
            try db.execute(
                sql: "INSERT INTO rrInterval (deviceId, ts, rrMs) VALUES (?, ?, ?)",
                arguments: ["test", 1002, 800]
            )
            // Valid: rrMs = 200 (inclusive lower boundary — must survive)
            try db.execute(
                sql: "INSERT INTO rrInterval (deviceId, ts, rrMs) VALUES (?, ?, ?)",
                arguments: ["test", 1003, 200]
            )
            // Valid: rrMs = 2000 (inclusive upper boundary — must survive)
            try db.execute(
                sql: "INSERT INTO rrInterval (deviceId, ts, rrMs) VALUES (?, ?, ?)",
                arguments: ["test", 1004, 2000]
            )

            // dailyMetric row with a non-NULL avgHrv — must be cleared to NULL by v10
            try db.execute(
                sql: "INSERT INTO dailyMetric (deviceId, day, avgHrv) VALUES (?, ?, ?)",
                arguments: ["test", "2026-01-01", 52.0]
            )
        }

        // Step 3: Apply migration v10 (purges invalid RR rows, clears avgHrv).
        try migrator.migrate(queue, upTo: "v10")

        // Step 4: Verify post-migration state.
        try queue.read { db in
            // Invalid rows (rrMs=50 and rrMs=65535) must be gone.
            let invalidCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM rrInterval WHERE rrMs < 200 OR rrMs > 2000"
            ) ?? -1
            XCTAssertEqual(invalidCount, 0,
                "v10 must delete all rrInterval rows with rrMs < 200 or > 2000; found \(invalidCount)")

            // Valid rows (rrMs=800, 200, 2000) must all survive.
            let validCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM rrInterval WHERE rrMs IN (800, 200, 2000)"
            ) ?? -1
            XCTAssertEqual(validCount, 3,
                "v10 must preserve all rrInterval rows with rrMs in [200, 2000]; found \(validCount)")

            // All dailyMetric rows must have avgHrv = NULL after v10.
            let nonNullHrvCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM dailyMetric WHERE avgHrv IS NOT NULL"
            ) ?? -1
            XCTAssertEqual(nonNullHrvCount, 0,
                "v10 must clear avgHrv to NULL in all dailyMetric rows; \(nonNullHrvCount) non-NULL row(s) remain")
        }
    }
}
