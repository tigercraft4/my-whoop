import SwiftUI

@main
struct OpenWhoopApp: App {
    var body: some Scene {
        WindowGroup {
            AppRoot()
        }
    }
}

/// Thin root wrapper that creates a MetricsRepository and LiveViewModel synchronously (no
/// async window) and immediately injects them as environment objects so RootTabView + its
/// tabs always receive non-nil @EnvironmentObjects from the very first render frame.
///
/// LiveViewModel owns the single BLEManager / CBCentralManager. Creating it here (at app
/// launch) means state-restoration fires in the same process lifetime as the manager, and
/// both the Device tab and the Alarm sheet share the same BLE connection.
///
/// The MetricsRepository opens its on-disk store lazily (on the first load/refresh call),
/// so there is no need to wait for an async factory before showing the UI.
///
/// BACKFILL WIRE — why `.onAppear` is not sufficient as the sole wire point:
/// With BLE state restoration (strap already bonded), CoreBluetooth can call
/// `willRestoreState` synchronously during `CBCentralManager.init`, which happens inside
/// `LiveViewModel.init`. The 1.5 s handshake delay before `beginBackfill` means the first
/// backfill normally completes well after `.onAppear`, but on a fast device with an
/// already-bonded strap the race window is real: `exitBackfilling` calls
/// `onBackfillComplete?()` while the closure is still nil → silent no-op →
/// `computeLocalMetrics()` is never called → data sits in the DB but never surfaces.
///
/// Fix: both objects are created inside `AppRootCoordinator.init()` (a `@MainActor` class)
/// and the backfill closure is wired immediately after both objects are constructed — before
/// SwiftUI evaluates `body` and before any CoreBluetooth event can arrive.
private struct AppRoot: View {
    @StateObject private var coordinator = AppRootCoordinator()

    var body: some View {
        RootTabView()
            .environmentObject(coordinator.metrics)
            .environmentObject(coordinator.live)
            .environmentObject(coordinator.hkExporter)
            .onAppear {
                // Idempotent re-wire on every appear (simple closure assignment).
                // Belt-and-suspenders: covers normal launch + any future scene re-insertion.
                coordinator.wireBackfill()
            }
    }
}

/// Owns MetricsRepository + LiveViewModel and wires the backfill→metrics bridge
/// synchronously in `init()` so the closure is registered before any BLE event arrives.
///
/// `@MainActor` is required because `LiveViewModel.init` is `@MainActor`-isolated. SwiftUI
/// initialises `@StateObject` wrapped values on the main thread, satisfying this requirement
/// at runtime; the annotation makes the isolation explicit to the Swift concurrency checker.
@MainActor
private final class AppRootCoordinator: ObservableObject {
    let metrics:    MetricsRepository
    let live:       LiveViewModel
    let hkExporter: HealthKitExporterViewModel

    init() {
        let m  = MetricsRepository(deviceId: AppConfig.deviceId)
        let l  = LiveViewModel(deviceId: AppConfig.deviceId)
        let hk = HealthKitExporterViewModel()
        self.metrics    = m
        self.live       = l
        self.hkExporter = hk
        // Wire synchronously — both objects are fully constructed here.
        l.onBackfillComplete {
            Task { await m.computeLocalMetrics() }
        }
    }

    /// Idempotent re-wire called from `.onAppear` as belt-and-suspenders.
    func wireBackfill() {
        live.onBackfillComplete { [metrics = self.metrics] in
            Task { await metrics.computeLocalMetrics() }
        }
    }
}
