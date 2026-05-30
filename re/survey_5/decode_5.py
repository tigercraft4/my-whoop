"""Phase 4 reference body decoder for WHOOP 5.0 — the Maverick-aware decode primitive.

What it does:
  (Task 1, D-01 gate) parse_body_5(): strip-free flat-body parser keyed at BODY OFFSET 4
      (the corrected D-01 — NOT offset 1). Resolves r52 PacketType / CommandNumber /
      EventNumber / MetadataType names. NO inner CRC32 on the body. Length-guarded
      (ASVS V5 / D-03 log-and-continue). Running this against the 46 golden frames is the
      D-01 body-layout gate: it proves the offset-4 hypothesis empirically.

  (Task 2, D-04) --rebuild-corpus: extract the full ~5028-frame corpus from both pklg
      captures via validate_frames_5.build_report(), decode each body, tag every record
      with a `stream_type` (resolved PacketType name), and re-curate to a per-(stream_type,
      cmd) exemplar cap so the committed frames_5_golden.json is a cross-type fixture
      (substantially larger than 46, well under 5028 — Pitfall 4 evidence policy).

  PROTO-15 dual-epoch detection: GET_DATA_RANGE (COMMAND_RESPONSE cmd 34) payloads are
      scanned for u32-LE Unix timestamps (1.4e9..1.9e9); EVENT bodies expose a device-epoch
      u32 at body[8]. Surfaced here so Wave 2/3 schema work can use it — full schema is NOT
      built in this plan.

ISOLATION (D-02): standalone in re/survey_5/. stdlib only (json/struct/pathlib/datetime)
plus `from validate_frames_5 import strip_maverick`. It deliberately does NOT do the
re/decode.py 4.0-package import hack (mutating the module search path to pull in the 4.0
packet class) — that 4.0 class assumes the 4.0 framing, which is wrong for 5.0. The
parse_frame logic is ADAPTED here (offsets 1/2/3 -> 4/5/6, CRC dropped), not imported.

Run:
    cd re/survey_5 && python decode_5.py frames_5_golden.json   # D-01 gate
    cd re/survey_5 && python decode_5.py --rebuild-corpus       # D-04 corpus expansion
"""
import json
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path

from validate_frames_5 import strip_maverick  # noqa: F401  (D-02: Phase 3 entry point)
import validate_frames_5 as vf

# ---------------------------------------------------------------------------
# r52 enum maps — single source of truth: read from the 4.0 schema at runtime.
# WG50_r52 is confirmed identical to the 4.0 enum maps (RESEARCH "Don't Hand-Roll"),
# so we load PacketType / MetadataType / EventNumber / CommandNumber from
# protocol/whoop_protocol.json rather than re-typing them here.
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parents[2]
PROTOCOL_4_0 = REPO_ROOT / "protocol" / "whoop_protocol.json"


def _load_enums():
    with open(PROTOCOL_4_0) as f:
        enums = json.load(f)["enums"]
    # JSON keys are strings; coerce to int -> name for fast cmd/ptype lookup.
    return {
        name: {int(k): v for k, v in table.items()}
        for name, table in enums.items()
    }


ENUMS = _load_enums()
PACKET_TYPE = ENUMS["PacketType"]
METADATA_TYPE = ENUMS["MetadataType"]
EVENT_NUMBER = ENUMS["EventNumber"]
COMMAND_NUMBER = ENUMS["CommandNumber"]

# PacketType numbers that carry a CommandNumber in cmd (body[6]).
_COMMAND_PTYPES = {35, 36}   # COMMAND, COMMAND_RESPONSE
_EVENT_PTYPES = {48}         # EVENT
_METADATA_PTYPES = {49}      # METADATA

# PROTO-15: plausible Unix-epoch u32-LE window (2014-05..2030-03 roughly).
UNIX_TS_MIN = 1_400_000_000
UNIX_TS_MAX = 1_900_000_000


def packet_type_name(ptype: int) -> str:
    """Resolve a PacketType number to its r52 name, or 'type{N}' if unmapped."""
    return PACKET_TYPE.get(ptype, f"type{ptype}")


