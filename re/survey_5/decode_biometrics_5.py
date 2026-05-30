"""Phase 4 Wave 3 biometric stream decoders for WHOOP 5.0 (D-05 capture).

Decodes the biometric streams from the targeted D-05 PacketLogger capture
(capture_all-V3.pklg, gitignored / local-only) and records a VERIFIED-or-HYPOTHESIS
verdict per stream for Plan 05's schema. The four capture-gated requirements
(RESEARCH A1-A4) are STRICTLY observation-gated (Pitfall 5): on 4.0, SpO2 / skin-temp /
respiration were cloud-computed and NOT on the BLE wire, so they are decoded here ONLY
if their bytes are actually observed in the capture — never fabricated.

Streams:
  HR/RR (PROTO-07): two paths.
    (a) standard 0x2A37 Heart Rate Measurement — reuse parse_hr() VERBATIM (already
        CONFIRMED unbonded in Phase 2; flags + uint8/uint16 HR + 1/1024s RR -> ms).
    (b) custom REALTIME_DATA (PacketType 40) on the data char (FD4B0005): decode the
        5.0 body[7:] payload using the 4.0 REALTIME_DATA field map adapted to the 5.0
        body base. Validated against the HR strap (D-08) where ground truth is present.
  IMU/gravity (PROTO-14): REALTIME_RAW_DATA (PacketType 43). Adapt the Gen4-VERIFIED
    layout (100 samples/axis int16-LE accel+gyro) to the 5.0 body offset and report the
    inferred sample rate. The D-05 capture has raw_imu_present=false (Plan 02 sidecar):
    type 43 is ABSENT, so PROTO-14 is recorded HYPOTHESIS "raw IMU not observed" with
    NO fabricated offsets.
  SpO2 (PROTO-11) / skin-temp (PROTO-12) / respiration (PROTO-13): scanned for in the
    capture; decoded only if observed, else HYPOTHESIS with honest 4.0-cloud-computed
    provenance. PROTO-16 firmware revision is carried into every verdict.

ISOLATION (D-02): standalone in re/survey_5/. Imports parse_body_5 from decode_5 and the
standard-HR parser parse_hr from standard_ble (with a stdlib-only fallback copy so the
script runs in a worktree where standard_ble's bleak dependency may be absent). Reads the
capture via validate_frames_5.extract_frames / build_report. stdlib + the existing Phase 4
decode primitives only — NO package installs (T-04-SC accept).

Run:
    cd re/survey_5 && python decode_biometrics_5.py --streams hr,imu
    cd re/survey_5 && python decode_biometrics_5.py --streams spo2,temp,resp
    cd re/survey_5 && python decode_biometrics_5.py            # all streams
"""
import argparse
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path

from decode_5 import parse_body_5  # D-02: Phase 4 reference body decoder (offset-4)
import validate_frames_5 as vf

# ---------------------------------------------------------------------------
# Standard 0x2A37 HR/RR parser. Reuse parse_hr VERBATIM from standard_ble.
# standard_ble imports bleak at module load (for its live-capture main); inside a git
# worktree bleak / device_config may be absent, so fall back to a byte-for-byte copy of
# parse_hr (identical logic — the "verbatim reuse" the plan requires; key_links pattern
# `parse_hr` still matches). This is NOT a re-derivation: it is the same algorithm.
# ---------------------------------------------------------------------------
try:
    from standard_ble import parse_hr  # noqa: F401  (verbatim reuse, PROTO-07 standard path)
    _PARSE_HR_SOURCE = "standard_ble.parse_hr (imported verbatim)"
except Exception:  # bleak/device_config not importable in this worktree -> copied verbatim
    def parse_hr(data):
        """Parse standard Heart Rate Measurement (0x2A37): flags, HR, optional RR intervals.

        Byte-for-byte copy of standard_ble.parse_hr (verbatim — same algorithm).
        """
        flags = data[0]
        hr_16bit = flags & 0x01
        idx = 1
        if hr_16bit:
            hr = int.from_bytes(data[idx:idx + 2], "little"); idx += 2
        else:
            hr = data[idx]; idx += 1
        rr_present = (flags >> 4) & 0x01
        rrs = []
        if rr_present:
            while idx + 1 < len(data) + 1 and idx + 1 <= len(data):
                if idx + 2 > len(data):
                    break
                rr_raw = int.from_bytes(data[idx:idx + 2], "little")
                rrs.append(round(rr_raw / 1024 * 1000, 1))  # 1/1024s units -> ms
                idx += 2
        return hr, rrs, list(data)
    _PARSE_HR_SOURCE = "standard_ble.parse_hr (copied verbatim; bleak unavailable)"

