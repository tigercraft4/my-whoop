#!/usr/bin/env bash
# Sync the canonical WHOOP 5.0 (Maverick) decode schema into its Swift consumer.
# Run from anywhere. Mirrors scripts/sync-schema.sh (4.0), retargeted to the _5 variant
# and hardened with a JSON-validation step before the copy (SCHEMA-05 / T-04-06).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CANON="$ROOT/protocol/whoop_protocol_5.json"
PKG="$ROOT/Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json"

# Validate the canonical schema exists and is well-formed JSON BEFORE copying it
# into the Swift bundle (T-04-06: never sync invalid JSON). Fail loudly with a
# non-zero exit and a precise error message in each failure case.
if [[ ! -f "$CANON" ]]; then
  echo "ERROR: $CANON not found — cannot sync." >&2
  exit 1
fi
# Pass $CANON as an argument (sys.argv[1]) rather than embedding it in the -c
# string so paths with spaces are handled correctly and without quoting hazards.
if ! python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$CANON"; then
  echo "ERROR: $CANON is not valid JSON — refusing to sync." >&2
  exit 1
fi

# mkdir -p is load-bearing: the 5.0 Resources file does not yet exist in fresh checkouts.
mkdir -p "$(dirname "$PKG")"
cp "$CANON" "$PKG"
echo "validated + synced → $PKG"

# Home-server branch: the 4.0 sync-schema.sh also mirrors to $HOME_SERVER_REPO. The 5.0
# home-server whoop-protocol consumer does not exist yet (Phase 5 scope). We OMIT the
# server sync for now rather than guess a path; add it when the 5.0 server package lands.