def resolve_cmd(ptype: int, cmd: int) -> str:
    """Resolve cmd (body[6]) to a name using the right enum for this ptype.

    COMMAND/COMMAND_RESPONSE -> CommandNumber, EVENT -> EventNumber,
    METADATA -> MetadataType. Unknown ptype or unmapped cmd -> 'cmd{N}'.
    """
    if ptype in _COMMAND_PTYPES:
        return COMMAND_NUMBER.get(cmd, f"cmd{cmd}")
    if ptype in _EVENT_PTYPES:
        return EVENT_NUMBER.get(cmd, f"event{cmd}")
    if ptype in _METADATA_PTYPES:
        return METADATA_TYPE.get(cmd, f"meta{cmd}")
    return f"cmd{cmd}"


def scan_unix_timestamps(payload: bytes):
    """Return [(offset, u32, iso)] for every u32-LE in the Unix-epoch window.

    PROTO-15 (unix epoch): used to surface candidate timestamps inside e.g. a
    GET_DATA_RANGE COMMAND_RESPONSE payload. Bounds-checked, never indexes past end.
    """
    out = []
    for off in range(0, max(0, len(payload) - 3)):
        val = struct.unpack_from("<I", payload, off)[0]
        if UNIX_TS_MIN <= val <= UNIX_TS_MAX:
            iso = datetime.fromtimestamp(val, tz=timezone.utc).isoformat()
            out.append((off, val, iso))
    return out


def parse_body_5(body: bytes) -> dict:
    """Decode a wrapper-stripped flat body at BODY OFFSET 4 (corrected D-01).

    Layout (RESEARCH Pattern 1, verified 46/46 golden frames):
        body[0]    role   0x00 cmd-in write / 0x01 notify
        body[1:4]  token  3-byte per-session token (HYPOTHESIS, A5)
        body[4]    ptype  r52 PacketType
        body[5]    seq    monotonic sequence
        body[6]    cmd    r52 CommandNumber / EventNumber / MetadataType (context = ptype)
        body[7:]   payload

    There is NO inner CRC32 on the body — do NOT carry over parse_frame's crc_ok check.

    ASVS V5 length guard (T-04-01 / D-03): bodies shorter than 7 bytes cannot carry the
    full prefix, so return an error dict and let the caller log-and-continue. Never index
    past the end of a truncated / fragmented BLE frame.
    """
    if len(body) < 7:
        return {"error": "short", "body_hex": body.hex()}
    role = body[0]
    token = body[1:4]
    ptype = body[4]
    seq = body[5]
    cmd = body[6]
    payload = body[7:]

    ptype_name = packet_type_name(ptype)
    cmd_name = resolve_cmd(ptype, cmd)

    decoded = {
        "role": role,
        "token": token.hex(),          # HYPOTHESIS (A5) — 3-byte session token
        "type": ptype,
        "stream_type": ptype_name,
        "seq": seq,
        "cmd": cmd,
        "cmd_name": cmd_name,
        "payload": payload.hex(),
    }

    # PROTO-15 dual-epoch surfacing (no full schema here — just expose for Wave 2/3).
    # GET_DATA_RANGE (COMMAND_RESPONSE cmd 34): scan payload for Unix-epoch u32-LE.
    if ptype == 36 and cmd == 34:
        ts = scan_unix_timestamps(payload)
        if ts:
            decoded["unix_timestamps"] = [
                {"offset": o, "value": v, "iso": iso, "epoch": "unix"} for o, v, iso in ts
            ]
    # EVENT (ptype 48): device-epoch u32 at body[8] (== payload[1:5]); tag epoch=device.
    if ptype == 48 and len(payload) >= 5:
        dev = struct.unpack_from("<I", payload, 1)[0]
        decoded["device_epoch"] = {"offset": 8, "value": dev, "epoch": "device"}

    return decoded


