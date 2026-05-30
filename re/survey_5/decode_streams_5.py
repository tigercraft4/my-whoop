"""Phase 4 Plan 03 Task 2 — WHOOP 5.0 corpus stream decoders (PROTO-08/09/10/15).

Decodes everything already present in the captured corpus (no new capture needed):

  EVENTS (PROTO-09): every EVENT frame (type 48) -> r52 EventNumber name, device-epoch u32
      at body[8] (== payload[1:5]), tagged epoch=device (PROTO-15 device epoch). Decodes
      STRAP_CONDITION_REPORT (event 29) and all other observed events.

  BATTERY (PROTO-08): BATTERY_LEVEL event (3) and EXTENDED_BATTERY_INFORMATION event (63).
      Attempts the 4.0 A6 precedent (u16 SOC*10 + u16 millivolts in the event payload) but
      reports the decode as HYPOTHESIS and cross-checks against the standard 0x2A19 read
      (23%, CONFIRMED in Phase 2) — validate, do not fabricate. GET_BATTERY_LEVEL (cmd 26)
      COMMAND_RESPONSE is decoded (u16/10 SOC) IF present (none in the current corpus).

  METADATA + HISTORICAL OFFLOAD (PROTO-10, documentation-only per D-09): METADATA frames
      (type 49) -> HISTORY_START (1) / HISTORY_END (2) / HISTORY_COMPLETE (3). CONSOLE_LOGS
      (type 50) ASCII narration of the live offload session already in the corpus is
      extracted and the store-then-ack protocol is DOCUMENTED: SEND_HISTORICAL_DATA (cmd 22)
      request, HISTORICAL_DATA_RESULT (cmd 23) ack, the data-range command (GET_DATA_RANGE
      34 / SET_READ_POINTER 33), and the trim cursor (0xXXXXXXXX:XXXXXXXX = the store-then-ack
      persistence pointer). NO live kill-process test (that is Phase 5, D-09).

  DUAL-EPOCH (PROTO-15): GET_DATA_RANGE (type 36 cmd 34) payload Unix u32-LE timestamps
      (epoch=unix) alongside the EVENT device-epoch u32 (epoch=device), each printed with a
      human-readable form so Plan 05 can record the model.

ISOLATION (D-02): standalone in re/survey_5/. `from decode_5 import parse_body_5` + resolvers.
Every offset access is len(body)/len(payload)-guarded (T-04-01 / D-03 log-and-continue).
Console-log strings are scrubbed of digit runs that could be a serial before printing
(T-04-04 / DISCLAIMER 2) — only protocol-structure narration is surfaced.

Run:
    cd re/survey_5 && python decode_streams_5.py
"""
import json
import re
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path

from decode_5 import (
    METADATA_TYPE,
    parse_body_5,
    scan_unix_timestamps,
)
import decode_5

GOLDEN = Path(__file__).parent / "frames_5_golden.json"

# Battery-bearing event IDs (r52 EventNumber).
EV_BATTERY_LEVEL = 3
EV_EXTENDED_BATTERY = 63
EV_STRAP_CONDITION = 29
# Standard GATT Battery Level (0x2A19) read recorded CONFIRMED in Phase 2.
GATT_BATTERY_PCT = 23

# Historical-offload command IDs (r52 CommandNumber) for the PROTO-10 documentation.
CMD_SEND_HISTORICAL_DATA = 22
CMD_HISTORICAL_DATA_RESULT = 23
CMD_SET_READ_POINTER = 33
CMD_GET_DATA_RANGE = 34

# Trim cursor format in the CONSOLE_LOGS narration: 0xXXXXXXXX:XXXXXXXX (page:offset).
# Require the full 8-hex offset so console-frame fragmentation (a cursor split across two
# CONSOLE_LOGS frames) does not surface a truncated cursor.
TRIM_RE = re.compile(r"0x[0-9a-fA-F]{8}:[0-9a-fA-F]{8}\b")


def _load_records():
    """Prefer the full corpus (raw captures, worktree-resolved); fall back to the golden
    corpus when the gitignored .pklg are unreachable. The golden corpus retains exemplars
    of every observed stream so every decoder below still has data to run on."""
    captures = decode_5._resolve_captures()
    if captures:
        try:
            import validate_frames_5 as vf
            records, _stats = vf.build_report(captures)
            if records:
                return records, f"full corpus ({len(records)} frames)"
        except Exception as exc:  # noqa: BLE001 — log-and-fall-back (D-03)
            print(f"  NOTE: full-corpus extraction unavailable ({exc!r}); using golden corpus")
    with open(GOLDEN) as f:
        records = json.load(f)
    return records, f"curated golden corpus ({len(records)} records)"


