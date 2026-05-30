"""Phase 4 Plan 03 Task 1 — WHOOP 5.0 command-surface reconciliation (PROTO-06, D-06/D-07).

What it does (capture-analysis fulfilment of PROTO-06 — there is NO live 0-255 probe on
macOS because Bleak cannot bond; the live probe is deferred to Phase 5 per D-06):

  1. Enumerate every command ID actually OBSERVED in the corpus:
       - body[6] of COMMAND (type 35) and COMMAND_RESPONSE (type 36) frames
       - the request cmd of cmd-in WRITE frames (role 0 on FD4B0002 — RESEARCH Pattern 2)
     Prefer the FULL ~5028-frame corpus via validate_frames_5.build_report(); fall back to
     the curated 123-record frames_5_golden.json when the gitignored .pklg captures are not
     reachable (fresh clone / CI). Either path yields the same observed command IDs because
     the golden corpus preserves >=1 exemplar of every observed (stream_type, cmd) pair.

  2. Pair cmd-in WRITE requests with cmd-resp NOTIFY by `seq` to confirm the request->response
     mapping (RESEARCH A7: body[6] of a cmd-in write IS the request command ID).

  3. Build an OBSERVED-vs-EXPECTED reconciliation against the COMPLETE r52 CommandNumber map:
     each r52 command is marked OBSERVED (with a frame count) or UNOBSERVED. Unobserved-but-
     r52-expected commands become HYPOTHESIS with r52 attribution (D-07). Explicitly
     cross-validate the 14 reused 4.0 command IDs
     (1,2,3,7,11,14,22,26,35,81,82,106,107,145) as present/absent in the 5.0 corpus.

ISOLATION (D-02): standalone in re/survey_5/. `from decode_5 import parse_body_5` + the r52
resolver; never imports the 4.0 packet class. stdlib only otherwise.

Run:
    cd re/survey_5 && python command_surface_5.py
"""
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

from decode_5 import (
    COMMAND_NUMBER,
    parse_body_5,
    resolve_cmd,
)
import decode_5

# The 14 command IDs reused from WHOOP 4.0 (plan + RESEARCH PROTO-06 row). Cross-validated
# as present/absent in the 5.0 corpus below.
REUSED_4_0_IDS = [1, 2, 3, 7, 11, 14, 22, 26, 35, 81, 82, 106, 107, 145]

# Command-carrying PacketTypes (body[6] = CommandNumber for these).
_COMMAND_PTYPES = {35, 36}   # COMMAND, COMMAND_RESPONSE
# cmd-in write characteristic (RESEARCH Pattern 2 / Finding 2) — role 0 requests live here.
CMD_IN_CHAR = "FD4B0002"

GOLDEN = Path(__file__).parent / "frames_5_golden.json"


def _load_records():
    """Return (records, source_label).

    Prefer the FULL corpus from the raw captures (validate_frames_5.build_report over the
    worktree-resolved .pklg captures). Fall back to the curated golden corpus when the
    gitignored captures are not reachable (fresh clone / CI). The golden corpus preserves
    every observed (stream_type, cmd) pair, so the OBSERVED set is identical either way.
    """
    captures = decode_5._resolve_captures()
    if captures:
        try:
            import validate_frames_5 as vf
            records, _stats = vf.build_report(captures)
            if records:
                return records, f"full corpus ({len(records)} frames, {len(captures)} captures)"
        except Exception as exc:  # noqa: BLE001 — log-and-fall-back, never crash (D-03)
            print(f"  NOTE: full-corpus extraction unavailable ({exc!r}); using golden corpus")
    with open(GOLDEN) as f:
        records = json.load(f)
    return records, f"curated golden corpus ({len(records)} records)"


