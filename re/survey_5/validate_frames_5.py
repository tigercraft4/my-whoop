"""Phase 3 critical-gate validator for WHOOP 5.0 framing — adapted from re/decode.py + Framing.swift.

What it does:
  (A) Runs the 4.0 inner-framing CRC gate (CRC8 poly 0x07 + CRC32-LE) against captured 5.0
      frames and DOCUMENTS the result. RESEARCH verified this yields 0.0% on 5028 frames —
      the 4.0 inner layout is NOT reused (PROTO-04, a documented negative).
  (B) parse_maverick() / strip_maverick(): strip the confirmed 4-byte Maverick header +
      4-byte trailer to expose the FLAT body (PROTO-05). The body is NOT a nested 0xAA frame
      (RESEARCH Finding 5 / Assumption A2).
  (C) Writes frames_5_golden.json — the wrapper-stripped corpus Phase 4 decodes.

ISOLATION (D-02): this script is standalone in re/survey_5/. It deliberately does NOT do the
4.0-package sys.path import that re/decode.py uses (decode.py lines 7-8) — the 4.0 WhoopPacket
assumes the 4.0 layout, which is wrong for 5.0. The reassemble()/parse logic is ADAPTED here,
not imported.

Run:
    cd re/survey_5 && .venv/bin/python validate_frames_5.py
"""
import json
import struct
import subprocess
import sys
import zlib
from pathlib import Path

# ---------------------------------------------------------------------------
# CRC8 (poly 0x07) — bitwise table generator. Produces the identical 256-entry
# table as Framing.swift:crc8Table and framing.py. Cross-check (D-02b):
#   crc8(b"\x08")     == 0x38   (== Framing.swift CRC8_TABLE[0x08])
#   crc8(b"\x08\x00") == 0xa8
# ---------------------------------------------------------------------------
CRC8_POLY = 0x07


def _crc8_table():
    t = []
    for i in range(256):
        c = i
        for _ in range(8):
            c = ((c << 1) ^ CRC8_POLY) & 0xFF if (c & 0x80) else (c << 1) & 0xFF
        t.append(c)
    return t


CRC8_TABLE = _crc8_table()


def crc8(data: bytes) -> int:
    """CRC8 over `data` using poly 0x07 (matches Framing.swift CRC8_TABLE)."""
    c = 0
    for b in data:
        c = CRC8_TABLE[c ^ b]
    return c


def verify_4_0(frame: bytes):
    """Run the 4.0 inner-framing gate. Returns (crc8_ok, crc32_ok).

    Per D-02b BOTH checks always run:
      - CRC8 (poly 0x07) over the 4.0 length region frame[1:3] vs frame[3]
      - CRC32-LE (zlib.crc32 & 0xFFFFFFFF) over frame[4:length] vs frame[length:length+4]

    The frame[1:3] length read is the 4.0 interpretation, intentionally WRONG for 5.0
    (5.0 puts a version byte 0x01 at offset 1; the real length is at offset 2-3). Running
    it this way is the point: it documents that the 4.0 gate fails. Expected (False, False)
    on every captured 5.0 frame — the PROTO-04 negative result.
    """
    if len(frame) < 8 or frame[0] != 0xAA:
        return (False, False)
    length = struct.unpack("<H", frame[1:3])[0]      # 4.0 offset (WRONG for 5.0, on purpose)
    crc8_ok = crc8(frame[1:3]) == frame[3]
    if length < 7 or length + 4 > len(frame):
        return (crc8_ok, False)
    inner = frame[4:length]
    crc32_ok = (zlib.crc32(inner) & 0xFFFFFFFF) == struct.unpack("<L", frame[length:length + 4])[0]
    return (crc8_ok, crc32_ok)