def _iso(ts):
    return datetime.fromtimestamp(ts, tz=timezone.utc).isoformat()


def _scrub(text):
    """T-04-04: redact long digit runs (possible serial/identifier) from console-log
    narration, keep the protocol structure (cmd names, hex trim cursor, short counts)."""
    # Preserve hex trim cursors (0x..:..) and small numbers; mask digit runs of length >=6.
    return re.sub(r"\b\d{6,}\b", "<redacted-digits>", text)


# ---------------------------------------------------------------------------
# EVENTS (PROTO-09) + device epoch (PROTO-15)
# ---------------------------------------------------------------------------
def decode_event(d):
    """Decode one parsed EVENT body dict. Returns an event-detail dict or None.

    body[6] = EventNumber (already resolved in d['cmd_name']); device-epoch u32 at body[8]
    (== payload[1:5]). Length-guarded: payload must be >=5 bytes to read the epoch.
    """
    payload = bytes.fromhex(d["payload"])
    detail = {
        "event_id": d["cmd"],
        "event_name": d["cmd_name"],
        "seq": d["seq"],
        "device_epoch": None,
        "payload_hex": d["payload"],
    }
    if len(payload) >= 5:  # T-04-01 guard before body[8] (payload[1:5])
        detail["device_epoch"] = {
            "offset": 8,
            "value": struct.unpack_from("<I", payload, 1)[0],
            "epoch": "device",
        }
    return detail


def decode_battery_event(d):
    """PROTO-08: attempt the 4.0 A6 battery layout from a BATTERY_LEVEL / EXTENDED battery
    event payload. Returns a dict tagged HYPOTHESIS — the 5.0 layout is NOT confirmed, so
    candidates are reported and cross-checked against the 0x2A19 23% read, never fabricated.

    A6 precedent (4.0): u16 SOC*10 then u16 millivolts inside the event sub-payload. In 5.0
    the event body is body[0]=sub, body[1:5]=device epoch, body[5:]=battery sub-payload.
    """
    payload = bytes.fromhex(d["payload"])
    out = {
        "event_id": d["cmd"],
        "event_name": d["cmd_name"],
        "confidence": "HYPOTHESIS",
        "note": "4.0 A6 layout attempted; 5.0 battery offset not confirmed — dedicated "
                "GET_BATTERY_LEVEL capture needed (Phase 5)",
        "candidates": [],
        "soc_pct_2a19_crosscheck": GATT_BATTERY_PCT,
    }
    if len(payload) < 5:  # T-04-01 guard
        out["error"] = "short battery payload"
        return out
    sub = payload[5:]  # battery sub-payload after the device-epoch u32
    # Scan u16-LE values; surface any plausible SOC (0..1000 as *10, i.e. 0..100.0%) and
    # any plausible Li-ion millivolt (3000..4400 mV). HYPOTHESIS only.
    for off in range(0, max(0, len(sub) - 1), 2):
        val = struct.unpack_from("<H", sub, off)[0]
        if 0 < val <= 1000:
            out["candidates"].append(
                {"offset": off, "u16": val, "as_soc_pct": round(val / 10.0, 1)})
        elif 3000 <= val <= 4400:
            out["candidates"].append(
                {"offset": off, "u16": val, "as_millivolts": val})
    return out


# ---------------------------------------------------------------------------
# METADATA + HISTORICAL OFFLOAD (PROTO-10, documentation-only)
# ---------------------------------------------------------------------------
def extract_console_narration(records):
    """Pull the human-readable ASCII narration out of CONSOLE_LOGS (type 50) frames.

    Returns (lines, trim_cursors). Each line is scrubbed (T-04-04). trim_cursors is the list
    of 0xXXXXXXXX:XXXXXXXX store-then-ack persistence pointers found in the narration.
    """
    lines = []
    trim_cursors = []
    for rec in records:
        d = parse_body_5(bytes.fromhex(rec.get("body_hex", "")))
        if "error" in d or d["type"] != 50:
            continue
        payload = bytes.fromhex(d["payload"])
        # ASCII run extraction — printable chars only, drop the binary header bytes.
        ascii_run = "".join(chr(b) if 32 <= b < 127 else " " for b in payload).strip()
        if not ascii_run:
            continue
        for cur in TRIM_RE.findall(ascii_run):
            trim_cursors.append(cur)
        lines.append(_scrub(ascii_run))
    return lines, trim_cursors


