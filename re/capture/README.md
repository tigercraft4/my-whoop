# Capture runbooks

Passive HCI-capture tooling and evidence for WHOOP 5.0 BLE traffic. This directory is the
capture counterpart to the active Bleak RE harness in `../` — it provides step-by-step
runbooks for recording raw HCI frames from iOS (PacketLogger) and Android (HCI snoop), plus
host-side analysis workflows in Wireshark and JADX. The authoritative protocol findings are
in `../../FINDINGS.md`; this directory covers only the capture mechanics. For the broader RE
context see `../README.md`.

---

## Runbooks

| File | Requirement | Capture source | What it covers |
|------|-------------|----------------|----------------|
| [ios-packetlogger.md](ios-packetlogger.md) | TOOL-01 | iPhone tethered via USB | PacketLogger install (Additional Tools for Xcode DMG), `iOSBluetoothLogging.mobileconfig`, Xcode device pairing, live HCI stream, evidence triplet |
| [android-btsnoop.md](android-btsnoop.md) | TOOL-02 | Android phone via adb | Developer Options HCI snoop, short-session buffer discipline, `adb bugreport` extraction, evidence triplet |
| [wireshark.md](wireshark.md) | TOOL-04 | Host (Mac) | Open `.pklg`/`.btsnoop` in Wireshark 4.4.x, ATT/GATT filter (`btatt`), non-empty-trace verification, redaction + SHA256 workflow |
| [jadx.md](jadx.md) | TOOL-03 | Host (Mac) | Pull WHOOP APK via `adb shell pm path`, decompile in JADX-GUI 1.5.1, navigate Maverick/packet-type enum definitions |

---

## Evidence checklist — Phase 1 success criteria

The four Phase 1 success criteria and their committed evidence artifacts:

**Criterion 1 — iOS ATT-layer traffic visible during live WHOOP session** (TOOL-01)

- [x] `evidence/2026-05-30-ios.hex` — redacted ATT-payload hex excerpt (BD_ADDR scrubbed)
- [x] `evidence/2026-05-30-ios.sha256` — SHA256 of the gitignored `.pklg` in `samples/`
- [x] `evidence/2026-05-30-ios.meta.yaml` — session metadata sidecar: 1011 btatt packets,
  0xAA SOF confirmed on all ATT payloads, characteristic handles 0x099b (cmd-in write) /
  0x099d / 0x09a3 (notifications), firmware iOS 26.3.1, `fd4b0001-...` service family

**Criterion 2 — Android `btsnoop_hci.log` captured with BTATT frames** (TOOL-02)

- [ ] No Android device available for this session. The runbook (`android-btsnoop.md`) is
  complete and reproducible; an evidence triplet will be added here when an Android device
  is available.

**Criterion 3 — Wireshark opens captured files and shows WHOOP custom service traffic** (TOOL-04)

- [x] Covered by the iOS evidence: `tshark -r <session>.pklg -Y btatt` produced 1011 rows.
  The redacted hex in `evidence/2026-05-30-ios.hex` was extracted via the workflow in
  `wireshark.md`. The Wireshark runbook is complete and confirmed against a live capture.

**Criterion 4 — JADX-GUI loads WHOOP Android APK and exposes Maverick/packet-type enum definitions** (TOOL-03)

- [ ] APK decompilation not performed in this session (no Android device available). The JADX
  runbook (`jadx.md`) is complete. Enum name/value notes will be added here per the legal
  recording rule in `jadx.md` when an APK is loaded.

---

## Commit policy (D-02 / D-04 / DISCLAIMER §2)

**Raw captures and decompiled APK output are GITIGNORED and never committed.**

```
re/capture/samples/    <-- gitignored (raw .pklg, .btsnoop, APK/JADX output live here)
re/capture/evidence/   <-- committed (redacted hex + SHA256 + metadata sidecar only)
```

Only three file types may be committed under `evidence/`:

| Extension | Content |
|-----------|---------|
| `.hex` | Redacted payload hex slice — BD_ADDR and SMP key material scrubbed |
| `.sha256` | SHA256 of the gitignored raw capture file in `samples/` |
| `.meta.yaml` | Session metadata sidecar (schema below) |

Never commit a raw `.pklg`, `.btsnoop`, decompiled Java/Smali, or any file that could contain
device identity (BD_ADDR, IMEI) or cryptographic material (LTK, IRK, SMP exchanges). The root
`.gitignore` enforces this with `re/capture/samples/*` (keeping only `.gitkeep`) and the
`apk/` rule.

---

## Metadata sidecar schema (Phase 2–3 contract)

Each evidence session has a `.meta.yaml` sidecar. This is the provenance contract consumed by
Phase 2 (GATT survey) and Phase 3 (framing confirmation / CRC gate):

```yaml
source: ios           # ios | android
tool: PacketLogger    # PacketLogger | btsnoop
tool_version: "x.y"
firmware: "<iOS or Android firmware version from ideviceinfo / device About>"
captured: 2026-05-30
raw_sha256: <sha256 of the gitignored raw capture in samples/>
custom_service_uuid_seen: "<fd4b0001-... | 61080001-... | none-yet>"
inner_frame_sof: "0xAA — confirmed | not yet checked"
att_packet_count: <integer>
notes: "Free-text provenance: ATT/GATT traffic present, BD_ADDR scrubbed, ..."
```

The `firmware` field pre-stages the PROTO-16 firmware-per-session requirement. Phase 3 uses
`inner_frame_sof` and `att_packet_count` as framing-gate evidence inputs.