# ---------------------------------------------------------------------------
# Maverick outer wrapper (RESEARCH Finding 4 / Pattern 2). Structure verified on
# 5028 frames across two sessions:
#   offset 0    SOF        0xAA
#   offset 1    version    0x01
#   offset 2-3  length     u16-LE body length
#   offset 4    role       0x00 = cmd-in write, 0x01 = notify  (== body[0])
#   offset 5..  body       flat payload (length bytes total incl. role at body[0])
#   last 4      trailer    per-frame checksum — ALGORITHM OPEN (Finding 6)
#   total length == length + 8  (4-byte header + body + 4-byte trailer)
# ---------------------------------------------------------------------------
def parse_maverick(frame: bytes):
    """Parse a full ATT value as a Maverick wrapper. Returns dict or None.

    Returns None when len(frame) < 9, frame[0] != 0xAA, frame[1] != 0x01, or the
    total length does not satisfy len(frame) == length + 8.
    """
    if len(frame) < 9 or frame[0] != 0xAA or frame[1] != 0x01:
        return None
    length = struct.unpack_from("<H", frame, 2)[0]    # u16-LE at offset 2-3 (the REAL length)
    if len(frame) != length + 8:                       # 4 hdr + body + 4 trailer
        return None
    role = frame[4]                                    # 0x00 cmd-in, 0x01 notify (== body[0])
    body = frame[4:4 + length]                          # FLAT body, includes role at body[0]
    trailer = frame[-4:]
    return {"length": length, "role": role, "body": body, "trailer": trailer}


def strip_maverick(frame: bytes) -> bytes:
    """Pure bytes->bytes: remove the 4-byte header + 4-byte trailer, return the flat body.

    Returns frame[4:4+length] (the D-03 path) or b"" if the wrapper does not parse.

    Body field offsets (from r52 whoop-vault, HYPOTHESIS):
        body[0]    = role (0x00 cmd-in / 0x01 notify)
        body[1:4]  = per-session token
        body[4:]   = seq + payload

    There is NO nested 0xAA frame to recover (RESEARCH Finding 5 / Assumption A2): the body
    is flat decode input for Phase 4. Do NOT re-run the 4.0 CRC gate on the stripped body.
    """
    p = parse_maverick(frame)
    return p["body"] if p else b""


def reassemble(fragments):
    """Yield complete frames, skipping strays. Adapted from re/decode.py:reassemble().

    tshark already yields complete ATT values (one per row), so reassembly here is a
    SOF-filtering pass-through: drop any fragment whose first byte is not 0xAA. The 4.0
    decode.py reassemble() buffered length-prefixed fragments; that buffering is unnecessary
    when each tshark row is a complete value, but we keep the 0xAA SOF filter (decode.py
    line 17: `if not f or f[0] != 0xAA: continue`).
    """
    for f in fragments:
        if not f or f[0] != 0xAA:
            continue  # stray, skip (mirrors decode.py reassemble)
        yield f


# ---------------------------------------------------------------------------
# Capture extraction + report + golden corpus writer (Task 2).
# ---------------------------------------------------------------------------
# Two existing captures, treated as two sessions per D-01. Use the EXACT Phase 1
# filename (with the space). The CONTEXT.md name with an "-ios" suffix does NOT exist
# on disk (RESEARCH Finding 1) — the real file is the one below.
REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CAPTURES = [
    REPO_ROOT / "re/capture/samples/whoop- iPhone de Francisco.pklg",   # Phase 1 iOS
    REPO_ROOT / "re/capture/samples/2026-05-30-smp-bond-full.pklg",     # Phase 2 SMP
]

# Four custom-service value handles (RESEARCH Finding 2 / Pitfall 4) -> characteristic UUIDs.
HANDLE_UUID = {
    "0x099b": "FD4B0002",   # cmd-in (write)
    "0x099d": "FD4B0003",   # cmd-resp (notify)
    "0x09a0": "FD4B0004",   # events (notify)
    "0x09a3": "FD4B0005",   # data (notify)
}

OUT_PATH = Path(__file__).parent / "frames_5_golden.json"
RUNBOOK = REPO_ROOT / "re/capture/ios-packetlogger.md"
MIN_FRAMES = 20