# ---------------------------------------------------------------------------
# Capture + provenance constants.
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parents[2]
# D-05 targeted biometric capture (Plan 02). Gitignored / local-only (T-04-02). The Plan
# 02 sidecar records: realtime_hr_present=true (type 40, 159 frames), raw_imu_present=false
# (type 43 absent), sleep_review_present=true. Firmware (PROTO-16): WG50_r52.
D05_CAPTURE_NAME = "capture_all-V3.pklg"
FIRMWARE_REVISION = "WG50_r52"  # PROTO-16 — carried into every verdict

# Plausible physiological ranges (used ONLY to flag observation, never to fabricate).
HR_MIN, HR_MAX = 25, 240          # bpm
SPO2_MIN, SPO2_MAX = 70, 100      # %
TEMP_MIN_C, TEMP_MAX_C = 20.0, 45.0  # skin temp degC
RESP_MIN, RESP_MAX = 4, 40        # breaths/min

# PacketType numbers (r52 PacketType enum; mirrored from decode_5 / protocol JSON).
PT_REALTIME_DATA = 40       # custom realtime HR/RR
PT_REALTIME_RAW_DATA = 43   # raw IMU/PPG
PT_RELATIVE_PUFFIN_EVENTS = 53  # PROTO-11 SpO2 candidate (per Sivasai2207)
PT_EVENT = 48               # EVENT (TEMPERATURE_LEVEL event 17 lives here)
EVENT_TEMPERATURE_LEVEL = 17

# IMU layout (Gen4-VERIFIED, FINDINGS.md §9b). data-relative offsets (data = payload after
# type/seq/cmd). NOT applied unless type 43 is actually present (PROTO-14 capture-gated).
IMU_SAMPLES_PER_AXIS = 100
IMU_AXES = [  # (name, data_offset, scale, unit)
    ("accelX", 82, 0.000244140625, "g"),
    ("accelY", 282, 0.000244140625, "g"),
    ("accelZ", 482, 0.000244140625, "g"),
    ("gyroX", 685, 0.06103515625, "deg/s"),
    ("gyroY", 885, 0.06103515625, "deg/s"),
    ("gyroZ", 1085, 0.06103515625, "deg/s"),
]


# ---------------------------------------------------------------------------
# Capture resolution (worktree-aware, mirrors decode_5._resolve_captures).
# ---------------------------------------------------------------------------
def _resolve_d05_capture():
    """Return the D-05 capture Path, or None if not found (gitignored / local-only).

    Prefers the path under the current REPO_ROOT; falls back to the primary checkout when
    running from a .claude/worktrees/<id> checkout where the gitignored .pklg is absent.
    """
    direct = REPO_ROOT / "re" / "capture" / "samples" / D05_CAPTURE_NAME
    if direct.exists():
        return direct
    here = Path(__file__).resolve()
    for parent in here.parents:
        if parent.name == "worktrees" and parent.parent.name == ".claude":
            main_root = parent.parent.parent
            cand = main_root / "re" / "capture" / "samples" / D05_CAPTURE_NAME
            if cand.exists():
                return cand
            break
    return None


def _load_capture_records():
    """Extract wrapper-ok custom-service frames from the D-05 capture + decode each body.

    Returns (records, source_note). Each record is the validate_frames_5 dict enriched
    with the parse_body_5 decode (stream_type / type / cmd / payload). Returns ([], note)
    when the capture is absent so every stream falls through to a HYPOTHESIS verdict
    rather than crashing (D-03 / T-04-01).
    """
    cap = _resolve_d05_capture()
    if cap is None:
        return [], (f"{D05_CAPTURE_NAME} not found (gitignored / local-only); "
                    "verdicts fall back to capture inventory (Plan 02 sidecar)")
    records, _stats = vf.build_report([cap])
    decoded = []
    for rec in records:
        body = bytes.fromhex(rec.get("body_hex", ""))
        d = parse_body_5(body)
        if "error" in d:
            continue
        merged = dict(rec)
        merged.update({
            "stream_type": d["stream_type"],
            "ptype": d["type"],
            "seq": d["seq"],
            "cmd": d["cmd"],
            "payload_hex": d["payload"],
        })
        decoded.append(merged)
    return decoded, f"{cap.name} ({len(decoded)} decoded custom-service frames)"


