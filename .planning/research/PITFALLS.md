# Domain Pitfalls — WHOOP 5.0 BLE Reverse Engineering

**Domain:** Wearable BLE protocol RE + iOS local-first client
**Researched:** 2026-05-30
**Researcher confidence:** MEDIUM-HIGH (heavy reliance on direct lessons captured in the project's own `FINDINGS.md` from the 4.0 RE, supplemented by Apple docs, Nordic docs, and community sources)

> **Source bias note:** the highest-value pitfalls below are recapitulations of mistakes the project already made on the 4.0 effort, documented in `FINDINGS.md`. They are HIGH confidence specifically because they already happened. Externally sourced items are flagged as MEDIUM unless backed by Apple or Nordic docs.

---

## Critical Pitfalls

### Pitfall 1: Assuming 5.0 frame format == 4.0 frame format

**What goes wrong:** Reusing `whoomp/WhoopPacket` (the 4.0 `[0xAA][len u16 LE][crc8][type u8][seq u8][cmd u8][payload][crc32 LE]` framing) as the parser, then "decoding" 5.0 traffic that happens to start with `0xAA` and getting plausible-but-garbage results.

**Why it happens:** The user *just* finished 4.0, so the 4.0 framing is the reflexive mental model. tazjin's Gadgetbridge #5731 thread says 5.0 IMU is still "6 integers (X/Y/Z per sensor)", which biases everyone toward assuming framing carried over too. The fields can match while the framing is different (e.g. different sync byte, different CRC poly, different length-field endianness, different per-fragment header).

**Consequences:**
- Hours-to-days wasted on a wrong parser before realising every fourth packet "fails CRC"
- Schema (`whoop_protocol_5.json`) gets locked in around a hallucinated layout
- Decoded sample arrays look "almost right" (waveforms exist!) but scales and channel order are off → silently bad biometrics

**Prevention:**
1. **Falsify the assumption first.** Take 20 captured frames from 5.0 across different packet types and *prove* that whoomp's CRC8(len) and CRC32(zlib over type|seq|cmd|payload) validate. If even one validation fails for an otherwise-well-formed packet, the frame format changed.
2. **Compute byte-1 histogram on every captured PDU.** If `0xAA` is not the dominant first byte of CMD/notify writes, the sync byte changed.
3. Look at fragmentation pattern: 4.0 fragments at ~244 B with only the first fragment carrying `0xAA`. If 5.0 fragments differently (e.g. every fragment carries a header), this is a different transport layer (possibly L2CAP CoC instead of GATT notifications).

**Detection signals:**
- CRC32 mismatch rate >1% on what should be normal traffic
- "Length" header value inconsistent with actual byte count delivered
- First-fragment-only `0xAA` pattern absent
- Notifications coming on a characteristic UUID that doesn't end in `05` (4.0's data char)

**Phase:** Phase 1 — Frame Format Confirmation. **This is the single highest-leverage early check.**

---

### Pitfall 2: Capturing on an encrypted/bonded link without the LTK → opaque traffic

**What goes wrong:** You sniff over-the-air with an nRF52840 Dongle (or use Android btsnoop) on a link that has already negotiated encryption from a prior bonding. Packets are captured but ATT payloads are AES-CCM ciphertext — totally unreadable. You spend a day debugging "weird random bytes" before realising the link is encrypted.

**Why it happens:** The 4.0 finding is explicit: "the custom service requires a bonded/encrypted link. Unbonded, those characteristics deliver nothing." For 5.0 this almost certainly carries over. Over-the-air sniffers see the encrypted Link Layer; without the LTK (Long-Term Key) or pairing key material, the decoder can't recover plaintext.

**Consequences:**
- Wasted capture sessions
- False conclusion that "the protocol is encrypted at the application layer" (it isn't — it's just BLE link encryption)
- Schema work blocked

