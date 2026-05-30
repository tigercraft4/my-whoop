import XCTest
@testable import WhoopProtocol

final class SchemaSyncTests: XCTestCase {
    /// Repo root, derived from this file's path:
    /// .../Packages/WhoopProtocol/Tests/WhoopProtocolTests/SchemaSyncTests.swift
    /// up 5 dirs (file -> WhoopProtocolTests -> Tests -> WhoopProtocol -> Packages -> repo).
    private func repoRoot(file: StaticString = #filePath) -> URL {
        var url = URL(fileURLWithPath: "\(file)")
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url
    }

    func testBundledSchemaMatchesCanonical() throws {
        // 5.0 (Maverick) is the runtime default schema (D-01). The bundled Swift resource
        // must equal the canonical protocol/whoop_protocol_5.json — keep them in sync with
        // scripts/sync-schema-5.sh.
        let canonical = repoRoot()
            .appendingPathComponent("protocol")
            .appendingPathComponent("whoop_protocol_5.json")
        let bundled = repoRoot()
            .appendingPathComponent("Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json")

        let canonicalData = try Data(contentsOf: canonical)
        let bundledData = try Data(contentsOf: bundled)
        XCTAssertEqual(bundledData, canonicalData,
                       "bundled Resources/whoop_protocol_5.json drifted from canonical protocol/whoop_protocol_5.json — run scripts/sync-schema-5.sh")
    }

    func testBundleModuleSchemaAlsoMatchesCanonical() throws {
        // The schema actually loaded at runtime (Bundle.module) must equal the canonical too.
        // Use the public API so Bundle.module resolves from the WhoopProtocol source target
        // (not the test target, which has a separate bundle without the schema resource).
        let canonical = repoRoot()
            .appendingPathComponent("protocol")
            .appendingPathComponent("whoop_protocol_5.json")
        let canonicalData = try Data(contentsOf: canonical)
        let moduleURL = try XCTUnwrap(
            WhoopProtocolInfo.schemaResourceURL(),
            "WhoopProtocolInfo.schemaResourceURL() returned nil — whoop_protocol_5.json missing from WhoopProtocol bundle")
        let moduleData = try Data(contentsOf: moduleURL)
        XCTAssertEqual(moduleData, canonicalData,
                       "Bundle.module schema differs from canonical protocol/whoop_protocol_5.json")
    }
}