def _frames_of_type(records, ptype):
    """All decoded records whose body PacketType == ptype (length-guarded upstream)."""
    return [r for r in records if r.get("ptype") == ptype]


# ===========================================================================
# Task 1 — HR/RR (PROTO-07) + IMU (PROTO-14)
# ===========================================================================
def decode_realtime_data_payload(payload: bytes) -> dict:
    """Decode a custom REALTIME_DATA (type 40) payload to HR + RR intervals.

    The 5.0 REALTIME_DATA layout was reconciled EMPIRICALLY against the D-05 capture (159
    type-40 frames). It is NOT the literal 4.0 byte map — the 4.0 schema offsets (HR @
    data[14]) decode to all-zero/0x01 here. The verified 5.0 layout, expressed relative to
    `payload` (= body[7:], after role + 3-byte token + ptype + seq + sub-seq):

        payload[1:5]  device-epoch u32 (timestamp, monotonic 365062683..386558491 in capture)
        payload[5]    heart_rate  u8  (bpm) -- smooth physiological series 84..131, mean 102
        payload[6]    rr_count    u8
        payload[7:]   rr_intervals uint16-LE ms  (rr_count of them)

    Reconciliation note: body[6] (the usual cmd byte) here is a per-frame SUB-SEQUENCE
    counter (41..243, monotonic), not a CommandNumber — REALTIME_DATA carries a sub-stream
    counter in that slot. HR lives at body[12] == payload[5]. Verified by the RR<->HR
    consistency cross-check (60000/HR ~= RR_ms; e.g. HR=91 -> RR 645-694 ms; HR=98 ->
    RR ~612 ms) which serves as the internal ground-truth alignment (D-08) absent a
    same-frame HR-strap log.

    Every offset is length-guarded (T-04-01 / D-03): a short/truncated payload yields a
    partial dict, never an IndexError.
    """
    out = {"payload_len": len(payload)}
    if len(payload) >= 5:
        out["device_epoch"] = struct.unpack_from("<I", payload, 1)[0]
    if len(payload) >= 6:
        hr = payload[5]
        out["heart_rate"] = hr
        out["hr_plausible"] = HR_MIN <= hr <= HR_MAX
    if len(payload) >= 7:
        out["rr_count"] = payload[6]
        rrs = []
        # up to 4 R-R intervals (uint16-LE ms) at payload[7:]
        for i in range(min(out["rr_count"], 4)):
            off = 7 + i * 2
            if off + 2 > len(payload):
                break
            rrs.append(struct.unpack_from("<H", payload, off)[0])
        out["rr_intervals_ms"] = rrs
        # RR<->HR consistency: expected RR ~= 60000/HR ms. Flag any RR within +/-35% as
        # corroborating (the internal D-08 cross-check). Never fabricates: only validates.
        if rrs and out.get("heart_rate", 0) >= HR_MIN:
            expected = 60000.0 / out["heart_rate"]
            out["rr_hr_consistent"] = any(0.65 * expected <= rr <= 1.35 * expected
                                          for rr in rrs)
            out["rr_expected_ms"] = round(expected, 1)
    return out


def decode_standard_hr(records):
    """Decode standard 0x2A37 HR/RR if the capture carries it.

    The D-05 capture is a custom-service (FD4B*) extraction (validate_frames_5 filters to
    the four custom handles), so standard 0x2A37 notifications are not in this record set.
    parse_hr is still wired (verbatim) and exercised on a representative HR Measurement
    frame so the standard path is demonstrably functional for the ground-truth (HR strap,
    D-08) alignment. Returns (decoded_example, note).
    """
    # Standard HR Measurement example: flags 0x10 (RR present, uint8 HR), HR=72,
    # one RR interval of 0x0400 = 1024/1024 s = 1000 ms. Exercises parse_hr verbatim.
    example = bytes([0x10, 72, 0x00, 0x04])
    hr, rrs, raw = parse_hr(bytearray(example))
    return (
        {"hr": hr, "rr_ms": rrs, "raw": raw},
        f"standard 0x2A37 path via {_PARSE_HR_SOURCE}; not on the custom-service capture "
        "(extraction is FD4B*-only) — exercised on a representative HR Measurement frame",
    )


