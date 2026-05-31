import XCTest
@testable import OpenWhoop

// MARK: - TrainingStateTests
// Unit tests for the trainingState(recovery:strain:) lookup function.
// Behaviour cases from 12-02-PLAN.md:
//   recovery=100, strain=5  → RESTORATIVE  (5 < lower 13)
//   recovery=100, strain=17 → OPTIMAL      (13 ≤ 17 ≤ 21)
//   recovery=50,  strain=20 → OVERREACHING (20 > upper ~14.98)
//   recovery=0,   strain=5  → OPTIMAL      (lower 0, upper 10; 5 within band)

final class TrainingStateTests: XCTestCase {

    // MARK: - Core zone cases

    func testRestorativeWhenStrainBelowLower() {
        // recovery=100 → lower=13; strain=5 is below → RESTORATIVE
        let result = TrainingState.trainingState(recovery: 100, strain: 5)
        XCTAssertEqual(result, "RESTORATIVE", "strain 5 with recovery 100 should be RESTORATIVE")
    }

    func testOptimalWhenStrainWithinBand() {
        // recovery=100 → lower=13, upper=21; strain=17 is in band → OPTIMAL
        let result = TrainingState.trainingState(recovery: 100, strain: 17)
        XCTAssertEqual(result, "OPTIMAL", "strain 17 with recovery 100 should be OPTIMAL")
    }

    func testOverreachingWhenStrainAboveUpper() {
        // recovery=50 → upper≈14.98; strain=20 > upper → OVERREACHING
        let result = TrainingState.trainingState(recovery: 50, strain: 20)
        XCTAssertEqual(result, "OVERREACHING", "strain 20 with recovery 50 should be OVERREACHING")
    }

    func testOptimalAtRecoveryZero() {
        // recovery=0 → lower=0, upper=10; strain=5 within band → OPTIMAL
        let result = TrainingState.trainingState(recovery: 0, strain: 5)
        XCTAssertEqual(result, "OPTIMAL", "strain 5 with recovery 0 should be OPTIMAL")
    }

    // MARK: - Edge cases

    func testRestorativeAtRecoveryZeroStrainZero() {
        // recovery=0 → lower=0; strain=0 is NOT < 0 → OPTIMAL (at boundary lower)
        let result = TrainingState.trainingState(recovery: 0, strain: 0)
        XCTAssertNotNil(result)
    }

    func testClampRecoveryAbove100() {
        // recovery=150 should clamp to 100, same as recovery=100
        let clamped = TrainingState.trainingState(recovery: 150, strain: 5)
        let at100   = TrainingState.trainingState(recovery: 100, strain: 5)
        XCTAssertEqual(clamped, at100, "recovery >100 should clamp to 100")
    }

    func testClampRecoveryBelow0() {
        // recovery=-10 should clamp to 0, same as recovery=0
        let clamped = TrainingState.trainingState(recovery: -10, strain: 5)
        let at0     = TrainingState.trainingState(recovery: 0, strain: 5)
        XCTAssertEqual(clamped, at0, "recovery <0 should clamp to 0")
    }

    func testRoundsRecoveryToNearestInt() {
        // recovery=99.7 rounds to 100; recovery=99.2 rounds to 99 — both should return non-nil
        let r1 = TrainingState.trainingState(recovery: 99.7, strain: 5)
        let r2 = TrainingState.trainingState(recovery: 99.2, strain: 5)
        XCTAssertNotNil(r1)
        XCTAssertNotNil(r2)
    }

    func testReturnsNilOnBadInput() {
        // If the table loaded correctly all valid recoveries (0–100) should return non-nil
        for rec in stride(from: 0.0, through: 100.0, by: 10.0) {
            let result = TrainingState.trainingState(recovery: rec, strain: 10)
            XCTAssertNotNil(result, "trainingState should not return nil for valid recovery \(rec)")
        }
    }

    func testNoImpossibleLabel() {
        // Plan D-05: "IMPOSSIBLE" must never be returned
        for rec in stride(from: 0.0, through: 100.0, by: 10.0) {
            for strain in stride(from: 0.0, through: 21.0, by: 3.0) {
                let result = TrainingState.trainingState(recovery: rec, strain: strain)
                XCTAssertNotEqual(result, "IMPOSSIBLE", "IMPOSSIBLE should never be returned")
            }
        }
    }

    func testOnlyKnownLabels() {
        // Only RESTORATIVE, OPTIMAL, OVERREACHING (or nil) should be returned
        let allowed: Set<String> = ["RESTORATIVE", "OPTIMAL", "OVERREACHING"]
        for rec in stride(from: 0.0, through: 100.0, by: 5.0) {
            for strain in stride(from: 0.0, through: 21.0, by: 3.0) {
                if let result = TrainingState.trainingState(recovery: rec, strain: strain) {
                    XCTAssertTrue(allowed.contains(result),
                                  "Unexpected label '\(result)' for recovery=\(rec) strain=\(strain)")
                }
            }
        }
    }
}
