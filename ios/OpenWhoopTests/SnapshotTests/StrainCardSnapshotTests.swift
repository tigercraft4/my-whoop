import XCTest
import SnapshotTesting
import SwiftUI
@testable import OpenWhoop
import WhoopStore

final class StrainCardSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Set isRecording = true to regenerate reference snapshots
        // isRecording = true
    }

    private func makeController(_ view: some View) -> UIViewController {
        UIHostingController(rootView: view.preferredColorScheme(.dark))
    }

    func testStrainCard_optimal() throws {
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
            totalCaloriesKcal: 2450.0
        )
        let vc = makeController(
            StrainCard(daily: daily)
                .frame(width: 390)
                .background(WH.Color.background)
        )
        assertSnapshot(of: vc, as: .image(on: .iPhone13Pro))
    }

    func testStrainCard_overreaching() throws {
        let daily = DailyMetric(
            day: "2026-06-01",
            totalSleepMin: 360,
            efficiency: 0.72,
            deepMin: 60,
            remMin: 50,
            lightMin: 140,
            disturbances: 6,
            restingHr: 62,
            avgHrv: 38,
            recovery: 0.28,
            strain: 19.5,
            exerciseCount: nil
        )
        let vc = makeController(
            StrainCard(daily: daily)
                .frame(width: 390)
                .background(WH.Color.background)
        )
        assertSnapshot(of: vc, as: .image(on: .iPhone13Pro))
    }

    func testStrainCard_empty() throws {
        let vc = makeController(
            StrainCard(daily: nil)
                .frame(width: 390)
                .background(WH.Color.background)
        )
        assertSnapshot(of: vc, as: .image(on: .iPhone13Pro))
    }
}