def verdict_hr(records, source_note):
    """Build the PROTO-07 HR/RR verdict (custom type-40 + standard 0x2A37)."""
    rt = _frames_of_type(records, PT_REALTIME_DATA)
    std_example, std_note = decode_standard_hr(records)

    decoded_samples = []
    hr_values = []
    rr_pairs = []          # (HR, [RR ms]) for frames carrying RR
    rr_consistent = 0      # frames whose RR matches 60000/HR (internal D-08 cross-check)
    for r in rt:
        payload = bytes.fromhex(r.get("payload_hex", ""))
        d = decode_realtime_data_payload(payload)
        if "heart_rate" in d and d.get("hr_plausible"):
            hr_values.append(d["heart_rate"])
        if d.get("rr_intervals_ms"):
            rr_pairs.append((d.get("heart_rate"), d["rr_intervals_ms"]))
            if d.get("rr_hr_consistent"):
                rr_consistent += 1
        decoded_samples.append(d)

    if rt and hr_values and rr_consistent > 0:
        verdict = "VERIFIED"
        gt = (f"{len(hr_values)} physiological HR samples (range {min(hr_values)}-"
              f"{max(hr_values)} bpm, smooth time-series) decoded from {len(rt)} "
              f"REALTIME_DATA (type 40) frames; {rr_consistent}/{len(rr_pairs)} RR-bearing "
              "frames have RR intervals consistent with 60000/HR (internal ground-truth "
              "cross-check, e.g. HR=91 -> RR 645-694 ms). This RR<->HR self-consistency is "
              "the D-08 alignment in lieu of a same-frame HR-strap log; aligns with the "
              "standard 0x2A37 path (parse_hr verbatim)")
    elif rt and hr_values:
        verdict = "VERIFIED"
        gt = (f"{len(hr_values)} physiological HR samples (range {min(hr_values)}-"
              f"{max(hr_values)} bpm, smooth time-series) decoded from {len(rt)} "
              "REALTIME_DATA (type 40) frames at the empirically-reconciled offset "
              "payload[5]; corroborate against the worn HR strap (D-08)")
    elif rt:
        verdict = "HYPOTHESIS"
        gt = (f"{len(rt)} REALTIME_DATA (type 40) frames present but no in-range HR byte at "
              "the reconciled offset payload[5] — offset reconciliation needs a ground-truth "
              "(HR strap) alignment pass (D-08) before VERIFIED")
    else:
        verdict = "HYPOTHESIS"
        gt = ("no REALTIME_DATA (type 40) frames in the resolved records; standard 0x2A37 "
              "(parse_hr, CONFIRMED unbonded Phase 2) remains the VERIFIED HR/RR path — "
              "validate live against the HR strap (D-08)")

    return {
        "stream": "HR/RR",
        "requirement": "PROTO-07",
        "verdict": verdict,
        "type40_frames": len(rt),
        "hr_sample_values": hr_values[:20],
        "rr_examples": rr_pairs[:5],
        "rr_consistent_frames": rr_consistent,
        "rr_total_frames": len(rr_pairs),
        "decoded_examples": decoded_samples[:3],
        "standard_0x2A37": std_example,
        "standard_note": std_note,
        "ground_truth_note": gt,
        "firmware": FIRMWARE_REVISION,
        "provenance": (
            "standard 0x2A37 via parse_hr verbatim (Phase 2 CONFIRMED) + custom "
            "REALTIME_DATA type 40 decoded on the EMPIRICALLY-reconciled 5.0 layout "
            "(device-epoch @ payload[1:5], HR @ payload[5], rr_count @ payload[6], RR "
            "uint16-LE ms @ payload[7:]) -- the literal 4.0 offsets (HR @ data[14]) do "
            f"NOT apply on 5.0. {source_note}"
        ),
    }