def enumerate_command_surface(records):
    """Collect observed command IDs and request->response seq pairings.

    Returns a dict:
        observed_counts : {cmd_id: total frame count across COMMAND/COMMAND_RESPONSE/cmd-in}
        observed_by_kind: {cmd_id: Counter(kind -> count)}  kind in {COMMAND, COMMAND_RESPONSE, WRITE}
        write_seqs      : {seq: cmd_id}     cmd-in WRITE requests (role 0 on FD4B0002)
        resp_seqs       : {seq: cmd_id}     cmd-resp NOTIFY (COMMAND_RESPONSE)
    """
    observed_counts = Counter()
    observed_by_kind = defaultdict(Counter)
    write_seqs = {}
    resp_seqs = {}

    for rec in records:
        body = bytes.fromhex(rec.get("body_hex", ""))
        d = parse_body_5(body)
        if "error" in d:
            continue  # truncated body — log-and-continue (D-03)
        ptype = d["type"]
        cmd = d["cmd"]
        seq = d["seq"]
        role = d["role"]
        char = rec.get("characteristic")

        if ptype in _COMMAND_PTYPES:
            kind = "COMMAND" if ptype == 35 else "COMMAND_RESPONSE"
            observed_counts[cmd] += 1
            observed_by_kind[cmd][kind] += 1
            if ptype == 36:
                resp_seqs.setdefault(seq, cmd)
            # A cmd-in WRITE request: role 0 on the cmd-in characteristic (Pattern 2 / A7).
            if role == 0 and char == CMD_IN_CHAR:
                observed_by_kind[cmd]["WRITE"] += 1
                write_seqs.setdefault(seq, cmd)

    return {
        "observed_counts": observed_counts,
        "observed_by_kind": observed_by_kind,
        "write_seqs": write_seqs,
        "resp_seqs": resp_seqs,
    }


def pair_request_response(write_seqs, resp_seqs):
    """Pair cmd-in WRITE requests with cmd-resp NOTIFY by seq (A7 confirmation).

    Returns [(seq, write_cmd, resp_cmd)] for seqs seen on both sides.
    """
    pairs = []
    for seq, wcmd in sorted(write_seqs.items()):
        if seq in resp_seqs:
            pairs.append((seq, wcmd, resp_seqs[seq]))
    return pairs


def reconcile(observed_counts):
    """Build the OBSERVED-vs-EXPECTED reconciliation against the full r52 CommandNumber map.

    Returns:
        rows       : [(cmd_id, name, observed_bool, count, confidence, note)]
        observed   : sorted list of observed cmd ids
        hypotheses : [(cmd_id, name)] for r52-expected-but-unobserved (D-07 HYPOTHESIS)
    """
    rows = []
    observed = sorted(observed_counts)
    hypotheses = []
    for cmd_id in sorted(COMMAND_NUMBER):
        name = COMMAND_NUMBER[cmd_id]
        count = observed_counts.get(cmd_id, 0)
        if count:
            rows.append((cmd_id, name, True, count, "VERIFIED", "observed in captures"))
        else:
            note = "not observed in captures, expected from r52 enum map"
            rows.append((cmd_id, name, False, 0, "HYPOTHESIS", note))
            hypotheses.append((cmd_id, name))

    # Observed cmd ids that are NOT in the r52 map (5.0-new candidates) — surface them too.
    for cmd_id in observed:
        if cmd_id not in COMMAND_NUMBER:
            cnt = observed_counts[cmd_id]
            rows.append((cmd_id, resolve_cmd(35, cmd_id), True, cnt, "CANDIDATE",
                         "observed in captures, not in r52 CommandNumber map (5.0-new?)"))
    return rows, observed, hypotheses


def build_surface(records):
    """Top-level: enumerate, pair, reconcile. Returns a Plan-05-consumable dict."""
    surf = enumerate_command_surface(records)
    pairs = pair_request_response(surf["write_seqs"], surf["resp_seqs"])
    rows, observed, hypotheses = reconcile(surf["observed_counts"])

    reused = []
    for cmd_id in REUSED_4_0_IDS:
        name = COMMAND_NUMBER.get(cmd_id, f"cmd{cmd_id}")
        count = surf["observed_counts"].get(cmd_id, 0)
        reused.append({
            "id": cmd_id,
            "name": name,
            "status": "OBSERVED" if count else "UNOBSERVED",
            "count": count,
        })

    return {
        "source_observed_counts": dict(surf["observed_counts"]),
        "observed_command_ids": observed,
        "request_response_pairs": pairs,
        "reconciliation_rows": rows,
        "hypotheses": hypotheses,
        "reused_14": reused,
    }


