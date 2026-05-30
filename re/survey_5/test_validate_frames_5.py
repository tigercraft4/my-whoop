"""Self-test for validate_frames_5.py (Phase 3, plan 03-01, Task 1 — TDD).

Plain assertion-based runnable test (no pytest dependency — matches the re/ test_*.py
convention). Exercises the pure functions: crc8, verify_4_0, parse_maverick, strip_maverick.

Run:
    cd re/survey_5 && .venv/bin/python test_validate_frames_5.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import validate_frames_5 as v  # noqa: E402

# A real wrapper frame from the Phase 1 capture (RESEARCH Pattern 1/3):
# [AA][01][len=0x0008 LE][role=00][body...][trailer 4B]  total = 8 + 8 = 16
FRAME = bytes.fromhex("aa0108000001e67123942200c0896bce")
BODY = bytes.fromhex("0001e67123942200")  # frame[4:4+length], length=8


def test_crc8_matches_swift_table():
    # Cross-check against Framing.swift CRC8_TABLE (poly 0x07): table[0x08] == 0x38.
    one = v.crc8(b"\x08")
    assert one == 0x38, "crc8(08)=%#x, expected 0x38" % one
    # Stable cross-check value for the two-byte length region (per D-02b comment in RESEARCH).
    two = v.crc8(b"\x08\x00")
    assert two == 0xA8, "crc8(0800)=%#x, expected 0xa8" % two


def test_verify_4_0_fails_on_5_0_frame():
    # 4.0 gate is the documented NEGATIVE (PROTO-04): both CRC8 and CRC32-LE fail.
    assert v.verify_4_0(FRAME) == (False, False), "4.0 gate must fail on 5.0 frame"


def test_parse_maverick_valid():
    p = v.parse_maverick(FRAME)
    assert p is not None, "valid wrapper must parse"
    assert p["length"] == 8, p["length"]
    assert p["role"] == 0x00, p["role"]
    assert p["body"] == BODY, p["body"].hex()
    assert p["trailer"] == bytes.fromhex("c0896bce"), p["trailer"].hex()


def test_parse_maverick_rejects_invalid():
    assert v.parse_maverick(b"\xaa\x00") is None, "short frame must be None"
    assert v.parse_maverick(b"\xbb\x01\x08\x00\x00") is None, "wrong SOF must be None"
    # Wrong b1 (version byte must be 0x01)
    assert v.parse_maverick(b"\xaa\x02\x08\x00\x00\x00\x00\x00\x00") is None, "wrong b1 must be None"
    # len(frame) != length + 8
    assert v.parse_maverick(b"\xaa\x01\x08\x00\x00\x00") is None, "bad length invariant must be None"


def test_strip_maverick_returns_flat_body():
    assert v.strip_maverick(FRAME) == BODY, v.strip_maverick(FRAME).hex()
    assert v.strip_maverick(b"\xaa\x00") == b"", "parse failure returns b''"


def test_strip_maverick_docstring_documents_no_nested_frame():
    doc = v.strip_maverick.__doc__ or ""
    assert ("NO nested" in doc) or ("no nested" in doc), "strip_maverick docstring must document Finding 5"


if __name__ == "__main__":
    tests = [fn for name, fn in sorted(globals().items()) if name.startswith("test_") and callable(fn)]
    failures = 0
    for fn in tests:
        try:
            fn()
            print(f"PASS  {fn.__name__}")
        except AssertionError as e:
            failures += 1
            print(f"FAIL  {fn.__name__}: {e}")
        except Exception as e:  # noqa: BLE001
            failures += 1
            print(f"ERROR {fn.__name__}: {type(e).__name__}: {e}")
    print(f"\n{len(tests) - failures}/{len(tests)} passed")
    sys.exit(1 if failures else 0)