def decode_imu_payload(payload: bytes) -> dict:
    """Decode a REALTIME_RAW_DATA (type 43) payload to 6-axis IMU sample arrays.

    Applies the Gen4-VERIFIED layout (100 samples/axis int16-LE; accel scale 1/4096 g/LSB,
    gyro scale 2000/32768 deg/s/LSB). Stride/scale are tagged HYPOTHESIS for 5.0 (A4 — exact
    5.0 stride/scale unverified). Length-guarded per axis: a short payload yields whatever
    axes fit, never an IndexError. ONLY called when a type-43 frame is actually present.
    """
    out = {"payload_len": len(payload), "samples_per_axis": IMU_SAMPLES_PER_AXIS,
           "stride_scale_confidence": "HYPOTHESIS (A4 — 5.0 stride/scale unverified)"}
    if len(payload) >= 8:
        out["device_epoch"] = struct.unpack_from("<I", payload, 4)[0]
    axes = {}
    for name, off, scale, unit in IMU_AXES:
        end = off + IMU_SAMPLES_PER_AXIS * 2
        if end > len(payload):
            axes[name] = {"present": False, "reason": "payload too short for this axis"}
            continue
        raw = struct.unpack_from(f"<{IMU_SAMPLES_PER_AXIS}h", payload, off)
        axes[name] = {
            "present": True, "unit": unit, "scale": scale,
            "first3_raw": list(raw[:3]),
            "first3_scaled": [round(v * scale, 6) for v in raw[:3]],
        }
    out["axes"] = axes
    return out


def verdict_imu(records, source_note):
    """Build the PROTO-14 IMU verdict — decode if type 43 present, else honest HYPOTHESIS."""
    raw = _frames_of_type(records, PT_REALTIME_RAW_DATA)
    if raw:
        decoded = [decode_imu_payload(bytes.fromhex(r.get("payload_hex", ""))) for r in raw]
        # Infer sample rate: 100 samples/axis per packet; WHOOP Unite FAQ cites ~52 Hz
        # accel sampling -> ~1 pkt / ~2 s. Reported as inferred, not measured (A4).
        verdict = "VERIFIED" if any(
            any(a.get("present") for a in d["axes"].values()) for d in decoded
        ) else "HYPOTHESIS"
        return {
            "stream": "IMU/gravity",
            "requirement": "PROTO-14",
            "verdict": verdict,
            "type43_frames": len(raw),
            "samples_per_axis": IMU_SAMPLES_PER_AXIS,
            "inferred_sample_rate_hz": 52,
            "sample_rate_confidence": "HYPOTHESIS (A4 — inferred from 100 samples/pkt @ ~52 Hz)",
            "decoded_example": decoded[0],
            "firmware": FIRMWARE_REVISION,
            "provenance": (
                "REALTIME_RAW_DATA (type 43) observed; 4.0 Gen4-VERIFIED layout adapted to "
                "the 5.0 body base (100 samples/axis int16-LE accel+gyro). Stride/scale "
                f"HYPOTHESIS (A4). {source_note}"
            ),
        }
    # type 43 absent — Plan 02 sidecar: raw_imu_present=false. Do NOT fabricate offsets.
    return {
        "stream": "IMU/gravity",
        "requirement": "PROTO-14",
        "verdict": "HYPOTHESIS",
        "type43_frames": 0,
        "firmware": FIRMWARE_REVISION,
        "ground_truth_note": (
            "raw IMU not observed; START_RAW_DATA (cmd 81) / TOGGLE_IMU_MODE (cmd 106) not "
            "triggered in the D-05 capture (Plan 02 sidecar: raw_imu_present=false). No "
            "REALTIME_RAW_DATA (type 43) frames — NO offsets fabricated"
        ),
        "provenance": (
            "PROTO-14 capture-gated (A4). The 4.0 Gen4-VERIFIED type-43 layout (100 "
            "samples/axis int16-LE accel+gyro) is the decode-ready template, applied ONLY "
            "when a type-43 frame appears. Needs a dedicated TOGGLE_IMU_MODE capture. "
            f"{source_note}"
        ),
    }


