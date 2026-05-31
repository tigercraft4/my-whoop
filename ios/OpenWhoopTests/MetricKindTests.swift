import XCTest
import WhoopStore
@testable import OpenWhoop

final class MetricKindTests: XCTestCase {

    // MARK: - Helpers

    private func makeMetric(efficiency: Double? = nil, restingHr: Int? = nil) -> DailyMetric {
        DailyMetric(
            day: "2026-05-20",
            totalSleepMin: 400,
            efficiency: efficiency,
            deepMin: 80,
            remMin: 100,
            lightMin: 220,
            disturbances: 2,
            restingHr: restingHr,
            avgHrv: 58,
            recovery: 0.62,
            strain: 10,
            exerciseCount: 1
        )
    }

    // MARK: - MetricKind.sleepPerformance — display properties

    func testSleepPerformanceTitleIsCorrect() {
        XCTAssertEqual(MetricKind.sleepPerformance.title, "Sleep Performance")
    }

    func testSleepPerformanceUnitIsPercent() {
        XCTAssertEqual(MetricKind.sleepPerformance.unit, "%")
    }

    func testSleepPerformanceFormatShowsRoundedPercent() {
        XCTAssertEqual(MetricKind.sleepPerformance.format(87), "87%")
        XCTAssertEqual(MetricKind.sleepPerformance.format(100), "100%")
        XCTAssertEqual(MetricKind.sleepPerformance.format(0), "0%")
        XCTAssertEqual(MetricKind.sleepPerformance.format(87.6), "88%")
    }

    func testSleepPerformanceFormatShortIsValueOnly() {
        XCTAssertEqual(MetricKind.sleepPerformance.formatShort(87), "87")
        XCTAssertEqual(MetricKind.sleepPerformance.formatShort(100), "100")
    }

    func testSleepPerformanceFixedYDomainIs0To100() {
        XCTAssertEqual(MetricKind.sleepPerformance.fixedYDomain, 0...100)
    }

    func testSleepPerformanceMarkTypeIsBar() {
        XCTAssertEqual(MetricKind.sleepPerformance.markType, .bar)
    }

    // MARK: - MetricKind.sleepPerformance — value(from:)

    func testSleepPerformanceValueScalesEfficiencyFrom0To100() {
        let metric = makeMetric(efficiency: 0.87)
        let result = MetricKind.sleepPerformance.value(from: metric)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 87.0, accuracy: 0.001)
    }

    func testSleepPerformanceValueReturnsNilWhenEfficiencyIsNil() {
        let metric = makeMetric(efficiency: nil)
        let result = MetricKind.sleepPerformance.value(from: metric)
        XCTAssertNil(result)
    }

    func testSleepPerformanceValueScalesEdgeCases() {
        let metricZero = makeMetric(efficiency: 0.0)
        XCTAssertEqual(MetricKind.sleepPerformance.value(from: metricZero)!, 0.0, accuracy: 0.001)

        let metricFull = makeMetric(efficiency: 1.0)
        XCTAssertEqual(MetricKind.sleepPerformance.value(from: metricFull)!, 100.0, accuracy: 0.001)
    }

    // MARK: - dailyCases membership

    func testDailyCasesContainsSleepPerformance() {
        XCTAssertTrue(MetricKind.dailyCases.contains(.sleepPerformance),
                      "dailyCases must include .sleepPerformance")
    }

    func testDailyCasesDoesNotContainSleepDuration() {
        XCTAssertFalse(MetricKind.dailyCases.contains(.sleepDuration),
                       "dailyCases must NOT include .sleepDuration (swapped for sleepPerformance)")
    }

    // MARK: - MetricKind.rhr title

    func testRhrTitleIsCompact() {
        XCTAssertEqual(MetricKind.rhr.title, "RHR")
    }
}