**Prevention:**
1. **Use the HCI snoop log, not the over-the-air sniffer, as the primary source.** HCI snoop sits *above* link-layer encryption on the host stack, so it always sees plaintext ATT writes/notifications. This is true for both:
   - macOS PacketLogger (paired iPhone → Mac via Xcode)
   - Android btsnoop_hci.log
2. **If you must use nRF Sniffer**, you must capture the pairing handshake (Secure Connections key exchange) from a clean unpaired state, then feed the derived LTK to Wireshark's BLE protocol preferences (Edit → Preferences → Protocols → BT SMP / BT LE). nRF Sniffer for BLE supports providing encryption keys in the Wireshark plugin UI specifically for this. ([Nordic nRF Sniffer for Bluetooth LE](https://www.nordicsemi.com/Products/Development-tools/nrf-sniffer-for-bluetooth-le))
3. **Always document the bonded/unbonded state of every capture file.** A captured `.pklg` or `.btsnoop` that crossed a pairing event in the middle has two regimes and must be split.

**Detection signals:**
- ATT payloads exhibit high byte entropy (~7.9 bits/byte, indistinguishable from random) → encrypted
- The 4.0 PPG packet was 2.5 bits/byte (FINDINGS §9b); a real plaintext payload will be similar
- No `0xAA` sync byte anywhere
- ATT_Write packets size is constant 16 or 17 bytes (telltale of fixed-size encrypted blocks)

**Phase:** Phase 0 — Capture Setup. Validate plaintext-recoverability before starting analysis.

---

### Pitfall 3: PacketLogger / btsnoop missing the bond handshake and connection-parameter negotiation