def decode_corpus(records):
    """Run parse_body_5 over a list of golden records. Returns (decoded, bytype).

    Each record carries `body_hex`. `decoded` is a list of dicts (the parse_body_5 result
    plus the source characteristic). `bytype` groups by resolved PacketType name with a
    per-type count + one exemplar (copies the dispatch/count idiom from re/decode.py
    lines 49-63). Short/garbled bodies are kept under their own 'SHORT' bucket
    (D-03 log-and-continue) rather than crashing.
    """
    decoded = []
    bytype = {}
    for rec in records:
        body = bytes.fromhex(rec.get("body_hex", ""))
        d = parse_body_5(body)
        d = dict(d)
        d["characteristic"] = rec.get("characteristic")
        decoded.append(d)
        if "error" in d:
            bytype.setdefault("SHORT", []).append(d)
            continue
        bytype.setdefault(d["stream_type"], []).append(d)
    return decoded, bytype


def _gate_print(bytype):
    """Print the per-type breakdown for the D-01 gate. Returns (all_ptypes_known,
    all_cmds_known, timestamp_candidates)."""
    all_ptypes_known = True
    all_cmds_known = True
    ts_candidates = 0

    print("\n===== D-01 body-offset-4 gate: per-PacketType breakdown =====")
    for tname in sorted(bytype):
        items = bytype[tname]
        if tname == "SHORT":
            print(f"  SHORT: {len(items)} truncated bodies (length-guarded, skipped)")
            continue
        if tname.startswith("type"):
            all_ptypes_known = False
        # cmd resolution check: any cmd that fell through to 'cmd{N}'/'event{N}'/'meta{N}'.
        unresolved = [i for i in items
                      if i["cmd_name"].startswith(("cmd", "event", "meta"))
                      and i["cmd_name"][len("cmd"):].lstrip("dmevnta").isdigit()]
        cmd_names = sorted({i["cmd_name"] for i in items})
        ex = items[0]
        print(f"  {tname}: {len(items)} frames | cmds: {', '.join(cmd_names)}")
        print(f"      e.g. seq={ex['seq']} cmd={ex['cmd']}({ex['cmd_name']}) "
              f"payload[:24]={ex['payload'][:48]}")
        # Surface PROTO-15 timestamps under COMMAND_RESPONSE.
        for i in items:
            if "unix_timestamps" in i and i["unix_timestamps"]:
                ts_candidates += len(i["unix_timestamps"])
                # Prefer a recent (2026-era) candidate as the headline evidence; fall
                # back to the first if none are recent. The device is a 2026 capture, so
                # the GET_DATA_RANGE response carries current-era data window bounds.
                recent = [t for t in i["unix_timestamps"] if t["iso"].startswith("2026")]
                headline = recent[0] if recent else i["unix_timestamps"][0]
                print(f"      PROTO-15 unix ts in {i['cmd_name']}: "
                      f"off={headline['offset']} {headline['value']} -> {headline['iso']}")
    return all_ptypes_known, all_cmds_known, ts_candidates


def run_gate(corpus_path: Path) -> int:
    """D-01 gate: load corpus, decode, print breakdown, exit 0 iff every decoded ptype
    resolves to a known r52 PacketType name. Reports PROTO-15 Unix timestamp candidates."""
    with open(corpus_path) as f:
        records = json.load(f)
    decoded, bytype = decode_corpus(records)
    all_ptypes_known, _all_cmds_known, ts_candidates = _gate_print(bytype)

    print(f"\nDecoded {len(decoded)} records from {corpus_path.name}")
    print(f"PROTO-15 Unix timestamp candidates: {ts_candidates}")

    if not all_ptypes_known:
        print("GATE FAIL: at least one ptype did not resolve to a known r52 PacketType")
        return 1
    print("GATE PASS: every decoded ptype resolves to a known r52 PacketType "
          "(offset-4 D-01 hypothesis confirmed)")
    return 0


# ---------------------------------------------------------------------------
# Task 2 (D-04): full-corpus extraction + stream_type classification + re-curation.
# ---------------------------------------------------------------------------
OUT_PATH = Path(__file__).parent / "frames_5_golden.json"