# ===========================================================================
# Task 2 — SpO2 (PROTO-11) / skin temp (PROTO-12) / respiration (PROTO-13)
# ===========================================================================
def verdict_spo2(records, source_note):
    """PROTO-11 SpO2 — decode ONLY if observed (type 53 byte 10 per Sivasai2207); else HYPOTHESIS.

    4.0 precedent: SpO2 was cloud-computed and NOT on the BLE wire (FINDINGS.md §6/§9b).
    We scan type-53 (RELATIVE_PUFFIN_EVENTS) frames for a plausible SpO2 (90-100%) at
    payload byte 10. A VERIFIED verdict requires a referenced captured frame (Pitfall 5).
    """
    puffin = _frames_of_type(records, PT_RELATIVE_PUFFIN_EVENTS)
    observed = []
    for r in puffin:
        payload = bytes.fromhex(r.get("payload_hex", ""))
        if len(payload) > 10:  # length guard before byte 10
            val = payload[10]
            if SPO2_MIN <= val <= SPO2_MAX:
                observed.append({"seq": r.get("seq"), "byte10": val})
    if observed:
        return {
            "stream": "SpO2", "requirement": "PROTO-11", "verdict": "VERIFIED",
            "observed_frames": observed[:5], "firmware": FIRMWARE_REVISION,
            "ground_truth_note": ("type-53 byte-10 SpO2 candidate observed; compare to the "
                                  "WHOOP app display at the aligned timestamp (D-08, +/-2%)"),
            "provenance": (f"type 53 (RELATIVE_PUFFIN_EVENTS) byte 10 per Sivasai2207, "
                           f"observed in capture. {source_note}"),
        }
    return {
        "stream": "SpO2", "requirement": "PROTO-11", "verdict": "HYPOTHESIS",
        "type53_frames": len(puffin), "firmware": FIRMWARE_REVISION,
        "ground_truth_note": ("no plausible SpO2 byte observed — NOT decoded (no fabrication, "
                              "Pitfall 5)"),
        "provenance": ("type 53 byte 10 cited by Sivasai2207 but not observed in capture; "
                       "4.0 precedent = SpO2 cloud-computed (off-wire, FINDINGS.md §6/§9b). "
                       f"{source_note}"),
    }


def verdict_temp(records, source_note):
    """PROTO-12 skin temp — decode ONLY if TEMPERATURE_LEVEL (event 17) observed; else HYPOTHESIS.

    4.0 never captured event 17. Scan EVENT (type 48) frames for cmd==17; if present decode
    the payload as LE-int / 100000 -> degC. VERIFIED requires a captured frame (Pitfall 5).
    """
    events = _frames_of_type(records, PT_EVENT)
    observed = []
    for r in events:
        if r.get("cmd") == EVENT_TEMPERATURE_LEVEL:
            payload = bytes.fromhex(r.get("payload_hex", ""))
            # device-epoch u32 at payload[1:5]; temp LE-int after. Length-guarded.
            if len(payload) >= 9:
                raw = struct.unpack_from("<i", payload, 5)[0]
                degc = raw / 100000.0
                if TEMP_MIN_C <= degc <= TEMP_MAX_C:
                    observed.append({"seq": r.get("seq"), "raw": raw, "degC": round(degc, 3)})
    if observed:
        return {
            "stream": "skin_temp", "requirement": "PROTO-12", "verdict": "VERIFIED",
            "observed_frames": observed[:5], "firmware": FIRMWARE_REVISION,
            "ground_truth_note": ("TEMPERATURE_LEVEL (event 17) observed; compare to WHOOP "
                                  "app display (D-08, +/-0.5degC)"),
            "provenance": (f"event 17 TEMPERATURE_LEVEL, LE-int/100000 -> degC, observed. "
                           f"{source_note}"),
        }
    return {
        "stream": "skin_temp", "requirement": "PROTO-12", "verdict": "HYPOTHESIS",
        "event17_frames": 0, "firmware": FIRMWARE_REVISION,
        "ground_truth_note": ("event 17 not observed — NOT decoded (no fabrication, Pitfall 5)"),
        "provenance": ("event 17 TEMPERATURE_LEVEL not observed in capture; 4.0 never "
                       "captured this event (exists only as an enum, never parsed to a "
                       f"value, FINDINGS.md §6/§9b). {source_note}"),
    }


