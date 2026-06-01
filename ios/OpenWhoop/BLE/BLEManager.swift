import Foundation
import CoreBluetooth
import OSLog
import WhoopProtocol
import WhoopStore

/// CoreBluetooth engine for the WHOOP 5.0: scan-by-service → connect → discover →
/// BOND (one confirmed write) → subscribe → reassemble char-05 frames → FrameRouter.
/// Cannot run in the simulator; verified manually on-device (Task C6).
@MainActor
public final class BLEManager: NSObject, ObservableObject {

    // MARK: GATT UUIDs (authoritative, from FINDINGS_5.md §1 — WHOOP 5.0)
    static let customService   = CBUUID(string: "FD4B0001-CCE1-4033-93CE-002D5875F58A")
    static let cmdWriteChar    = CBUUID(string: "FD4B0002-CCE1-4033-93CE-002D5875F58A") // CMD → strap
    static let cmdNotifyChar   = CBUUID(string: "FD4B0003-CCE1-4033-93CE-002D5875F58A") // responses
    static let eventNotifyChar = CBUUID(string: "FD4B0004-CCE1-4033-93CE-002D5875F58A") // events
    static let dataNotifyChar  = CBUUID(string: "FD4B0005-CCE1-4033-93CE-002D5875F58A") // data (frag)
    static let heartRateService = CBUUID(string: "180D")
    static let heartRateChar    = CBUUID(string: "2A37") // HR + R-R (works unbonded)
    static let batteryService   = CBUUID(string: "180F")
    static let batteryChar      = CBUUID(string: "2A19")

    // Gen4 / legacy service (61080xxx) — same WHOOP device, different GATT service.
    // Historical DATA frames (type-47) from SEND_HISTORICAL_DATA arrive on 61080005,
    // NOT on FD4B0005, as confirmed by re/sync_openwhoop.py which subscribes 61080005.
    static let gen4Service       = CBUUID(string: "61080001-8D6D-82B8-614A-1C8CB0F8DCC6")
    static let gen4DataNotifChar = CBUUID(string: "61080005-8D6D-82B8-614A-1C8CB0F8DCC6")

    static let restoreID = "com.openwhoop.ble.central"

    // MARK: Published state
    public let state: LiveState
    private let router: FrameRouter
    private var collector: Collector?

    // MARK: Upload
    private var uploader: Uploader?

    // MARK: Server pull (History = union(phone-collected, server-computed))
    private var serverSync: ServerSync?
    /// Guards the once-per-launch cloud restore attempt so it does not re-run on every reconnect.
    /// `restoreIfEmpty()` is already self-gating via the emptiness check, but this flag avoids a
    /// redundant round-trip on every connect once we know the store is non-empty.
    private var didAttemptRestore = false

    // MARK: Backfill
    private var backfiller: Backfiller?
    /// True while a historical offload session is in progress (frames route to Backfiller).
    private var backfilling = false
    /// Safety-net detector: strap reports newer data than us AND our frontier frozen 10 min ⇒ flag for
    /// reboot. behindGapSeconds avoids false positives when off-wrist / caught up. Insurance only.
    private var stuckDetector = StuckStrapDetector(stuckAfterSeconds: 600, behindGapSeconds: 300)
    /// Newest record unix the strap reports having (from the GET_DATA_RANGE response); refreshed each
    /// offload. Compared against our frontier to tell "stuck" from "off-wrist/caught-up".
    private var strapNewestTs: Int?
    /// Fires if the strap goes silent mid-offload; re-armed on every frame during backfill.
    private var backfillTimeout: DispatchWorkItem?
    /// Fires if the FF key exchange is not completed within 15s after connect handshake.
    /// Clears ffExchangePending and triggers requestSync(.connect) so backfill can proceed.
    private var ffExchangeTimeout: DispatchWorkItem?
    /// Periodic opportunistic upload while connected. Without it, upload only fires at connect +
    /// backfill-exit, so during a long live session decoded rows pile up locally and the server
    /// (dashboard) lags. Started on bond, cancelled on disconnect.
    private var uploadTimer: DispatchSourceTimer?
    static let uploadIntervalSeconds = 30
    /// Periodic re-trigger of the type-47 historical offload. This is the PRIMARY continuous metric
    /// source (mirrors how WHOOP syncs): the strap's 14-day biometric store is re-offloaded every
    /// `backfillIntervalSeconds` while connected+bonded, rather than once per connect. Started on
    /// bond, cancelled on disconnect. Plain SEND_HISTORICAL_DATA returns the type-47 store (no
    /// high-freq-sync), so each periodic tick just routes through requestSync(.periodic) → beginBackfill
    /// (SEND_HISTORICAL_DATA + watchdog), subject to the BackfillPolicy floor.
    private var backfillTimer: DispatchSourceTimer?
    // The timer fires this often, but BackfillPolicy.periodicFloorSeconds is the real floor (a recent
    // event-triggered sync defers the next periodic tick). 900s = 15 min, matching WHOOP.
    static let backfillIntervalSeconds = 900
    /// Last-offload-attempt time (unix seconds), persisted so the rate limiter survives relaunch
    /// (matches WHOOP's DATA_SYNC_WORKER_LAST_WORK_TIME watermark).
    static let backfillLastAtKey = "backfillLastAt"
    /// Prevents a second backfill from starting on a same-process reconnect to the same strap.
    private var backfillStarted = false
    /// Runs the connect handshake EXACTLY ONCE per connection. `didWriteValueFor` re-fires on every
    /// `.withResponse` write (the bond write, every SEND_HISTORICAL, every HISTORY_END ack); without
    /// this guard those re-entries re-blasted hello/SET_CLOCK at the strap mid-offload and stopped it
    /// from streaming type-47 — THE iOS "won't serve" root cause. Reset on disconnect.
    private var connectHandshakeDone = false
    private var bondRetryCount = 0
    private static let maxBondRetries = 3
    /// Re-entrancy guard for captureRawAccel: true while a bounded on-demand window is running.
    /// A second tap is a no-op until the active capture's asyncAfter block fires and clears this.
    private var rawCaptureInFlight = false
    /// Ordered queue of frames awaiting drain through the serial Backfiller task.
    private var backfillFrameQueue: [[UInt8]] = []
    /// True while the drain task is running (prevents a second drain task from launching).
    private var backfillDraining = false
    /// Called once after every historical offload session ends (regardless of reason).
    /// Wired by AppRoot to MetricsRepository.computeLocalMetrics() so offline-derived metrics
    /// (resting HR, HRV, sleep detection) update immediately after new BLE data arrives.
    var onBackfillComplete: (() -> Void)?
    /// FF exchange state — tracks rounds of SEND_NEXT_FF and accumulates FF names for SET_FF_VALUE.
    private var ffExchangePending = false
    private var ffRoundsRemaining = 0
    private var ffNames: [String] = []

