import XCTest
import SnapshotTesting
import SwiftUI
@testable import OpenWhoop
import WhoopStore

final class SleepCardSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Set isRecording = true to regenerate reference snapshots
        // isRecording = true
    }

    private func makeController(_ view: some View) -> UIViewController {
        UIHostingController(rootView: view.preferredColorScheme(.dark))
    }

    func testSleepCard_withData() throws {
        let daily = DailyMetric(
            day: "2026-06-01",
            totalSleepMin: 452,
            efficiency: 0.87,
            deepMin: 88,
            remMin: 70,
            lightMin: 192,
            disturbances: 2,
            restingHr: 54,
            avgHrv: 61,
            recovery: 0.78,
            strain: nil,
            exerciseCount: nil,
            sleepPerformance: 82.0,
            sleepNeededMin: 450.0
        )
        let vc = makeController(
            SleepCard(session: nil, daily: daily)
                .frame(width: 390)
                .background(WH.Color.background)
        )
        assertSnapshot(of: vc, as: .image(on: .iPhone13Pro))
    }

    func testSleepCard_empty() throws {
        let vc = makeController(
            SleepCard(session: nil, daily: nil)
                .frame(width: 390)
                .background(WH.Color.background)
        )
        assertSnapshot(of: vc, as: .image(on: .iPhone13Pro))
    }
}