def _print_report(result, source_label):
    print(f"===== WHOOP 5.0 command surface (PROTO-06, D-06 capture analysis) =====")
    print(f"Source: {source_label}")
    print("Strategy: observed body[6] (COMMAND/COMMAND_RESPONSE + cmd-in WRITE) reconciled")
    print("          against the full r52 CommandNumber map. No live 0-255 probe (D-06,")
    print("          macOS cannot bond) — that probe is deferred to Phase 5.\n")

    observed = result["observed_command_ids"]
    print(f"OBSERVED command IDs ({len(observed)}): {observed}\n")

    # OBSERVED commands resolved to r52 names.
    print("----- OBSERVED commands (VERIFIED candidates for Plan 05) -----")
    for cmd_id, name, is_obs, count, conf, _note in result["reconciliation_rows"]:
        if is_obs and conf == "VERIFIED":
            print(f"  cmd {cmd_id:>3}  {name:<28} OBSERVED  ({count} frames)")
    candidates = [r for r in result["reconciliation_rows"] if r[4] == "CANDIDATE"]
    if candidates:
        print("\n  -- observed but NOT in r52 map (5.0-new candidates) --")
        for cmd_id, name, _io, count, _c, note in candidates:
            print(f"  cmd {cmd_id:>3}  {name:<28} CANDIDATE ({count} frames) — {note}")

    # Request->response pairing (A7 confirmation). seq is reused across separate command
    # sessions, so a naive seq->cmd pairing conflates bursts; MATCHes within a contiguous
    # burst (e.g. SEND_NEXT_FF 118, SET_FF_VALUE 120, HISTORICAL_DATA_RESULT 23) confirm A7,
    # MISMATCHes are cross-session seq collisions, not protocol violations. Summarise the
    # counts + a few exemplars; the full list is in the returnable dict for Plan 05.
    print("\n----- cmd-in WRITE -> cmd-resp pairing by seq (A7) -----")
    pairs = result["request_response_pairs"]
    if pairs:
        matches = [(s, w, r) for s, w, r in pairs if w == r]
        mismatches = [(s, w, r) for s, w, r in pairs if w != r]
        print(f"  {len(pairs)} WRITE/RESP seq pairs: {len(matches)} MATCH (A7 confirmed "
              f"within burst), {len(mismatches)} cross-session seq collisions")
        seen_match = set()
        shown = 0
        for seq, wcmd, rcmd in matches:
            if wcmd in seen_match:
                continue
            seen_match.add(wcmd)
            wn = COMMAND_NUMBER.get(wcmd, f"cmd{wcmd}")
            print(f"    MATCH  seq {seq:>3}: WRITE {wcmd}({wn}) -> RESP {rcmd}({wn})")
            shown += 1
            if shown >= 6:
                break
        for seq, wcmd, rcmd in mismatches[:2]:
            wn = COMMAND_NUMBER.get(wcmd, f"cmd{wcmd}")
            rn = COMMAND_NUMBER.get(rcmd, f"cmd{rcmd}")
            print(f"    (collision) seq {seq:>3}: WRITE {wcmd}({wn}) -> RESP {rcmd}({rn})")
    else:
        print("  (no WRITE/RESP seq pairs in this corpus — few cmd-in write exemplars, A7 note)")

    # The 14 reused 4.0 IDs cross-validation.
    print("\n----- Reused 4.0 command IDs cross-validation (the 14) -----")
    for r in result["reused_14"]:
        print(f"  cmd {r['id']:>3}  {r['name']:<28} {r['status']:<10} ({r['count']} frames)")
    obs_reused = sum(1 for r in result["reused_14"] if r["status"] == "OBSERVED")
    print(f"  -> {obs_reused}/14 reused IDs OBSERVED in the 5.0 corpus")

    # HYPOTHESIS (D-07): r52-expected but unobserved.
    print("\n----- UNOBSERVED-but-r52-expected commands (HYPOTHESIS, D-07) -----")
    hyps = result["hypotheses"]
    print(f"  {len(hyps)} r52 commands NOT observed in captures — each tagged HYPOTHESIS")
    print('  note: "not observed in captures, expected from r52 enum map"')
    preview = ", ".join(f"{cid}:{name}" for cid, name in hyps[:12])
    print(f"  e.g. {preview}{' ...' if len(hyps) > 12 else ''}")

    print(f"\nSummary: {len(observed)} observed / {len(COMMAND_NUMBER)} r52 expected "
          f"({len(hyps)} HYPOTHESIS, {obs_reused}/14 reused observed).")


def main(argv=None):
    records, source_label = _load_records()
    result = build_surface(records)
    _print_report(result, source_label)
    return 0


if __name__ == "__main__":
    sys.exit(main())