    // MARK: CoreBluetooth
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    /// Peripheral captured during `willRestoreState`; cleared in `didConnect`.
    /// Non-nil signals that `centralManagerDidUpdateState` should reconnect this
    /// specific peripheral rather than starting a fresh scan.
    private var restoredPeripheral: CBPeripheral?
    private var cmdCharacteristic: CBCharacteristic?
    private let reassembler = Reassembler()
    private var seq: UInt8 = 0
    private var didBond = false
    private var clockRequested = false
    private var intentionalDisconnect = false

    /// Stable device id; matches the server's existing device for sync parity. Overridable.
    let deviceId: String
    /// Captured (device↔wall) correlation from GET_CLOCK; nil until the response lands.
    private(set) var clockRef: ClockRef?

    public init(state: LiveState, deviceId: String = "my-whoop") {
        self.state = state
        self.deviceId = deviceId
        self.router = FrameRouter(state: state)
        // WhoopStore.init is now async, so it can't run here.
        // bootstrapStore() is called once the CBCentralManager reaches poweredOn
        // (see centralManagerDidUpdateState), which guarantees the store is ready
        // before any BLE data arrives.
        self.collector = nil
        super.init()
        state.lastSyncedAt = UserDefaults.standard.object(forKey: "lastSyncedAt") as? Double
        // Restore identifier + background-capable central (foundation for M3 state restoration).
        central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionRestoreIdentifierKey: BLEManager.restoreID]
        )
        // Strap-as-clock: an incoming EVENT packet kicks a rate-limited catch-up sync.
        router.onSyncTrigger = { [weak self] in self?.requestSync(.strap) }
    }

    /// Build the WhoopStore + Collector + Backfiller asynchronously. Safe to call multiple
    /// times — bails out early if the collector is already initialised.
    func bootstrapStore() async {
        guard collector == nil else { return }
        guard let path = try? StorePaths.defaultDatabasePath() else { return }
        guard let store = try? await WhoopStore(path: path) else { return }
        try? await store.upsertDevice(id: deviceId, mac: nil, name: "WHOOP 5.0")
        // Research toggle — OFF by default. When disabled the app is decoded-only and never
        // persists raw frames. Flip "enableRawCapture" in UserDefaults to capture raw again.
        let enableRawCapture = UserDefaults.standard.bool(forKey: "enableRawCapture")
        collector = Collector(store: store, deviceId: deviceId,
                              enableRawCapture: enableRawCapture)
        backfiller = Backfiller(store: store, deviceId: deviceId,
                                ackTrim: { [weak self] trim, endData in
                                    self?.ackHistoricalChunk(trim: trim, endData: endData)
                                },
                                enableRawCapture: enableRawCapture)
        if let cfg = AppConfig.uploaderConfig(deviceId: deviceId) {
            uploader = Uploader(config: cfg, store: store, deviceId: deviceId)
            serverSync = ServerSync(config: cfg, store: store, deviceId: deviceId)
        }
    }

    /// Designated initializer for testing and preview use: accepts a pre-built Collector.
    init(state: LiveState, deviceId: String = "my-whoop", collector: Collector?) {
        self.state = state
        self.deviceId = deviceId
        self.router = FrameRouter(state: state)
        self.collector = collector
        super.init()
        state.lastSyncedAt = UserDefaults.standard.object(forKey: "lastSyncedAt") as? Double
        central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionRestoreIdentifierKey: BLEManager.restoreID]
        )
        // Strap-as-clock: an incoming EVENT packet kicks a rate-limited catch-up sync.
        router.onSyncTrigger = { [weak self] in self?.requestSync(.strap) }
    }

    // MARK: Public API
    public func connect() {
        intentionalDisconnect = false
        guard central.state == .poweredOn else {
            log("Bluetooth not powered on (state=\(central.state.rawValue)); cannot scan yet")
            return
        }
        log("Scanning for service \(BLEManager.customService)…")
        central.scanForPeripherals(
            withServices: [BLEManager.customService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    public func disconnect() {
        intentionalDisconnect = true
        guard central.state == .poweredOn else { return }
        if let p = peripheral {
            central.cancelPeripheralConnection(p)
        }
        central.stopScan()
    }

    /// Apply the raw-outbox retention policy (24h synced window / 50MB unsynced cap).
    /// Called when the app enters the background; no-op without a concrete store.
    public func pruneRaw() {
        Task { @MainActor in await collector?.prune() }
    }

    /// Light storage summary for the UI (decoded rows, raw batches, raw bytes). nil without a store.
    public func storageStats() async -> (decodedRows: Int, rawBatches: Int, rawBytes: Int)? {
        await collector?.storageStats()
    }

    /// Capture raw accelerometer (type-43 IMU) frames on demand for a bounded window, then stop.
    /// Persists raw even when the global research toggle is off (that's the point: on-demand, not
    /// 24/7). The Collector's window auto-expires at its deadline so a dropped stop can't leak raw.
    public func captureRawAccel(seconds: TimeInterval = 30) {
        guard !rawCaptureInFlight else {
            log("Raw-accel capture: already in flight — ignoring")
            return
        }
        rawCaptureInFlight = true
        let secs = RawCaptureWindow.clamp(seconds)
        collector?.beginRawCapture(seconds: secs)
        send(.startRawData, payload: [0x01])
        send(.toggleIMUMode, payload: [0x01])
        log("Raw-accel capture: started for \(secs)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + secs) { [weak self] in
            guard let self else { return }
            // Only stop the raw stream if the 24/7 research toggle is OFF.  When it's ON, the
            // continuous stream must keep running — we just flush/upload the bounded window we
            // captured without halting the wider session.
            if !UserDefaults.standard.bool(forKey: "enableRawCapture") {
                self.send(.stopRawData, payload: [0x01])
            }
            self.rawCaptureInFlight = false
            Task { @MainActor in
                await self.collector?.endRawCapture()
                self.uploadOpportunistically()   // push the captured raw to the server
            }
            self.log("Raw-accel capture: stopped + flushed")
        }
    }

    /// Send a command to the WHOOP strap.
    /// - Parameters:
    ///   - command: The command to send.
    ///   - payload: Command payload bytes (default `[0x00]`).
    ///   - writeType: BLE write type; defaults to `.withoutResponse` so all existing call
    ///     sites are unaffected. Pass `.withResponse` for acked commands (e.g. historicalDataResult).
    public func send(_ command: WhoopCommand, payload: [UInt8] = [0x00],
                     writeType: CBCharacteristicWriteType = .withoutResponse) {
        guard let p = peripheral, let ch = cmdCharacteristic else {
            log("send(\(command.label)) ignored — not connected")
            return
        }
        seq = seq &+ 1
        // WHOOP 5.0 requires Maverick-wrapped writes for all commands (PROTO-05, resolved).
        // golden corpus (frames_5_golden.json): all 27 writes to FD4B0002 are Maverick [AA][01][len][body][trailer].
        // The 4.0 frame() format has 0% pass rate on 5.0 firmware (FINDINGS_5.md §7 PROTO-04).
        let frame = command.maverickFrame(seq: seq, payload: payload)
        p.writeValue(Data(frame), for: ch, type: writeType)
        log("→ \(command.label) payload=\(hex(payload))")
    }

    /// Ack one HISTORY_END chunk so the strap may trim it. Confirmed write — the strap forgets
    /// the chunk once this lands (link-layer half of safe-trim; decoded + raw already persisted).
    ///
    /// High-freq-sync ack form (matches re/sync_openwhoop.py, which pulled 762 type-47 records):
    /// HISTORICAL_DATA_RESULT(23) payload = `[0x01] + end_data`, where end_data is the verbatim
    /// 8 bytes of the HISTORY_END metadata.data[10:18] (trim u32 at [10:14] + next u32 at [14:18]).
    /// The `trim` argument (= end_data first u32) is already persisted as the strap_trim cursor by
    /// the Backfiller; it is passed here only for logging.
    func ackHistoricalChunk(trim: UInt32, endData: [UInt8]) {
        send(.historicalDataResult, payload: [0x01] + endData, writeType: .withResponse)
    }

    // MARK: Backfill helpers

    /// Start a historical-offload session: tell the store machine to begin, flip the routing
    /// flag, kick the strap with sendHistoricalData, and arm the idle timeout.
    private func beginBackfill() {
        // Never offload before the connect handshake has run: a racing foreground/restore trigger
        // firing SEND_HISTORICAL ahead of hello/SET_CLOCK was part of the storm that stopped serving.
        guard connectHandshakeDone else {
            log("Backfill: deferred — connect handshake not done yet")
            return
        }
        guard !ffExchangePending else {
            log("Backfill: deferred — FF key exchange still in progress")
            return
        }
        guard let backfiller else {
            // Store not ready yet. Do NOT force live HR — the type-47 backfill is the metric
            // source. Just log; the next periodic backfill tick will run once the store is ready.
            log("Backfill: store not ready — deferring to next periodic tick")
            return
        }
        backfiller.begin()
        backfilling = true
        backfillFrameCount = 0
        // SEND_HISTORICAL_DATA triggers the historical offload on the WHOOP 5.0.
        // START_FF_KEY_EXCHANGE was already sent in the connect handshake — that is what unlocks
        // historical serving. ENTER_HIGH_FREQ_SYNC (cmd 96) is NOT sent — it never appears in
        // the official WHOOP 5.0 app capture (capture_all-V3.pklg golden corpus).
        send(.sendHistoricalData, payload: [0x00], writeType: .withResponse)
        armBackfillTimeout()
        log("Backfill: session started — historical offload requested")
        BLEManager.logger.notice("BF: session started")
    }

    /// Feed a frame to the Backfiller preserving exact arrival order. Frames are appended
    /// synchronously (delegate order) and drained sequentially by a single task, so START /
    /// data / END chunk assembly is never reordered (Backfiller.ingest is async).
    private var backfillFrameCount = 0
    private func routeBackfillFrame(_ frame: [UInt8]) {
        backfillFrameCount += 1
        if backfillFrameCount == 1 || backfillFrameCount % 50 == 0 {
            let isMav = frame.count > 1 && frame[1] == 0x01
            let typeOff = isMav ? 8 : 4
            let pktType = frame.count > typeOff ? frame[typeOff] : 0
            let subId  = frame.count > typeOff + 2 ? frame[typeOff + 2] : 0  // event_num or resp_cmd
            BLEManager.logger.notice("BF: frame #\(self.backfillFrameCount, privacy: .public) type=\(pktType, privacy: .public) sub=\(subId, privacy: .public) len=\(frame.count, privacy: .public)")
        }
        backfillFrameQueue.append(frame)
        guard !backfillDraining else { return }
        backfillDraining = true
        Task { @MainActor in
            while !backfillFrameQueue.isEmpty {
                let f = backfillFrameQueue.removeFirst()
                await backfiller?.ingest(f)
                afterBackfillIngest()
            }
            backfillDraining = false
        }
    }

    /// Called after every Backfiller.ingest completes. If the Backfiller has consumed all
    /// historical data (isBackfilling drops to false), exit the backfill session cleanly.
    private func afterBackfillIngest() {
        guard backfilling, backfiller?.isBackfilling == false else { return }
        exitBackfilling(reason: "HISTORY_COMPLETE")
    }

    /// True when a frame is part of the historical offload (HISTORICAL_DATA=47, EVENT=48,
    /// METADATA=49, CONSOLE_LOGS=50) rather than the live stream (REALTIME_DATA=40,
    /// REALTIME_RAW_DATA=43). The live type-43 raw flood streams continuously and unprompted on
    /// this firmware, so the backfill idle-watchdog must NOT be re-armed by it — only by genuine
    /// offload progress — otherwise the session can neither complete nor time out.
    static func isOffloadFrame(_ frame: [UInt8]) -> Bool {
        // Maverick 5.0: [0xAA][0x01][len_lo][len_hi][role][token0][token1][token2][packet_type]...
        // packet_type is at frame[8]; frame[4] is the role byte (always 0x01).
        // 4.0: [0xAA][len_lo][len_hi][crc8][packet_type]... → packet_type at frame[4].
        let isMaverick = frame.count > 1 && frame[1] == 0x01
        let typeOffset = isMaverick ? 8 : 4
        guard frame.count > typeOffset else { return false }
        switch frame[typeOffset] {
        case 47, 48, 49, 50: return true   // HISTORICAL_DATA / EVENT / METADATA / CONSOLE_LOGS
        default: return false              // 40 REALTIME_DATA, 43 REALTIME_RAW_DATA (live flood)
        }
    }

    /// Re-arm the idle watchdog. Called on every offload frame during backfill so the timer resets
    /// as long as the strap keeps sending HISTORY; if the strap goes silent the timer fires and we
    /// exit the session (the durable strap_trim cursor means the next session resumes where we left
    /// off). Timeout is generous (60 s, not 20 s): the unstoppable ~2/s type-43 raw flood eats BLE
    /// airtime, so genuine offload frames can arrive in bursts with multi-second lulls between chunks
    /// — a short watchdog cut sessions short mid-drain. Longer = more records drained per session.
    static let backfillIdleTimeoutSeconds = 60
    private func armBackfillTimeout() {
        backfillTimeout?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.backfiller?.timeoutFired()
            self.exitBackfilling(reason: "timeout")
        }
        backfillTimeout = item
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(BLEManager.backfillIdleTimeoutSeconds), execute: item)
    }

    /// Tear down the backfill session. Does NOT auto-start live HR: the periodic type-47 backfill
    /// is the primary metric source now, mirroring how WHOOP syncs. Live HR is opt-in only (the
    /// manual "Start HR" button in LiveView). Between backfills the Collector sees only the live
    /// type-43 flood, which extractStreams ignores — the data comes from the next periodic offload.
    private func exitBackfilling(reason: String) {
        guard backfilling else { return }
        backfilling = false
        backfillTimeout?.cancel()
        backfillTimeout = nil
        backfillFrameQueue.removeAll()
        log("Backfill: session ended — reason=\(reason)")
        BLEManager.logger.notice("BF: session ended reason=\(reason, privacy: .public)")
        uploadOpportunistically()
        // Read-path sync runs AFTER the offload, never concurrently with it — the offload and the
        // pull share the WhoopStore actor, and a large first-run pull would starve the Backfiller's
        // per-chunk insert→ack and trip the 20s offload watchdog. Safe to run now: backfilling=false.
        restoreFromServerIfNeeded()  // once-per-launch: full history restore if the store is empty
        pullFromServer()             // incremental pull: new rows since read-highwater
        if reason == "HISTORY_COMPLETE" {
            state.lastSyncedAt = Date().timeIntervalSince1970
            UserDefaults.standard.set(state.lastSyncedAt, forKey: "lastSyncedAt")
        }
        checkStrapLiveness()         // safety-net: strap ahead of us AND our frontier frozen ⇒ stuck?
        onBackfillComplete?()        // trigger offline metric derivation (LocalMetricsComputer)
    }

    /// After an offload, judge liveness: stuck = strap reports records newer than our frontier AND our
    /// frontier (max persisted HR ts) hasn't advanced for the detector window. Off-wrist / caught up
    /// (strap not ahead) is NOT stuck. On stuck: attempt recovery (defensive EXIT + SET_CLOCK) and raise
    /// the surface. Best-effort; reads the frontier via the Collector (which owns the concrete store).
    private func checkStrapLiveness() {
        let strapNewest = strapNewestTs
        Task { @MainActor in
            let frontier = await collector?.latestHRSampleTs()
            let front: Int? = frontier ?? nil
            let now = Date().timeIntervalSince1970
            let stuck = stuckDetector.observe(strapNewestTs: strapNewest,
                                              ourFrontierTs: front,
                                              now: now)
            state.strapNeedsReboot = stuck
            if stuck {
                log("Watchdog: behind + frontier frozen — recovery (exit high-freq + SET_CLOCK)")
                send(.exitHighFreqSync, payload: [0x00])
                send(.setClock, payload: BLEManager.setClockPayload())
            }
        }
    }

    /// Fire-and-forget drain: pushes any pending rows to the server.
    /// No-op when uploader is nil (placeholder secrets / unconfigured).
    private func uploadOpportunistically() {
        guard let uploader else { return }
        Task { await uploader.drain() }
    }

    /// Fire-and-forget server pull: GET new decoded streams + derived metrics since the read
    /// highwater and upsert locally (History = union(phone-collected, server-computed)). Best-effort
    /// — a pull failure never affects the BLE connection. No-op when serverSync is nil (unconfigured).
    private func pullFromServer() {
        guard let serverSync else { return }
        Task { await serverSync.pull() }
    }

    /// Attempt a once-per-launch cloud restore if the local store is empty (fresh reinstall). If
    /// the store is non-empty `restoreIfEmpty()` returns false immediately (< 1ms). Best-effort —
    /// a failure never affects the BLE connection. The `didAttemptRestore` flag prevents re-running
    /// on subsequent reconnects within the same process lifetime; the emptiness check in
    /// `restoreIfEmpty()` itself makes this doubly safe.
    private func restoreFromServerIfNeeded() {
        guard !didAttemptRestore, let serverSync else { return }
        didAttemptRestore = true
        Task { await serverSync.restoreIfEmpty() }
    }

    /// Start (or restart) the periodic upload timer so the server stays current during a long
    /// connected session. Idempotent drains (highwater-gated) make repeated firing safe.
    private func startUploadTimer() {
        uploadTimer?.cancel()
        guard uploader != nil else { return }
        let interval = BLEManager.uploadIntervalSeconds
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + .seconds(interval), repeating: .seconds(interval))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            self.uploadOpportunistically()
            // Keep the local union current with server-computed metrics — but never while an offload
            // is in flight (the pull would starve the Backfiller's insert→ack on the shared actor).
            if !self.backfilling { self.pullFromServer() }
        }
        t.resume()
        uploadTimer = t
    }

    /// Pure decision: should the periodic timer kick off another historical offload? Only when
    /// connected + bonded and NOT already mid-backfill. Extracted so the gate is unit-testable
    /// without a CoreBluetooth seam. Note this intentionally does NOT consult `backfillStarted`
    /// (that flag guards the once-per-connect INITIAL kick); the periodic re-trigger is separate.
    static func shouldRunPeriodicBackfill(connected: Bool, bonded: Bool, backfilling: Bool) -> Bool {
        connected && bonded && !backfilling
    }

    /// Start (or restart) the periodic backfill timer. Each tick re-runs the type-47 historical
    /// offload while connected+bonded and not already backfilling — the primary metric sync.
    private func startBackfillTimer() {
        backfillTimer?.cancel()
        let interval = BLEManager.backfillIntervalSeconds
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + .seconds(interval), repeating: .seconds(interval))
        t.setEventHandler { [weak self] in self?.triggerPeriodicBackfill() }
        t.resume()
        backfillTimer = t
    }

    /// The single gated entry point for every historical-offload kick. Applies the connection/state
    /// gate AND the BackfillPolicy rate-limiter for the trigger. On a go: records the attempt time
    /// (persisted) and starts the offload.
    func requestSync(_ trigger: BackfillTrigger) {
        guard BLEManager.shouldRunPeriodicBackfill(
            connected: state.connected, bonded: state.bonded, backfilling: backfilling) else { return }
        let now = Date().timeIntervalSince1970
        let last = UserDefaults.standard.object(forKey: BLEManager.backfillLastAtKey) as? Double
        guard BackfillPolicy.shouldRun(trigger: trigger, now: now, lastBackfillAt: last) else {
            log("Backfill: \(trigger) skipped (rate-limited; last \(last.map { Int(now - $0) } ?? -1)s ago)")
            return
        }
        UserDefaults.standard.set(now, forKey: BLEManager.backfillLastAtKey)
        beginBackfill()
    }

    /// Periodic-timer callback: routes through the rate-limited requestSync entry point.
    private func triggerPeriodicBackfill() {
        requestSync(.periodic)
    }

    // MARK: Helpers
    private static let logTimeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()
    private static let logger = Logger(subsystem: "com.francisco.openwhoop", category: "BLE")

    private func log(_ s: String) {
        let line = "[\(timestamp())] \(s)"
        state.append(log: line)
        BLEManager.logger.info("\(line, privacy: .public)")
    }
    private func timestamp() -> String {
        BLEManager.logTimeFormatter.string(from: Date())
    }
    private func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Alarm API (M6 — additive; does NOT touch connect/offload/sync flows)

    /// Arm the strap's firmware alarm for `date` (UTC).
    ///
    /// Sequence: SET_CLOCK first to ensure the strap RTC is UTC-correct, then SET_ALARM_TIME.
    /// The strap will buzz at `date` even if the app is backgrounded or force-quit
    /// (event STRAP_DRIVEN_ALARM_EXECUTED=57). This is the guaranteed fixed-time fallback path —
    /// the smart-wake layer (`SmartAlarmController`) fires on top of this if conditions are met,
    /// but this firmware alarm always fires as the safety net.
    ///
    /// On-device verification needed: confirm the strap ACKs SET_ALARM_TIME and that the
    /// alarm persists across BLE disconnect (cannot be verified in the simulator).
    func armStrapAlarm(at date: Date) {
        let epochSec = UInt32(date.timeIntervalSince1970)
        send(.setClock, payload: BLEManager.setClockPayload())
        send(.setAlarmTime, payload: WhoopCommand.setAlarmPayload(epochSec: epochSec))
        log("Alarm: armed for \(date) (epoch \(epochSec))")
    }

    /// Disarm the currently-armed firmware alarm.
    func disableStrapAlarm() {
        send(.disableAlarm, payload: [0x01])
        log("Alarm: disarmed")
    }

    /// Request the currently-armed alarm time from the strap (response arrives on cmd-notify char).
    /// Parsing the reply is optional/bonus — the raw bytes will appear in the BLE log.
    func getStrapAlarm() {
        send(.getAlarmTime, payload: [0x01])
        log("Alarm: requested current alarm time")
    }

    /// Fire an immediate alarm buzz on the strap for testing.
    ///
    /// Uses RUN_HAPTICS_PATTERN (cmd 79) with patternId=2, 3 loops — the same pattern the official
    /// WHOOP app uses for alarms (verified: patternId=2, observed for interoperability), plus RUN_ALARM
    /// (cmd 68) as a belt-and-suspenders. patternId=2 gives the characteristic graduated alarm buzz.
    ///
    /// Alternative waveform form (12-byte):
    ///   [wfe1=47, wfe2=152, 0,0,0,0,0,0, loop u16=0, overall_loop=7, dur=30]
    /// — note for future refinement; the preset id=2 form is simpler and confirmed to buzz on-device.
    ///
    /// Haptic firing cannot be verified in the simulator (no strap motor). Test on-device only.
    func testAlarmBuzz() {
        // VERIFIED payload from PacketLogger capture 2026-06-01:
        // cmd=0x13(19) payload=[01 2F 98 00 00 00 00 00 00 00 00 01 00] (13 bytes)
        // Confirmed: HAPTICS_FIRED (event 60) + HAPTICS_TERMINATED (event 100) received.
        // patternId=0x2F(47)=alarm pattern, intensity/param=0x98(152)
        send(.runHapticPatternMaverick, payload: [0x01, 0x2F, 0x98, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00])
        log("Alarm: test buzz fired (pattern=0x2F alarm, VERIFIED payload)")
    }

    /// Send TOGGLE_IMU_MODE command to the strap.
    ///
    /// When `on` is `true`, activates biometric streams (IMU/gravity, SpO₂, skin temp, respiration).
    /// When `false`, deactivates the streams.
    ///
    /// HYPOTHESIS (5.0 unverified) — command rawValue 106, inherited from 4.0.
    /// Physical validation is performed in Phase 7 (plan 07A) via re_harness.py capture session.
    public func toggleIMUMode(on: Bool) {
        let payload: [UInt8] = on ? [0x01] : [0x00]
        log("toggleIMUMode(on: \(on))")
        send(.toggleIMUMode, payload: payload)
    }

    /// Parse a standard BLE Heart Rate Measurement (0x2A37) via the pure StandardHeartRate parser.
    private func parseStandardHR(_ data: [UInt8]) {
        guard let m = StandardHeartRate.parse(data) else { return }
        // R-R: the standard profile is the RELIABLE source (the custom REALTIME_DATA stream
        // usually reports rr_count=0), so always surface intervals when present.
        if !m.rr.isEmpty { state.rr = m.rr }
        // HR: prefer the custom stream once bonded; use 0x2A37 HR as a pre-bond fallback.
        if state.heartRate == nil || !state.bonded { state.heartRate = m.hr }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: @preconcurrency CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log("Central state: \(central.state.rawValue) (5 = poweredOn)")
        guard central.state == .poweredOn else { return }
        // Bootstrap the async store once on first poweredOn (idempotent if already set).
        Task { @MainActor in await bootstrapStore() }
        if let p = restoredPeripheral {
            log("poweredOn with restored peripheral — reconnecting \(p.identifier)")
            if p.state != .connected {
                central.connect(p, options: nil)
            } else {
                p.discoverServices([
                    BLEManager.customService, BLEManager.gen4Service, BLEManager.heartRateService, BLEManager.batteryService,
                ])
            }
        } else {
            connect()
        }
    }

    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any],
                               rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? "unknown"
        log("Discovered \(name) (rssi \(RSSI)) — connecting")
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        restoredPeripheral = nil
        state.connected = true
        log("Connected — discovering services")
        peripheral.discoverServices([
            BLEManager.customService, BLEManager.gen4Service, BLEManager.heartRateService, BLEManager.batteryService,
        ])
    }

    public func centralManager(_ central: CBCentralManager,
                               didDisconnectPeripheral peripheral: CBPeripheral,
                               error: Error?) {
        Task { @MainActor in await collector?.flush() }
        state.connected = false
        didBond = false
        clockRequested = false
        connectHandshakeDone = false
        bondRetryCount = 0
        ffExchangePending = false
        ffRoundsRemaining = 0
        ffNames = []
        // Reset backfill state so the next connect starts a fresh offload.
        backfillStarted = false
        backfilling = false
        backfillTimeout?.cancel()
        backfillTimeout = nil
        backfillFrameQueue.removeAll()
        backfillDraining = false
        uploadTimer?.cancel()
        uploadTimer = nil
        backfillTimer?.cancel()
        backfillTimer = nil
        if !intentionalDisconnect {
            log("Disconnected\(error.map { " — \($0.localizedDescription)" } ?? ""); rescanning in 3s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self, !self.intentionalDisconnect else { return }
                self.connect()
            }
        } else {
            log("Disconnected (intentional)")
        }
    }

    public func centralManager(_ central: CBCentralManager,
                               didFailToConnect peripheral: CBPeripheral,
                               error: Error?) {
        log("Failed to connect\(error.map { " — \($0.localizedDescription)" } ?? "")")
    }

    /// State restoration entry point (M3 background collection).
    /// Stores the restored peripheral and — if already connected — immediately
    /// re-discovers services so `cmdCharacteristic` is re-acquired and
    /// notifications are re-routed without user interaction.
    public func centralManager(_ central: CBCentralManager,
                               willRestoreState dict: [String: Any]) {
        guard let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
              let p = peripherals.first else {
            log("Restore: no peripherals in state dict")
            return
        }
        self.peripheral = p
        self.restoredPeripheral = p
        p.delegate = self
        // Collection only runs post-bond, so a restored link was already bonded;
        // seed those flags now. `didWriteValueFor` won't re-fire on its own.
        state.bonded = true
        didBond = true
        // clockRef is nil in the fresh process after restore, so we must re-request it.
        // Reset the flag so the post-restore didWriteValueFor issues exactly one getClock.
        clockRequested = false
        // Ensure the store is ready before restored BLE data arrives (idempotent; no-op if already built).
        Task { @MainActor in await bootstrapStore() }
        if p.state == .connected {
            state.connected = true
            log("Restored CONNECTED peripheral \(p.identifier) — will re-discover services on poweredOn")
            // Do NOT call p.discoverServices() here: willRestoreState fires before
            // centralManagerDidUpdateState(.poweredOn), so the central is not yet ready.
            // centralManagerDidUpdateState handles re-discovery once the central is powered on.
        } else {
            state.connected = false
            log("Restored DISCONNECTED peripheral \(p.identifier) — reconnect on poweredOn")
            if central.state == .poweredOn { central.connect(p, options: nil) }
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: @preconcurrency CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for s in services {
            switch s.uuid {
            case BLEManager.customService:
                peripheral.discoverCharacteristics(
                    [BLEManager.cmdWriteChar, BLEManager.cmdNotifyChar,
                     BLEManager.eventNotifyChar, BLEManager.dataNotifyChar], for: s)
            case BLEManager.gen4Service:
                peripheral.discoverCharacteristics([BLEManager.gen4DataNotifChar], for: s)
            case BLEManager.heartRateService:
                peripheral.discoverCharacteristics([BLEManager.heartRateChar], for: s)
            case BLEManager.batteryService:
                peripheral.discoverCharacteristics([BLEManager.batteryChar], for: s)
            default: break
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didDiscoverCharacteristicsFor service: CBService,
                           error: Error?) {
        guard let chars = service.characteristics else { return }
        for c in chars {
            switch c.uuid {
            case BLEManager.cmdWriteChar:
                cmdCharacteristic = c
                // THE BONDING TRICK: one confirmed write triggers just-works bonding.
                // GET_BATTERY_LEVEL is benign and what the Mac prototype uses.
                seq = seq &+ 1
                let bondFrame = WhoopCommand.getBatteryLevel.maverickFrame(seq: seq, payload: [0x00])
                log("Bonding: confirmed write GET_BATTERY_LEVEL to FD4B0002")
                peripheral.writeValue(Data(bondFrame), for: c, type: .withResponse)
            case BLEManager.cmdNotifyChar,
                 BLEManager.eventNotifyChar,
                 BLEManager.dataNotifyChar,
                 BLEManager.gen4DataNotifChar,
                 BLEManager.heartRateChar:
                peripheral.setNotifyValue(true, for: c)
                log("Subscribed \(c.uuid)")
            case BLEManager.batteryChar:
                peripheral.setNotifyValue(true, for: c)
                // Read the current value immediately — 2A19 only notifies on change,
                // so without an explicit read the level stays "—" until the next change.
                peripheral.readValue(for: c)
                log("Subscribed Battery Level")
            default: break
            }
        }
    }

    /// Confirmed-write completion = bonding succeeded (no error).
    public func peripheral(_ peripheral: CBPeripheral,
                           didWriteValueFor characteristic: CBCharacteristic,
                           error: Error?) {
        if let error = error {
            // Encryption/authentication insufficient → iOS auto-starts BLE pairing.
            // Retry the bond write after 2s so it lands on the newly-encrypted link.
            if let attErr = error as? CBATTError,
               (attErr.code == .insufficientEncryption || attErr.code == .insufficientAuthentication),
               !didBond {
                bondRetryCount += 1
                guard bondRetryCount <= BLEManager.maxBondRetries else {
                    log("Bonding: encryption failed after \(BLEManager.maxBondRetries) retries — pair via Settings → Bluetooth → Forget This Device, then reconnect")
                    return
                }
                log("Bonding: link encrypting — retrying write in 2s (attempt \(bondRetryCount)/\(BLEManager.maxBondRetries))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard let self, let p = self.peripheral, let ch = self.cmdCharacteristic else { return }
                    self.seq = self.seq &+ 1
                    let frame = WhoopCommand.getBatteryLevel.maverickFrame(seq: self.seq, payload: [0x00])
                    p.writeValue(Data(frame), for: ch, type: .withResponse)
                    self.log("Bonding: retry write sent (\(self.bondRetryCount)/\(BLEManager.maxBondRetries))")
                }
                return
            }
            log("Confirmed write failed: \(error.localizedDescription)")
            return
        }
        if !didBond {
            didBond = true
            state.bonded = true
            log("BONDED — re-subscribing encrypted characteristics")
            // Re-subscribe to custom notify chars that failed pre-bond with Authentication insufficient.
            if let svc = peripheral.services?.first(where: { $0.uuid == BLEManager.customService }),
               let chars = svc.characteristics {
                for c in chars where c.uuid != BLEManager.cmdWriteChar {
                    peripheral.setNotifyValue(true, for: c)
                    log("Re-subscribing \(c.uuid)")
                }
            }
        }
        // Run the connect handshake EXACTLY ONCE per connection. didWriteValueFor re-fires on EVERY
        // .withResponse write — the bond write, every SEND_HISTORICAL, every HISTORY_END ack. Without
        // this guard those re-entries re-sent hello/SET_CLOCK at the strap *during* the offload and
        // stopped it from streaming type-47. This was THE iOS-side root cause: the Mac prototype pulls
        // type-47 fine because it runs the sequence once on a stable connection; the app stormed it.
        guard !connectHandshakeDone else { return }
        connectHandshakeDone = true
        backfillStarted = true

        // WHOOP 5.0 connect lifecycle — VERIFIED from PacketLogger 2026-06-01 (official WHOOP app):
        //   GET_HELLO(145,[01]) → SET_CLOCK(10) → GET_ADVERTISING_NAME(141,[01]) →
        //   START_FF_KEY_EXCHANGE(117,[01]) → [FF exchange: SEND_NEXT_FF×15 → SET_FF_VALUE×15] →
        //   HAPTICS(19) → GET_DATA_RANGE(34) → SEND_HISTORICAL_DATA(22,[00])
        //
        // CRITICAL: TOGGLE_REALTIME_HR and R10/R11 must NOT be sent before START_FF_KEY_EXCHANGE.
        // In the official app they appear only during the offload phase (~+77s into the session).
        // Sending them early causes the WHOOP state machine to enter a different mode and stop
        // responding to START_FF_KEY_EXCHANGE entirely (observed: FF exchange timeout every connect).
        send(.getHello, payload: [0x01])                            // cmd 145 — WHOOP 5.0 hello
        send(.setClock, payload: BLEManager.setClockPayload())      // cmd 10  — sync clock
        send(.getAdvertisingName, payload: [0x01])                  // cmd 141 — 5.0 advertising name
        ffExchangePending = true
        ffRoundsRemaining = 0
        ffNames = []
        send(.startFFKeyExchange, payload: [0x01])                  // cmd 117 — REQUIRED gate
        send(.getDataRange)                                         // cmd 34  — refresh watchdog range
        ffExchangeTimeout?.cancel()
        let ffTimeoutItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            BLEManager.logger.notice("BF: FF exchange timeout — no response to START_FF_KEY_EXCHANGE; falling back")
            self.ffExchangePending = false
            // Still stop the raw flood and enable HR before trying backfill
            self.send(.sendR10R11Realtime, payload: [0x00])
            self.send(.toggleRealtimeHR, payload: [0x01])
            if self.clockRef == nil && !self.clockRequested {
                self.clockRequested = true
                self.send(.getClock, payload: [])
            }
            self.requestSync(.connect)
        }
        ffExchangeTimeout = ffTimeoutItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: ffTimeoutItem)  // 10s — 15 rounds × ~0.06s + margin
        uploadOpportunistically()
        // NOTE: the server pull + cloud-restore are deliberately NOT kicked here. They share the
        // WhoopStore actor with the historical offload, and a large first-run pull would starve the
        // Backfiller's per-chunk insert→ack. They run from exitBackfilling() once the offload drains.
        startUploadTimer()     // keep the server current during the live session
        startBackfillTimer()   // re-offload the type-47 store every backfillIntervalSeconds
    }

    /// SET_CLOCK(10) payload: [seconds u32 LE][u32 zero] = 8 bytes (struct.pack("<II", now, 0)).
    /// Format confirmed by re/fix_raw_flood.py + re/enable_dataproducts.py (WHOOP 5.0 reference
    /// scripts). The older 9-byte form (re/sync_openwhoop.py Gen4) was a Gen4-only variant.
    static func setClockPayload(now: UInt32 = UInt32(Date().timeIntervalSince1970)) -> [UInt8] {
        [UInt8(now & 0xFF), UInt8((now >> 8) & 0xFF),
         UInt8((now >> 16) & 0xFF), UInt8((now >> 24) & 0xFF),
         0, 0, 0, 0]
    }

    /// Send one SEND_NEXT_FF request to pull the next Feature Flag entry from the strap.
    private func sendNextFFRound() {
        BLEManager.logger.notice("BF: SEND_NEXT_FF (remaining=\(self.ffRoundsRemaining, privacy: .public))")
        send(.sendNextFF, payload: [0x01])
    }

    /// After all SEND_NEXT_FF rounds complete, enable each FF with SET_FF_VALUE.
    /// Confirmed payload format: [0x01] + ASCII name (from capture_all-V3.pklg).
    private func setFFValues() {
        BLEManager.logger.notice("BF: SET_FF_VALUE for \(self.ffNames.count, privacy: .public) flags")
        // Payload format VERIFIED from PacketLogger 2026-06-01 (official WHOOP app):
        // [0x01][name: 63 bytes null-padded][version: 1 byte] = 65 bytes total
        // Most features use version=0x32(50); enable_r22_v4_packets and
        // enable_passive_strap_fit_gen5 use version=0x31(49).
        let featureVersions: [String: UInt8] = [
            "enable_r22_v4_packets": 0x31,
            "enable_passive_strap_fit_gen5": 0x31,
        ]
        func ffPayload(for name: String) -> [UInt8] {
            var payload: [UInt8] = [0x01]
            let nameBytes = Array(name.utf8.prefix(63))
            payload.append(contentsOf: nameBytes)
            payload.append(contentsOf: [UInt8](repeating: 0x00, count: 63 - nameBytes.count))
            payload.append(featureVersions[name] ?? 0x32)
            return payload  // 65 bytes
        }
        let names: [String] = ffNames.isEmpty ? [
            // Full 15 feature names VERIFIED from PacketLogger capture 2026-06-01:
            "enable_r22_packets", "enable_r22_v2_packets", "enable_r22_v3_packets",
            "enable_r22_v4_packets", "enable_r22_v5_packets", "enable_r22_v6_packets",
            "enable_r22_v8_packets", "make_hrfm_visible", "disable_pip_r26_packets",
            "wear_detect_bias", "hr_ch_switching", "ir_hw_switching",
            "enable_passive_strap_fit_gen5", "enable_sig11_during_sleep", "dorset_inhibit_wpt",
        ] : ffNames
        for name in names {
            send(.setFFValue, payload: ffPayload(for: name))
        }
        ffExchangeTimeout?.cancel()
        ffExchangeTimeout = nil
        ffExchangePending = false
        // Send R10/R11 and Toggle Realtime HR AFTER FF exchange (not before) — official app sequence.
        send(.sendR10R11Realtime, payload: [0x00])  // stop type-43 raw flood
        send(.toggleRealtimeHR, payload: [0x01])    // activate FD4B0005 data channel
        if clockRef == nil && !clockRequested {
            clockRequested = true
            send(.getClock, payload: [])
        }
        requestSync(.connect)
        BLEManager.logger.notice("BF: FF exchange complete (\(names.count, privacy: .public) flags) — requestSync(.connect) triggered")
    }

    /// Newest plausible-unix marker in a GET_DATA_RANGE COMMAND_RESPONSE = the strap's newest stored
    /// record. Mirrors re/diagnose_biometrics.py: scan u32 LE words in the response body (data starts at
    /// frame[7], after [type,seq,cmd]), keep those in the unix range, return the max. nil if none.
    static func dataRangeNewestUnix(from frame: [UInt8]) -> Int? {
        guard frame.count > 7 else { return nil }
        let body = Array(frame[7...]); var newest: Int? = nil; var i = 0
        while i + 4 <= body.count {
            let w = Int(body[i]) | Int(body[i+1]) << 8 | Int(body[i+2]) << 16 | Int(body[i+3]) << 24
            if w >= 1_700_000_000 && w <= 1_900_000_000 { newest = max(newest ?? 0, w) }
            i += 4
        }
        return newest
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didUpdateValueFor characteristic: CBCharacteristic,
                           error: Error?) {
        guard let data = characteristic.value else { return }
        let bytes = [UInt8](data)

        switch characteristic.uuid {
        case BLEManager.heartRateChar:
            parseStandardHR(bytes)
        case BLEManager.batteryChar:
            if let pct = bytes.first { state.setBattery(Double(pct)) } // 0x2A19 = percent
        case BLEManager.gen4DataNotifChar:
            // Gen4/legacy data channel — historical frames arrive here during backfill.
            BLEManager.logger.notice("BF: gen4 notification \(bytes.count, privacy: .public)B type=\(bytes.first ?? 0, privacy: .public)")
            if backfilling {
                armBackfillTimeout()
                routeBackfillFrame(bytes)
            }
        case BLEManager.dataNotifyChar,
             BLEManager.cmdNotifyChar,
             BLEManager.eventNotifyChar:
            // Reassemble (no-op for already-complete frames) then route each complete frame.
            for frame in reassembler.feed(bytes) {
                router.handle(frame: frame)                       // UI (always)
                let isMav = frame.count > 1 && frame[1] == 0x01
                let cmdOff = isMav ? 10 : 6
                // Log every COMMAND_RESPONSE arriving on cmdNotifyChar for diagnostic purposes.
                let ptype = frame.count > (isMav ? 8 : 4) ? frame[isMav ? 8 : 4] : 0
                if ptype == 36 {  // COMMAND_RESPONSE
                    BLEManager.logger.notice("CMD_RESP: cmd=\(frame.count > cmdOff ? frame[cmdOff] : 0, privacy: .public) len=\(frame.count, privacy: .public)")
                }
                if frame.count > cmdOff, frame[cmdOff] == WhoopCommand.getDataRange.rawValue,
                   let newest = BLEManager.dataRangeNewestUnix(from: frame) {
                    strapNewestTs = newest                        // feeds the liveness watchdog
                    BLEManager.logger.notice("BF: GET_DATA_RANGE newest=\(newest, privacy: .public) (\(Date(timeIntervalSince1970: TimeInterval(newest)), privacy: .public))")
                }
                // FF key exchange — handle START_FF_KEY_EXCHANGE and SEND_NEXT_FF responses.
                // The WHOOP 5.0 ignores SEND_HISTORICAL_DATA until this exchange completes.
                // Sequence: START_FF_KEY_EXCHANGE → (strap) → SEND_NEXT_FF×N → SET_FF_VALUE×N → ready.
                if frame.count > cmdOff {
                    let respCmd = frame[cmdOff]
                    if respCmd == WhoopCommand.startFFKeyExchange.rawValue && ffExchangePending {
                        // Response body (Maverick): [cmd=0x75][?][status][flag][numFF][0x00]
                        // Verified from PacketLogger 2026-06-01: bytes=[75 07 01 01 0F 00] → numFF at payloadOff+3
                        let payloadOff = isMav ? 11 : 7
                        let numFF = frame.count > payloadOff + 3 ? Int(frame[payloadOff + 3]) : 15
                        ffRoundsRemaining = max(numFF, 0)
                        ffNames = []
                        BLEManager.logger.notice("BF: FF exchange started, \(self.ffRoundsRemaining, privacy: .public) entries")
                        if ffRoundsRemaining > 0 {
                            sendNextFFRound()
                        } else {
                            setFFValues()  // numFF=0 means device already has FF state; skip pull, send SET
                        }
                    } else if respCmd == WhoopCommand.sendNextFF.rawValue && ffRoundsRemaining > 0 {
                        // Response body: [cmd=0x76][idx][flag1][flag2][enabled][name_ascii][zeros]
                        // Verified: name starts at frame[15] (nameOff=15), not frame[12].
                        let nameOff = isMav ? 15 : 11
                        if frame.count > nameOff {
                            let endOff = frame.count - 4  // strip 4-byte CRC trailer
                            if endOff > nameOff {
                                let nameBytes = frame[nameOff ..< endOff]
                                if let name = String(bytes: nameBytes, encoding: .utf8)?
                                    .trimmingCharacters(in: .controlCharacters)
                                    .trimmingCharacters(in: CharacterSet(charactersIn: "\0")),
                                   !name.isEmpty {
                                    ffNames.append(name)
                                }
                            }
                        }
                        ffRoundsRemaining -= 1
                        if ffRoundsRemaining > 0 {
                            sendNextFFRound()
                        } else {
                            // All FF entries pulled — now SET_FF_VALUE to enable them.
                            setFFValues()
                        }
                    }
                }
                // Clock correlation runs in both live and backfill modes. Once established it
                // unblocks both the Collector (live path) and the Backfiller (chunk decoding).
                if clockRef == nil {
                    let parsed = parseFrame(frame)
                    if let ref = ClockCorrelation.clockRef(from: parsed, wall: Int(Date().timeIntervalSince1970)) {
                        clockRef = ref
                        collector?.clockRef = ref                  // unblocks buffered persistence
                        backfiller?.clockRef = ref                 // unblocks historical chunk decode
                        log("Clock correlated: device=\(ref.device) wall=\(ref.wall)")
                        // Conditional SET_CLOCK (mirrors WHOOP): only when the strap RTC has drifted /
                        // is frozen — not blindly every connect. Offload doesn't depend on this (it uses
                        // clockRef for decoding); SET_CLOCK only keeps FUTURE logging timestamps sane.
                        if ClockPolicy.shouldSetClock(deviceClock: ref.device, wallNow: ref.wall) {
                            log("Clock drift detected — issuing SET_CLOCK")
                            send(.setClock, payload: BLEManager.setClockPayload())
                        }
                    }
                }
                if backfilling {
                    if BLEManager.isOffloadFrame(frame) {
                        armBackfillTimeout()
                        routeBackfillFrame(frame)
                    }
                } else {
                    collector?.ingest(frame)
                }
            }
        default:
            break
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didUpdateNotificationStateFor characteristic: CBCharacteristic,
                           error: Error?) {
        if let error = error {
            log("Notify state FAILED \(characteristic.uuid.uuidString.prefix(8)): \(error.localizedDescription)")
        } else {
            log("Notify state OK \(characteristic.uuid.uuidString.prefix(8)): isNotifying=\(characteristic.isNotifying)")
        }
    }
}
