import SwiftUI
import HealthKit
import WhoopStore

// MARK: - HealthKitExporterViewModel
//
// Thin ObservableObject wrapper around the HealthKitExporter actor so SwiftUI's
// @EnvironmentObject system can hold it. The underlying HealthKitExporter actor is
// created lazily on the first call to requestAuthorizationAndExport — never at app launch.
//
// Injection: AppRootCoordinator creates this as @Published and AppRoot exposes it as
// .environmentObject(coordinator.hkExporter). TodayView reads it via @EnvironmentObject.

@MainActor
final class HealthKitExporterViewModel: ObservableObject {

    @Published private(set) var isAuthorized = false
    @Published private(set) var authDenied   = false

    private var exporter: HealthKitExporter?

    // MARK: - Lazy auth + export

    /// Request HealthKit authorization and export all streams.
    /// Creates the actor on first call (lazy). No-ops on simulator (isHealthDataAvailable guard).
    func requestAuthorizationAndExport(whoopStore: WhoopStore, deviceId: String) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        // Lazy creation — never at app launch
        if exporter == nil {
            exporter = HealthKitExporter(whoopStore: whoopStore, deviceId: deviceId)
        }
        guard let exporter else { return }

        do {
            try await exporter.requestAuthorization()
        } catch {
            print("[HKExporterVM] Authorization error: \(error)")
            authDenied = true
            return
        }

        // Check status after authorization request
        let hrType = HKQuantityType(.heartRate)
        let store   = HKHealthStore()
        let status  = store.authorizationStatus(for: hrType)

        switch status {
        case .sharingAuthorized:
            isAuthorized = true
            authDenied   = false
            await exporter.export()
        case .sharingDenied:
            authDenied   = true
            isAuthorized = false
        default:
            // .notDetermined — user dismissed sheet; treat as not denied yet
            break
        }
    }
}
