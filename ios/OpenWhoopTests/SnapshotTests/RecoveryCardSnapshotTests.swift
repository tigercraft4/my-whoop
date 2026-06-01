import XCTest
import SnapshotTesting
import SwiftUI
@testable import OpenWhoop
import WhoopStore

final class RecoveryCardSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Set isRecording = true to regenerate reference snapshots
        // isRecording = true
    }

    private func makeController(_ view: some View) -> UIViewController {
        UIHostingController(rootView: view.preferredColorScheme(.dark))
    }

    func testRecoveryCard_green() throws {
        let daily = DailyMetric(
            day: "2026-06-01",
            totalSleepMin: 435,
            efficiency: 0.84,
            deepMin: 90,
            remMin: 72,
            lightMin: 180,
            disturbances: 3,
            restingHr: 56,
            avgHrv: 52,
            recovery: 0.73,
            strain: 14.2,
            exerciseCount: nil,
            respRateBpm: 15.8,
            sleepPerformance: 84.0,
            sleepNeededMin: 450.0
        )
        let vc = makeController(
            RecoveryCard(daily: daily)
                .frame(width: 390)
                .background(WH.Color.background)
        )
        assertSnapshot(of: vc, as: .image(on: .iPhone13Pro))
    }

    func testRecoveryCard_yellow() throws {
        let daily = DailyMetric(
            day: "2026-06-01",
            totalSleepMin: 300,
            efficiency: 0.70,
            deepMin: 60,
            remMin: 50,
            lightMin: 140,
            disturbances: 5,
            restingHr: 62,
            avgHrv: 38,
            recovery: 0.50,
            strain: 12.0,
            exerciseCount: nil,
            sleepPerformance: 60.0,
            sleepNeededMin: 480.0
        )
        let vc = makeController(
            RecoveryCard(daily: daily)
                .frame(width: 390)
                .background(WH.Color.background)
        )
        assertSnapshot(of: vc, as: .image(on: .iPhone13Pro))
    }

    func testRecoveryCard_empty() throws {
        let vc = makeController(
            RecoveryCard(daily: nil)
                .frame(width: 390)
                .background(WH.Color.background)
        )
        assertSnapshot(of: vc, as: .image(on: .iPhone13Pro))
    }
}