def document_historical_offload(records):
    """PROTO-10 (documentation-only, D-09): build the store-then-ack offload narrative from
    METADATA + CONSOLE_LOGS already in the corpus. No live kill test (Phase 5)."""
    meta_counts = {}
    for rec in records:
        d = parse_body_5(bytes.fromhex(rec.get("body_hex", "")))
        if "error" in d or d["type"] != 49:
            continue
        name = METADATA_TYPE.get(d["cmd"], f"meta{d['cmd']}")
        meta_counts[name] = meta_counts.get(name, 0) + 1

    console_lines, trim_cursors = extract_console_narration(records)
    return {
        "metadata_frames": meta_counts,
        "console_narration": console_lines,
        "trim_cursors": trim_cursors,
        "protocol": {
            "request": f"SEND_HISTORICAL_DATA (cmd {CMD_SEND_HISTORICAL_DATA})",
            "ack": f"HISTORICAL_DATA_RESULT (cmd {CMD_HISTORICAL_DATA_RESULT})",
            "range_cmds": [
                f"GET_DATA_RANGE (cmd {CMD_GET_DATA_RANGE})",
                f"SET_READ_POINTER (cmd {CMD_SET_READ_POINTER})",
            ],
            "trim_cursor_meaning": "0xPAGE:OFFSET = the store-then-ack persistence cursor; "
                                   "the strap advances the trim pointer only after the host "
                                   "ack, so a kill before ack must NOT advance it (D-09 live "
                                   "test deferred to Phase 5)",
            "documentation_only": True,
        },
    }


# ---------------------------------------------------------------------------
# DUAL-EPOCH (PROTO-15)
# ---------------------------------------------------------------------------
def decode_dual_epoch(records):
    """PROTO-15: collect Unix u32 timestamps from GET_DATA_RANGE responses (epoch=unix) and
    device-epoch u32 from EVENT bodies (epoch=device). Returns {unix:[...], device:[...]}."""
    unix_ts = []
    device_ts = []
    for rec in records:
        d = parse_body_5(bytes.fromhex(rec.get("body_hex", "")))
        if "error" in d:
            continue
        if d["type"] == 36 and d["cmd"] == CMD_GET_DATA_RANGE:
            payload = bytes.fromhex(d["payload"])
            for off, val, iso in scan_unix_timestamps(payload):
                unix_ts.append({"offset": off, "value": val, "iso": iso, "epoch": "unix"})
        if d["type"] == 48:
            payload = bytes.fromhex(d["payload"])
            if len(payload) >= 5:  # T-04-01 guard
                dev = struct.unpack_from("<I", payload, 1)[0]
                device_ts.append({"event": d["cmd_name"], "value": dev, "epoch": "device"})
    return {"unix": unix_ts, "device": device_ts}


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------
def decode_streams(records):
    """Run all decoders. Returns a Plan-05 / FINDINGS_5.md-consumable dict."""
    events = []
    batteries = []
    event_name_counts = {}
    for rec in records:
        d = parse_body_5(bytes.fromhex(rec.get("body_hex", "")))
        if "error" in d or d["type"] != 48:
            continue
        ev = decode_event(d)
        events.append(ev)
        event_name_counts[ev["event_name"]] = event_name_counts.get(ev["event_name"], 0) + 1
        if d["cmd"] in (EV_BATTERY_LEVEL, EV_EXTENDED_BATTERY):
            batteries.append(decode_battery_event(d))

    historical = document_historical_offload(records)
    epochs = decode_dual_epoch(records)

    # GET_BATTERY_LEVEL (cmd 26) COMMAND_RESPONSE, if present (u16/10 SOC). None expected.
    batt_cmd_resp = []
    for rec in records:
        d = parse_body_5(bytes.fromhex(rec.get("body_hex", "")))
        if "error" in d or d["type"] != 36 or d["cmd"] != 26:
            continue
        payload = bytes.fromhex(d["payload"])
        if len(payload) >= 2:  # T-04-01 guard
            soc = struct.unpack_from("<H", payload, 0)[0] / 10.0
            batt_cmd_resp.append({"soc_pct": soc, "confidence": "HYPOTHESIS"})

    return {
        "events": events,
        "event_name_counts": event_name_counts,
        "batteries": batteries,
        "battery_cmd_responses": batt_cmd_resp,
        "historical_offload": historical,
        "dual_epoch": epochs,
    }