**What goes wrong:** You start the capture *after* connecting in the official WHOOP app. You then never see:
- The SMP pairing/bonding exchange (so you can't replicate it from scratch)
- The initial `LL_CONNECTION_PARAM_REQ` / `LL_FEATURE_REQ` (so you don't know the connection interval, supervision timeout, or supported PHY)
- The MTU exchange (`ATT_EXCHANGE_MTU_REQ/RSP`) — so you don't know the negotiated MTU and your fragmentation assumptions are wrong
- Service discovery (`READ_BY_GROUP_TYPE_REQ`) — so you may miss services the app discovers but doesn't actively use

**Why it happens:** Convenient workflow is "open app, see it connected, then start logger." The first ~2 seconds of a BLE connection are the most information-dense.

**Consequences:**
- Cannot reproduce bonding from your own client (the FINDINGS bonding trick — "issue one confirmed write" — was only discoverable because someone captured the encryption handshake)
- Wrong MTU → wrong fragment size → reassembly fails on edge cases
- Missing services means missing capabilities (e.g. a hidden DFU/firmware-update service that uses different framing)

**Prevention:**
1. **Force the official app to do a fresh bonding**: in the WHOOP app, "Forget device" / re-add, OR power-cycle the strap before each forensic capture session.
2. **Start the logger first, then open the app, then connect.** Lead by 5+ seconds.
3. **For PacketLogger:** check the "HCI Commands and Events" filter is on; the SMP/encryption events come through HCI commands, not just ACL data.
4. **For Android btsnoop:** toggle "Bluetooth HCI snoop log" *off then on* in Developer Options, then toggle Bluetooth on the phone off then on. The btsnoop file rotates on each Bluetooth cycle. Pull the log immediately after capture — see Pitfall 5 on rotation.
5. **Verify the capture contains** SMP packets (opcodes `0x01`–`0x0F`), `LL_FEATURE_REQ`, `LL_CONNECTION_PARAM_REQ`, and `ATT_EXCHANGE_MTU_REQ`. If any are missing, the capture is partial.

**Detection signals:**
- No SMP traffic in pcap
- ATT MTU not set (defaults to 23) — but you see 244-byte fragments → you captured post-MTU-exchange
- No service discovery → you can't list characteristics from the capture alone

**Phase:** Phase 0 — Capture Setup, plus a checklist gate before any capture is considered "valid".

---

### Pitfall 4: Mistaking device epoch for Unix epoch when correlating timestamps

**What goes wrong:** `REALTIME_DATA` packets carry a u32 "timestamp" field. You read it as Unix epoch, get years like 1971 or 2106, and either:
- Conclude the timestamps are corrupted, or
- "Fix" them with a magic constant that happens to work for one session but breaks across reboots.

**Why it happens:** The 4.0 finding nails this: "`GET_CLOCK` (11) returns device clock, **own epoch** (~31.5M), NOT unix — correlate to wall-clock at capture." But `GET_DATA_RANGE` returns *real Unix* timestamps (from last phone sync). So *some* fields are Unix and some are device-relative, in the same protocol. This is dangerously easy to conflate.

**Consequences:**
- Historical data gets stamped to wrong wall-clock times
- HRV / sleep correlation against other data (Apple Health, calendar) is silently wrong
- "Mid-session strap reboot" → device epoch resets → all subsequent records in the same offload are mis-timed unless detected (already a known M3 limitation in FINDINGS §11)

**Prevention:**
1. **Capture wall-clock and `GET_CLOCK` at the moment you open the BLE session**, store as `(wall_clock_ref, device_clock_ref)`. Every device-relative timestamp gets converted via `unix = wall_clock_ref + (ts - device_clock_ref)`.
2. **Re-fetch `GET_CLOCK` after every reconnect.** Never reuse a `clockRef` across BLE disconnects, and never across app process boundaries.
3. **Detect strap reboot**: monitor the device clock for monotonicity; a clock that decreases or jumps back to ~0 within one session = reboot, invalidate `clockRef`.
4. **Treat historical-offload timestamps as a separate domain**: the `HISTORY_END` payload `[unix u32][subsec u16]...` is real Unix (sync'd from phone). Document this in the schema.
5. **Mark schema fields explicitly:** add `"epoch": "device" | "unix"` to every timestamp field in `whoop_protocol_5.json`. Decoder fails loudly if absent.

**Detection signals:**
- Decoded year < 2010 or > 2050 → wrong epoch
- Timestamp delta between consecutive packets not ≈ 1 s / 2 s (depending on stream) → corruption or wrong field offset
- Two timestamps in the same packet that diverge by ~10^9 seconds → one is Unix, one is device

**Phase:** Phase 2 — Decode (HR/RR + historical). Bake the dual-epoch model into the schema and decoder from day 1.

---

### Pitfall 5: Schema lock-in before the protocol surface is fully explored

**What goes wrong:** You write `whoop_protocol_5.json` after decoding the first 5 commands. You also write the Swift decoder against it. Then you discover command 81 (`START_RAW_DATA`) produces *two different packet sizes* (1917 vs 1921 bytes — exactly the 4.0 surprise per FINDINGS §6) that don't fit the schema's "one type, one layout" assumption. Refactoring cascades through Python decoder, Swift decoder, server ingest, fixtures.

**Why it happens:** Premature consolidation. The "schema-driven decode shared between Swift and Python" architecture is excellent but only after the protocol is mapped. Doing it during exploration treats the schema as a contract before it should be one.

**Consequences:**
- 2–3× engineering cost on every protocol revision
- Fixtures (golden test data) become invalid and have to be re-captured
- Decoder bugs introduced during refactors

**Prevention:**
1. **Two-phase schema discipline:**
   - **Exploration phase**: decoder is plain Python with hand-coded offsets, no schema. Capture-driven, throwaway.
   - **Consolidation phase**: only once command surface is closed (every observed packet type has a known layout), write `whoop_protocol_5.json` and the Swift decoder.
2. **Build in a `variant` / discriminator field per packet type.** The 4.0 had subtypes (`REALTIME_RAW_DATA` type 43 subtype 10); assume 5.0 has more. Schema should allow `{type: 43, when: {len: 1917}}` vs `{type: 43, when: {len: 1921}}`.
3. **Tolerate unknown fields**: decoder should return a `raw_tail: bytes` for any unparsed remainder, not throw. This lets you ship a partial decoder while iterating.
4. **Version the schema** (`"protocol_version": 1`). Old fixtures stay decodable under their original schema version.

**Detection signals:**
- Same packet type, two distinct sizes (FINDINGS §6 — already a known 4.0 pattern)
- Decoded fields have impossible values (HR=255, accel=0 for whole packet) → wrong subtype branch
- Schema needs a "fix" within 48 hours of being written

**Phase:** Phase 3 — Schema. Don't enter this phase until Phase 2 is *complete*, not just well underway.

---

### Pitfall 6: Historical backfill — incorrect `trim` cursor / ack logic

**What goes wrong:** The 4.0 historical-offload loop (`SEND_HISTORICAL_DATA` 22 → `HISTORY_START` → many `REALTIME_RAW_DATA` → `HISTORY_END` → ack with `HISTORICAL_DATA_RESULT` carrying `trim`) is a per-chunk ratchet. If your ack carries the wrong `trim` value, you either:
- Re-receive the same data forever (trim never advances → strap re-streams from same point), or
- **Permanently lose data** (trim advances past data you haven't durably stored → strap clears it from its buffer).

**Why it happens:** The 4.0 finding documents the wire format `[unix u32][subsec u16][unk0 u32][trim u32]` and the ack format `[0x01][trim u32][0x00000000]`. Easy to misalign byte offsets, easy to ack before storage commits to disk.

**Consequences:**
- **Irreversible data loss** if you ack before storing locally — the strap has limited buffer (FINDINGS shows ~weeks worth from Dec 2024 → 2025).
- Or infinite loops re-fetching the same history (waste of battery + time).

**Prevention:**
1. **Store-then-ack discipline.** The local SQLite/GRDB write must complete and fsync before sending `HISTORICAL_DATA_RESULT`. This is the single most important invariant for the whole local-first architecture.
2. **Idempotent ingest.** Use `(device_id, device_timestamp)` as primary key with `ON CONFLICT DO NOTHING` (already in FINDINGS §11). Then re-fetching the same chunk on a crash recovery is harmless.
3. **Log every (trim_sent, trim_received) pair**. If a session crashes mid-loop, you can reconstruct what was acked vs not.
4. **5.0-specific check:** confirm the trim/ack semantics in 5.0 match 4.0 by intentionally NOT acking one chunk and observing whether the strap re-sends it. If 5.0 has a different mechanism (e.g. a cursor sent in the request instead of an ack), the entire offload state machine differs.

**Detection signals:**
- Same packets re-arriving across reconnects → ack format wrong or trim value wrong
- `GET_DATA_RANGE` showing a window that *grows* between syncs even when the strap is being worn continuously — indicates failure to clear acked data, possibly wrong ack format
- Total bytes offloaded > device buffer size in a single session — re-streaming

**Phase:** Phase 4 — Historical Offload. Mark as high-risk in `PLAN.md`; require explicit data-loss simulation tests before deployment.

---

## Moderate Pitfalls

### Pitfall 7: Endianness assumptions in payload parsing

**What goes wrong:** Assuming everything is little-endian (because 4.0 framing CRC and length are LE) when the payload contains a big-endian field, or vice versa.

**Why it happens:** BLE itself is LE on the wire, but the *application* payload format is whatever the firmware authors chose. 4.0 mixes formats: timestamps are u32 LE, but BLE-standard Heart Rate `0x2A37` is a defined format with its own conventions. Multi-byte sensor packs can go either way; the 4.0 IMU is little-endian int16 per FINDINGS §9b.

**Prevention:**
- For every multi-byte field, **always test both endianness** against a known-truth reference (e.g. battery % which you can confirm against the app's UI, HR which you can confirm against the standard 0x2A37 channel).
- **Sanity-check ranges**: a u16 LE accel sample reading 32767 in a still device probably means you read it BE (or it's not the field you think it is).
- **Pin endianness per field in the schema** (`"endian": "little"`).

**Phase:** Phase 2 — Decode.

---

### Pitfall 8: Android btsnoop log rotation / silent truncation

**What goes wrong:** btsnoop_hci.log rotates at a size threshold (commonly 4 MB on AOSP, can be vendor-modified). A long capture session ends up with only the *last* slice. PPG/raw streams at ~960 B per 2 s burn through 4 MB quickly.

**Source:** Web search confirms: "Bluetooth HCI logs can grow quickly... limited internal storage can cause logging to stop silently or overwrite older data... Some devices rotate or overwrite the file when it reaches a size threshold." (MEDIUM confidence — multiple Android dev community sources)

**Prevention:**
- **Pull btsnoop_hci.log via adb every few minutes** during long captures: `adb pull /sdcard/btsnoop_hci.log` (path varies — also try `/data/log/bt/`, `/data/misc/bluetooth/logs/`).
- **Increase rotation size** where possible: `adb shell setprop persist.bluetooth.btsnoopsize 16777216` (16 MB) — requires a Bluetooth restart.
- **Prefer PacketLogger for long sessions** since macOS doesn't have the same hard rotation cap.
- **Always pull immediately** after a capture; never trust that the log is still there hours later.

**Detection signals:** capture file starts mid-stream (no SMP, no service discovery, first packet is a notification), or wall-clock duration covered by capture is shorter than session duration.

**Phase:** Phase 0 — Capture Setup.

---

### Pitfall 9: CoreBluetooth state preservation/restoration misconfigured → silent background failure

**What goes wrong:** App background-collects fine when tested in foreground, then silently stops collecting when the user puts the phone in their pocket. Or: app force-quit doesn't auto-reconnect.

**Source:** Apple Core Bluetooth Background Execution docs (HIGH confidence).

**Specific traps:**
1. **Missing `CBCentralManagerOptionRestoreIdentifierKey`** when initialising the `CBCentralManager` → no preservation, ever. Easy to forget on a refactor.
2. **`willRestoreState` must be called BEFORE any other delegate method on relaunch.** If the central manager isn't created until view-load time, restoration is missed.
3. **10-second background-wake budget** — heavy work on a connect callback (e.g. running a migration, decoding a huge batch) can get the app throttled or killed.
4. **`CBCentralManagerScanOptionAllowDuplicatesKey` is ignored in background** — duplicate-discovery-based reconnect logic that works in foreground silently breaks in background.
5. **Background scanning requires explicit service UUIDs in `scanForPeripherals(withServices:)`** — passing `nil` works in foreground only. Background scans for `nil` services are dropped.
6. **Service UUIDs go to advertisement "overflow area"** in background advertising — discoverability changes characteristics.

**Prevention:**
- Add the restore identifier on day 1 of iOS work, not as a polish step.
- `willRestoreState` test scenario is already in FINDINGS §11 ("Force-quit + relaunch") — keep that as a release gate.
- Defer heavy work in connect callbacks behind a background task / `BGProcessingTask`.
- Always scan with explicit service UUIDs `[CBUUID(string: "61080001-...")]` (or whatever 5.0's custom service ends up being).
- Test physical-device background behaviour weekly during M3 — never trust the simulator (which doesn't support CoreBluetooth at all).

**Phase:** Phase 5 — iOS Client (Background Collection).

**Sources:**
- [Apple — Performing Tasks While Your App Is in the Background](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html)

---

### Pitfall 10: MTU negotiation differs across iOS versions / strap firmware

**What goes wrong:** You see 244-byte fragments on the Mac capture (MTU 247) and assume that's universal. Then a user on a different iOS minor version sees 185-byte fragments (MTU 188 or whatever Apple decided that year), and your reassembler — which assumes a max fragment size — silently truncates or mis-aligns.

**Why it happens:** Apple has historically tuned the negotiated MTU per iOS release; 5.0 firmware may also have its own preferences. The 4.0 finding documents "~244-byte fragments" but doesn't pin the MTU as immutable.

**Prevention:**
- **Read the actual negotiated MTU at runtime** via `peripheral.maximumWriteValueLength(for: .withResponse)` and use it in the reassembler.
- **Reassemble by the length header in the protocol**, not by counting fragments — the 4.0 framing already has a u16 length, use it as the source of truth.
- **Test on iOS 16 (oldest supported per PROJECT.md), 17, 18, 26** if available — capture MTU each time.
- **Document the observed MTU per capture** in the metadata sidecar.

**Phase:** Phase 5 — iOS Client.

---

### Pitfall 11: Firmware updates changing the protocol mid-RE effort

**What goes wrong:** You decode 5.0 protocol against firmware 50.32.x. WHOOP pushes 50.36.1.0 (real version per community forums) and packet layouts shift (e.g. accuracy improvements per [the5krunner Oct 2025](https://the5krunner.com/2025/10/06/whoop-5-0-gets-unusual-new-firmware-accuracy-boost-2/) suggesting different sensor channel weighting). Your decoder produces subtly-wrong values for users on the new firmware.

**Source:** WHOOP firmware update community discussions (MEDIUM confidence on the rate of change; LOW confidence on which specific updates touched BLE wire format).

**Prevention:**
- **Pin firmware version in every capture's metadata** (read via `REPORT_VERSION_INFO` equivalent — for 4.0 it's command 7 returning `harvard 41.16.6.0, boylston 17.2.2.0`).
- **Maintain a firmware-version → schema-version map** in `whoop_protocol_5.json` (`"min_fw": "50.32.0.0"`).
- **If the device auto-updates mid-session**, invalidate all subsequent decode and warn the user. Don't silently keep recording with a now-wrong schema.
- **Capture a fresh golden fixture after every firmware bump** the user observes. The user's own device will eventually update; that captured-traffic delta is the most valuable signal for whether wire format changed.
- **Watch for protocol commands that return `0a 03` (unsupported)** vs `0a 01` (ok) — a command going from ok to unsupported between firmware versions = a firmware-driven protocol drop.

**Phase:** Cross-cutting. Add a "firmware version" column to every captured-data table.

---

### Pitfall 12: Legal — DMCA §1201(f) interoperability defence is conditional, not blanket

**What goes wrong:** Treating "I'm doing interoperability research" as a magic shield. It isn't — the §1201(f) exemption has specific conditions: the elements you reverse-engineer must (1) not already be available, (2) be used solely to achieve interoperability, (3) not enable infringement.

**Source:** Project's own `DISCLAIMER.md` is already aligned with this; the pitfall is in execution, not in intent.

**Specific traps:**
- Reproducing **WHOOP firmware bytes or APK strings** (even small snippets) in a public repo would void the defence — currently the project disclaimer explicitly forbids this (DISCLAIMER §2). Stay strict.
- **Distributing a tool that lets users break the WHOOP subscription paywall** (e.g. computing recovery scores that the paid app provides) is a grey area. Read-only access to your own raw biometrics is defensible; cloning the subscription product is risky.
- **WHOOP ToS prohibits reverse engineering** — ToS is contract, separate from copyright law. Violating ToS doesn't make you a copyright infringer, but WHOOP could terminate your subscription / brick your device via firmware. This isn't a "stop" signal, but it's a risk to flag to users.
- **Publishing captured BLE traffic that contains the user's own biometric data** is fine for the user, but if shared publicly, it may include device serial / MAC and accidentally identifying info. Sanitise fixtures (FINDINGS already uses `<DEVICE_SERIAL>` / `<DEVICE_UUID>` placeholders — keep this discipline).

**Prevention:**
- Maintain the DISCLAIMER.md as-is; review at each milestone.
- **Never commit raw .pklg / .btsnoop capture files** — they contain serials, MACs, possibly nearby-device addresses. Sanitise to JSONL with PII removed before committing fixtures.
- **Personal use only framing**: keep README clear that this is single-user, single-device, no third-party hosting.
- If the project ever ships a binary distribution (Mac app, App Store iOS app), revisit the legal posture with a lawyer; distributing materially changes the analysis.

**Phase:** Cross-cutting. Verify at every milestone gate.

---

## Minor Pitfalls

### Pitfall 13: Trusting community/AI-scaffolded repos uncritically

**What goes wrong:** Importing UUIDs / command numbers from a repo that *looks* authoritative but is hallucinated.

**Why it happens:** FINDINGS §2 explicitly calls this out: "The `whoop-reader` repo's UUID map is **shifted by one and wrong** (it calls `61080000` the service). It is fabricated." And §7 marks `christianmeurer/whoop-reader` as "**Fabricated/AI-scaffold.** Wrong UUIDs, invented commands, speculative byte table."

**Prevention:** every borrowed constant gets validated against live capture before being trusted. `whoomp` and `bWanShiTong` are validated reference points for 4.0; for 5.0, only `tazjin / Gadgetbridge #5731` is known and the code is unpublished. Treat everything as hypothesis until your own capture confirms.

**Phase:** Phase 1 onward.

---

### Pitfall 14: Reassembly logic that parses per-notification

**What goes wrong:** Decoder treats each BLE notification as a complete packet. Works for small commands. Silently drops or mis-parses any packet bigger than the MTU (raw IMU/PPG at ~1920 B).

**Why it happens:** Most BLE tutorials show one-notification = one-message. The 4.0 finding flags this exactly: "BLE reassembly is mandatory... whoomp parses per-notification and therefore misses these."

**Prevention:**
- Reassembly engine must be in place before attempting any raw-data decode.
- Test fixtures must include at least one ≥1KB packet to exercise reassembly.

**Phase:** Phase 2 — Decode.

---

### Pitfall 15: Confusing "no on-device analytics" with "no on-device computation"

**What goes wrong:** FINDINGS §6 / tazjin: "the device does no analytics on-device (all HRV/sleep/strain is cloud-side)." Easy to extrapolate: "so SpO2 and skin temp must be on the wire." They aren't — FINDINGS §9b: "SpO2 / skin-temp computed VALUES: NOT in the BLE stream." Computed cloud-side from raw PPG.

**Prevention:** be specific about what "no analytics" means: the *aggregate scores* are cloud-side, but *some lower-level processing* (e.g. heart rate detection from PPG) does happen on-device or in firmware. Don't assume one or the other; verify per signal.

**Phase:** Phase 2 — Decode.

---

### Pitfall 16: Battery-level event under-sampling collapsing rows

**What goes wrong:** FINDINGS §11 already documents this as a known M3 limitation: `COMMAND_RESPONSE` battery readings have no device timestamp, get stamped at `wallClockRef`, and `ON CONFLICT DO NOTHING` collapses multiple reads in one clock-correlation window. Cosmetic now, but if 5.0 has additional battery-derived telemetry (e.g. charge-cycle counter, thermal events), this collapse could lose useful data.

**Prevention:** if the field is one you actually want fine-grained, store with a row-level sequence number, not just `(device_id, ts)`.

**Phase:** Phase 4 — Storage schema design.

---

## Phase-Specific Warnings

| Phase | Likely Pitfall | Mitigation |
|---|---|---|
| **Phase 0 — Capture Setup** | Encrypted link, missing handshake, btsnoop rotation, no firmware version recorded | Pre-capture checklist; pull logs frequently; record fw version + bonded state in every capture metadata |
| **Phase 1 — Frame Format Confirmation** | Assume 4.0 framing carries over | Run whoomp parser against 20 5.0 frames; fail-fast if CRC mismatch >1% |
| **Phase 2 — Decode (HR/RR/Events)** | Endianness, epoch confusion, per-notification parsing | Schema-enforced endian/epoch tags; reassembler from day 1 |
| **Phase 3 — Schema Consolidation** | Premature lock-in, no variant discriminator | Don't enter this phase until command surface is closed; design for subtypes |
| **Phase 4 — Historical Offload** | Wrong trim/ack semantics → data loss | Store-then-ack discipline; idempotent ingest; data-loss simulation tests |
| **Phase 5 — iOS Client** | CoreBluetooth restore identifier missing, scan-with-nil-services in background, MTU assumption | Configure restore identifier on day 1; always scan with explicit UUIDs; read MTU at runtime |
| **Phase 6 — Server Sync** | (See `PITFALLS_iOS.md` if/when created) | — |
| **Cross-cutting** | Firmware drift, legal posture drift, trusting unverified sources | FW version in every row; DISCLAIMER review per milestone; constants verified against live capture |

---

## Sources

- **`FINDINGS.md`** (this project, 4.0 RE) — HIGH confidence on every pitfall it directly documented; this is the single most valuable source because it captures mistakes already paid for.
- **`DISCLAIMER.md`** (this project) — HIGH confidence on the legal framing; aligns with §1201(f).
- **[Apple — Core Bluetooth Background Execution](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html)** — HIGH confidence on CoreBluetooth background constraints, state preservation, the 10-second wake budget, scan/advertise restrictions.
- **[Nordic Semiconductor — nRF Sniffer for Bluetooth LE](https://www.nordicsemi.com/Products/Development-tools/nrf-sniffer-for-bluetooth-le)** — HIGH confidence on encrypted-capture workflow (LTK + Wireshark plugin).
- **[Gadgetbridge issue #5731 — tazjin on WHOOP 5.0 IMU](https://codeberg.org/Freeyourgadget/Gadgetbridge/issues/5731)** — MEDIUM confidence (single source, unpublished code); useful prior art but not validated independently.
- **[WHOOP firmware release notes / community](https://support.whoop.com/s/topic/0TO6Q000000gQcmWAE/firmware-release-notes)** — MEDIUM confidence on which firmware versions exist; LOW confidence on whether any specific update changed BLE wire format (WHOOP doesn't publish that level of detail).
- **[the5krunner — WHOOP 5.0 firmware accuracy boost (Oct 2025)](https://the5krunner.com/2025/10/06/whoop-5-0-gets-unusual-new-firmware-accuracy-boost-2/)** — MEDIUM confidence on existence of sensor-processing changes via firmware; LOW confidence on wire-format implications.
- Android btsnoop community knowledge — MEDIUM confidence on rotation behaviour; varies by OEM and Android version.

---

## Gaps / Open Questions

These could not be verified at research time and should be flagged for phase-specific deeper research:

1. **Does WHOOP 5.0 use the same custom service UUID `61080001-8d6d-82b8-614a-1c8cb0f8dcc6` as 4.0?** PROJECT.md correctly identifies this as the first test. Until captured, treat as unknown.
2. **Has WHOOP introduced LE Secure Connections numeric comparison** (vs 4.0's "just works" bonding triggered by a confirmed write)? If so, the bonding trick from FINDINGS §1 won't work and a different pairing path is needed.
3. **Does WHOOP 5.0 use L2CAP Connection-Oriented Channels (CoC)** for high-throughput streams instead of/in addition to GATT notifications? CoC has totally different framing and would invalidate the GATT-notification reassembly approach.
4. **Specific firmware versions that altered wire format** — not publicly documented; only discoverable by capturing across an observed firmware bump on the user's own device.
5. **iOS 26 / latest CoreBluetooth API changes** beyond the cited archive doc — Apple may have new background-mode constraints in recent SDKs. Worth a check during Phase 5.