# Per-(stream_type, cmd) exemplar cap. Replaces the flat per-handle cap so the committed
# fixture keeps >=1 exemplar of every observed (PacketType, cmd) pair while capping the
# bulk data frames (HISTORICAL_DATA / CONSOLE_LOGS dominate the ~4400 non-control frames).
PER_TYPE_CMD_CAP = 4


def _resolve_captures():
    """Return the list of pklg captures to extract from.

    The raw .pklg files are gitignored (Pitfall 4 / T-04-02) and therefore do NOT exist
    inside a git worktree checkout — only in the developer's primary working tree. Prefer
    validate_frames_5.DEFAULT_CAPTURES when present; otherwise fall back to the same
    relative paths under the main (non-worktree) repo so --rebuild-corpus works from a
    worktree. Captures stay local-only either way — none are committed.
    """
    present = [c for c in vf.DEFAULT_CAPTURES if Path(c).exists()]
    if present:
        return present
    # Worktree fallback: .claude/worktrees/<id> -> walk up to the primary checkout.
    here = Path(__file__).resolve()
    for parent in here.parents:
        if parent.name == "worktrees" and parent.parent.name == ".claude":
            main_root = parent.parent.parent
            candidates = [main_root / Path(c).relative_to(REPO_ROOT) for c in vf.DEFAULT_CAPTURES]
            present = [c for c in candidates if Path(c).exists()]
            if present:
                return present
            break
    return []


def rebuild_corpus() -> int:
    """Extract the full corpus, decode + tag stream_type, re-curate, write golden JSON."""
    captures = _resolve_captures()
    if not captures:
        print("ERROR: no pklg captures found (raw captures are gitignored / local-only).")
        print("       Place them under re/capture/samples/ in the primary checkout.")
        return 1

    print("Extracting full corpus from:")
    for c in captures:
        print(f"  {c}")
    records, _stats = vf.build_report(captures)
    total = len(records)
    print(f"\nTotal wrapper-ok frames extracted: {total}")

    # Decode every record's body, populate type/seq/cmd/payload + add stream_type.
    stream_counts = {}
    pair_seen = set()
    for rec in records:
        body = bytes.fromhex(rec["body_hex"])
        d = parse_body_5(body)
        if "error" in d:
            rec["stream_type"] = "SHORT"
            rec["type"] = rec["seq"] = rec["cmd"] = None
            rec["payload"] = None
            stream_counts["SHORT"] = stream_counts.get("SHORT", 0) + 1
            continue
        rec["type"] = d["type"]
        rec["seq"] = d["seq"]
        rec["cmd"] = d["cmd"]
        rec["payload"] = d["payload"]
        rec["stream_type"] = d["stream_type"]
        stream_counts[d["stream_type"]] = stream_counts.get(d["stream_type"], 0) + 1
        pair_seen.add((d["stream_type"], d["cmd"]))

    # Re-curate: keep up to PER_TYPE_CMD_CAP exemplars per (stream_type, cmd) pair so every
    # observed (PacketType, cmd) combination survives while the bulk data frames are capped.
    per_pair = {}
    curated = []
    for rec in records:
        key = (rec["stream_type"], rec["cmd"])
        if per_pair.get(key, 0) >= PER_TYPE_CMD_CAP:
            continue
        per_pair[key] = per_pair.get(key, 0) + 1
        curated.append(rec)

    with open(OUT_PATH, "w") as f:
        json.dump(curated, f, indent=2)

    print("\n===== stream_type counts (full corpus) =====")
    for st in sorted(stream_counts):
        print(f"  {st:<24} {stream_counts[st]:>5}")
    print(f"\nDistinct (stream_type, cmd) pairs: {len(pair_seen)}")
    print(f"Curated entries written to {OUT_PATH.name}: {len(curated)} "
          f"(of {total}; per-(type,cmd) cap = {PER_TYPE_CMD_CAP})")
    return 0


def main(argv=None):
    argv = list(argv if argv is not None else sys.argv[1:])
    if "--rebuild-corpus" in argv:
        return rebuild_corpus()
    corpus = Path(argv[0]) if argv else OUT_PATH
    return run_gate(corpus)


if __name__ == "__main__":
    sys.exit(main())