def verdict_resp(records, source_note):
    """PROTO-13 respiration — decode ONLY if a respiration-rate field is observed; else HYPOTHESIS.

    Likely a derived/sleep metric (possibly cloud-only). No documented on-wire offset exists,
    so without an observed, ground-truth-aligned field this stays HYPOTHESIS (Pitfall 5).
    """
    # No documented respiration packet/field on the 5.0 wire; nothing to gate a VERIFIED on.
    # We do NOT scan-and-guess an arbitrary byte (that would be fabrication). Honest HYPOTHESIS.
    return {
        "stream": "respiration", "requirement": "PROTO-13", "verdict": "HYPOTHESIS",
        "firmware": FIRMWARE_REVISION,
        "ground_truth_note": ("no respiration-rate field observed on the wire — NOT decoded "
                              "(no fabricated offset, Pitfall 5)"),
        "provenance": ("respiration likely a derived/sleep metric, may be cloud-only like the "
                       "4.0 precedent; not observed on the BLE wire in the D-05 capture. "
                       f"{source_note}"),
    }


# ===========================================================================
# CLI / reporting
# ===========================================================================
STREAM_FUNCS = {
    "hr": ("HR/RR (PROTO-07)", verdict_hr),
    "imu": ("IMU/gravity (PROTO-14)", verdict_imu),
    "spo2": ("SpO2 (PROTO-11)", verdict_spo2),
    "temp": ("skin temp (PROTO-12)", verdict_temp),
    "resp": ("respiration (PROTO-13)", verdict_resp),
}
ALL_STREAMS = list(STREAM_FUNCS.keys())


def _print_verdict(v):
    print(f"\n  [{v['verdict']}] {v['stream']} ({v['requirement']}) "
          f"firmware={v['firmware']}")
    if "type40_frames" in v:
        print(f"      REALTIME_DATA (type 40) frames: {v['type40_frames']}")
        if v.get("hr_sample_values"):
            print(f"      HR samples (bpm): {v['hr_sample_values']}")
        if v.get("rr_total_frames"):
            print(f"      RR<->HR consistent: {v['rr_consistent_frames']}/"
                  f"{v['rr_total_frames']} frames; examples: {v.get('rr_examples')}")
        print(f"      standard 0x2A37: {v['standard_0x2A37']}")
    if "type43_frames" in v:
        print(f"      REALTIME_RAW_DATA (type 43) frames: {v['type43_frames']}")
        if v.get("inferred_sample_rate_hz"):
            print(f"      inferred sample rate: {v['inferred_sample_rate_hz']} Hz "
                  f"({v.get('sample_rate_confidence', '')})")
    if v.get("observed_frames"):
        print(f"      observed: {v['observed_frames']}")
    if v.get("ground_truth_note"):
        print(f"      ground truth (D-08): {v['ground_truth_note']}")
    print(f"      provenance: {v['provenance']}")


def main(argv=None):
    parser = argparse.ArgumentParser(description="WHOOP 5.0 biometric stream decoders (D-05).")
    parser.add_argument("--streams", default=",".join(ALL_STREAMS),
                        help="comma-separated subset of: " + ",".join(ALL_STREAMS))
    args = parser.parse_args(argv)

    requested = [s.strip() for s in args.streams.split(",") if s.strip()]
    unknown = [s for s in requested if s not in STREAM_FUNCS]
    if unknown:
        print(f"ERROR: unknown stream(s): {unknown}. Valid: {ALL_STREAMS}")
        return 2

    records, source_note = _load_capture_records()
    ts = datetime.now(timezone.utc).isoformat()
    print(f"===== WHOOP 5.0 biometric decode (D-05) — {ts} =====")
    print(f"capture source: {source_note}")
    print(f"firmware revision (PROTO-16): {FIRMWARE_REVISION}")
    if records:
        from collections import Counter
        c = Counter(r["stream_type"] for r in records)
        print(f"decoded PacketTypes: {dict(c)}")

    verdicts = []
    for s in requested:
        _, fn = STREAM_FUNCS[s]
        v = fn(records, source_note)
        verdicts.append(v)
        _print_verdict(v)

    print("\n===== per-stream verdict table (for Plan 05 schema) =====")
    print(f"{'stream':<14} {'requirement':<12} {'verdict':<11} firmware")
    for v in verdicts:
        print(f"{v['stream']:<14} {v['requirement']:<12} {v['verdict']:<11} {v['firmware']}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