def extract_frames(capture_path: Path):
    """Run tshark on a .pklg and yield (handle, frame_bytes) for custom-service aa-frames.

    tshark command (RESEARCH Pattern 1):
        tshark -r "<file>" -Y "btatt.value" -T fields -e btatt.handle -e btatt.value
    Filter: value starts with "aa" AND handle in the four custom-service handles (Pitfall 4).
    """
    if not capture_path.exists():
        print(f"  WARNING: capture not found: {capture_path}")
        return
    proc = subprocess.run(
        ["tshark", "-r", str(capture_path), "-Y", "btatt.value",
         "-T", "fields", "-e", "btatt.handle", "-e", "btatt.value"],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        print(f"  WARNING: tshark failed on {capture_path.name}: {proc.stderr.strip()[:200]}")
        return
    for line in proc.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        handle, value = parts[0].strip(), parts[1].strip().replace(":", "").lower()
        if not value.startswith("aa") or handle not in HANDLE_UUID:
            continue
        try:
            yield handle, bytes.fromhex(value)
        except ValueError:
            continue


def build_report(captures):
    """Extract + validate frames from all captures. Returns (records, per_handle_stats)."""
    records = []
    stats = {}  # handle -> dict(count, crc8_ok, crc32_ok, wrapper_ok, example)
    for cap in captures:
        print(f"\n--- {Path(cap).name} ---")
        frames = list(reassemble(f for _, f in extract_frames(Path(cap))))
        # extract_frames already pairs handle+frame; re-run to keep the handle alongside.
        for handle, frame in extract_frames(Path(cap)):
            frame = next(reassemble([frame]), None)
            if frame is None:
                continue
            crc8_ok, crc32_ok = verify_4_0(frame)
            p = parse_maverick(frame)
            wrapper_ok = p is not None
            s = stats.setdefault(handle, {
                "count": 0, "crc8_ok": 0, "crc32_ok": 0, "wrapper_ok": 0, "example": frame[:16].hex()})
            s["count"] += 1
            s["crc8_ok"] += int(crc8_ok)
            s["crc32_ok"] += int(crc32_ok)
            s["wrapper_ok"] += int(wrapper_ok)
            if wrapper_ok:
                records.append({
                    "hex": frame.hex(),
                    "type": None,
                    "seq": None,
                    "cmd": None,
                    "payload": None,
                    "characteristic": HANDLE_UUID[handle],
                    "handle": handle,
                    "role": p["role"],
                    "length": p["length"],
                    "body_hex": p["body"].hex(),
                    "trailer_hex": p["trailer"].hex(),
                    "crc8_4_0_ok": crc8_ok,
                    "crc32_4_0_ok": crc32_ok,
                })
    return records, stats


def main(argv=None):
    captures = [Path(a) for a in (argv or [])] or DEFAULT_CAPTURES
    records, stats = build_report(captures)

    total = sum(s["count"] for s in stats.values())
    total_wrapper_ok = sum(s["wrapper_ok"] for s in stats.values())
    total_crc_ok = sum(s["crc8_ok"] + s["crc32_ok"] for s in stats.values())

    # D-01b fallback: if too few aa-frames, point at the PacketLogger runbook and exit non-zero.
    if total < MIN_FRAMES:
        print("Fallback: no existing captures yielded >=20 frames")
        print(f"Capture a fresh session — runbook: {RUNBOOK}")
        return 1

    # Per-characteristic breakdown (RESEARCH Finding 2 / decode.py bytype model).
    print("\n===== Per-characteristic 4.0-CRC gate + Maverick wrapper =====")
    print(f"{'handle':<8} {'uuid':<10} {'n':>5} {'crc8':>5} {'crc32':>6} {'wrap':>5}  example")
    for handle in sorted(stats):
        s = stats[handle]
        print(f"{handle:<8} {HANDLE_UUID[handle]:<10} {s['count']:>5} "
              f"{s['crc8_ok']:>5} {s['crc32_ok']:>6} {s['wrapper_ok']:>5}  {s['example']}")

    crc_rate = (total_crc_ok / (total * 2) * 100) if total else 0.0
    print(f"\n4.0 CRC gate pass rate: {crc_rate:.1f}%  "
          f"({total_crc_ok}/{total * 2} CRC8+CRC32 checks over {total} frames)")
    all_wrapper = total_wrapper_ok == total
    print(f"Wrapper overhead (len == length+8): {total_wrapper_ok}/{total} frames consistent")
    if all_wrapper:
        print("Maverick wrapper: CONFIRMED")
    else:
        print(f"Maverick wrapper: PARTIAL ({total - total_wrapper_ok} frames failed the len+8 invariant)")

    with open(OUT_PATH, "w") as f:
        json.dump(records, f, indent=2)
    print(f"\n{OUT_PATH.name} written ({len(records)} wrapper-stripped frames)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