def _print_report(result, source_label):
    print("===== WHOOP 5.0 corpus stream decode (PROTO-08/09/10/15) =====")
    print(f"Source: {source_label}\n")

    # EVENTS (PROTO-09)
    print("----- EVENTS (PROTO-09) — resolved to r52 EventNumber + device epoch -----")
    for name, count in sorted(result["event_name_counts"].items()):
        print(f"  {name:<32} {count} frames")
    # Highlight STRAP_CONDITION_REPORT (29) with its device epoch.
    strap = next((e for e in result["events"]
                  if e["event_name"] == "STRAP_CONDITION_REPORT" and e["device_epoch"]), None)
    if strap:
        de = strap["device_epoch"]
        print(f"  e.g. STRAP_CONDITION_REPORT (event 29): device-epoch u32 @body[8] = "
              f"{de['value']} (epoch=device, PROTO-15)")
    else:
        any_ev = next((e for e in result["events"] if e["device_epoch"]), None)
        if any_ev:
            de = any_ev["device_epoch"]
            print(f"  e.g. {any_ev['event_name']}: device-epoch u32 @body[8] = "
                  f"{de['value']} (epoch=device, PROTO-15)")

    # BATTERY (PROTO-08)
    print("\n----- BATTERY (PROTO-08) — HYPOTHESIS, cross-checked vs 0x2A19 = 23% -----")
    if result["batteries"]:
        for b in result["batteries"]:
            print(f"  {b['event_name']} (event {b['event_id']}): {b['confidence']}")
            for c in b["candidates"]:
                if "as_soc_pct" in c:
                    print(f"      off {c['offset']:>2}: u16 {c['u16']} -> SOC {c['as_soc_pct']}% (candidate)")
                else:
                    print(f"      off {c['offset']:>2}: u16 {c['u16']} -> {c['as_millivolts']} mV (candidate)")
            print(f"      cross-check: GATT 0x2A19 read = {b['soc_pct_2a19_crosscheck']}% (Phase 2 CONFIRMED)")
            print(f"      note: {b['note']}")
    else:
        print("  (no BATTERY_LEVEL/EXTENDED battery events in this corpus slice)")
    if result["battery_cmd_responses"]:
        for r in result["battery_cmd_responses"]:
            print(f"  GET_BATTERY_LEVEL (cmd 26) resp: SOC {r['soc_pct']}% ({r['confidence']})")
    else:
        print("  GET_BATTERY_LEVEL (cmd 26) COMMAND_RESPONSE: not present in corpus "
              "(battery decode rests on the BATTERY_LEVEL event only)")

    # HISTORICAL OFFLOAD (PROTO-10)
    print("\n----- HISTORICAL OFFLOAD (PROTO-10) — DOCUMENTATION-ONLY (D-09) -----")
    ho = result["historical_offload"]
    print(f"  METADATA frames: {ho['metadata_frames']}")
    proto = ho["protocol"]
    print(f"  store-then-ack protocol:")
    print(f"    request : {proto['request']}")
    print(f"    ack     : {proto['ack']}")
    print(f"    range   : {', '.join(proto['range_cmds'])}")
    print(f"    trim cursor: {proto['trim_cursor_meaning']}")
    if ho["trim_cursors"]:
        print(f"  Trim cursor(s) observed in CONSOLE_LOGS: {sorted(set(ho['trim_cursors']))}")
    print("  CONSOLE_LOGS narration (scrubbed, protocol structure only):")
    for line in ho["console_narration"][:6]:
        print(f"    | {line}")

    # DUAL-EPOCH (PROTO-15)
    print("\n----- DUAL-EPOCH MODEL (PROTO-15) -----")
    epochs = result["dual_epoch"]
    if epochs["unix"]:
        recent = [t for t in epochs["unix"] if t["iso"].startswith("2026")]
        u = (recent or epochs["unix"])[0]
        print(f"  Unix epoch (GET_DATA_RANGE): off {u['offset']} {u['value']} -> {u['iso']} "
              f"(epoch=unix)  [{len(epochs['unix'])} Unix ts total]")
    else:
        print("  Unix epoch: (no GET_DATA_RANGE timestamps in this corpus slice)")
    if epochs["device"]:
        d0 = epochs["device"][0]
        print(f"  Device epoch (EVENT body[8]): {d0['value']} from {d0['event']} "
              f"(epoch=device)  [{len(epochs['device'])} device ts total]")
    else:
        print("  Device epoch: (no EVENT device timestamps in this corpus slice)")
    print("  -> dual-epoch confirmed: GET_DATA_RANGE carries Unix u32, EVENTs carry a "
          "device-epoch u32 — each field MUST be tagged epoch=unix|device in the schema.")


def main(argv=None):
    records, source_label = _load_records()
    result = decode_streams(records)
    _print_report(result, source_label)
    return 0


if __name__ == "__main__":
    sys.exit(main())
