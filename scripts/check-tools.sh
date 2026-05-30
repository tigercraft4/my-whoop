#!/usr/bin/env bash
# Verify the passive-capture toolchain. Run from anywhere.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Version-floor rationale: Brewfile installs what brew delivers today (Wireshark 4.6.6,
# JADX 1.5.5, adb 37.0.0 / platform-tools 35.x). Floor pins match the D-03 intent while
# accepting newer versions. Wireshark 4.6.x dissects ATT/GATT identically to 4.4.x for
# BLE analysis purposes (Assumption A7, RESEARCH.md). Exact pins are not brew-achievable
# today (homebrew/versions is deprecated).

fail=0

assert_min() {
  # assert_min <name> <actual-version> <min-version>
  local name="$1" actual="$2" min="$3"
  if [ "$(printf '%s\n%s' "$min" "$actual" | sort -V | head -1)" != "$min" ]; then
    echo "FAIL $name: $actual < required $min"
    fail=1
  else
    echo "ok   $name: $actual (>= $min)"
  fi
}

# --- Hard-fail checks (required for capture toolchain) ---

# Wireshark CLI (tshark) >= 4.4.0
if command -v tshark >/dev/null 2>&1; then
  WS_VER="$(tshark --version 2>/dev/null | sed -n '1s/.* \([0-9][0-9.]*\).*/\1/p')"
  assert_min wireshark "$WS_VER" 4.4.0
else
  echo "FAIL wireshark (tshark): not found — run: brew bundle --file=Brewfile"
  fail=1
fi

# JADX >= 1.5.1
if command -v jadx >/dev/null 2>&1; then
  JADX_VER="$(jadx --version 2>/dev/null)"
  assert_min jadx "$JADX_VER" 1.5.1
else
  echo "FAIL jadx: not found — run: brew bundle --file=Brewfile"
  fail=1
fi

# adb >= 35.0.0 (Android Platform Tools 35.x ships adb 35.x)
if command -v adb >/dev/null 2>&1; then
  ADB_VER="$(adb --version 2>/dev/null | sed -n '1s/.* version \([0-9][0-9.]*\).*/\1/p')"
  assert_min adb "$ADB_VER" 35.0.0
else
  echo "FAIL adb (android-platform-tools): not found — run: brew bundle --file=Brewfile"
  fail=1
fi

# libimobiledevice — presence-check via ideviceinfo
if command -v ideviceinfo >/dev/null 2>&1; then
  echo "ok   libimobiledevice: ideviceinfo present"
else
  echo "FAIL libimobiledevice: ideviceinfo not found — run: brew bundle --file=Brewfile"
  fail=1
fi

# Java runtime — required by JADX (brew openjdk is keg-only; PATH/JAVA_HOME may need exporting)
if java -version >/dev/null 2>&1; then
  JAVA_VER="$(java -version 2>&1 | sed -n '1s/.*version "\([^"]*\)".*/\1/p')"
  echo "ok   java JRE: ${JAVA_VER:-present}"
else
  echo "FAIL java JRE: java -version failed — openjdk is keg-only; add to PATH:"
  echo "     echo 'export PATH=\"\$(brew --prefix openjdk)/bin:\$PATH\"' >> ~/.zprofile"
  fail=1
fi

# --- WARN-only checks (irreducible manual steps — cannot be installed by script) ---

if [ -d "/Applications/PacketLogger.app" ] || [ -d "$HOME/Applications/PacketLogger.app" ]; then
  echo "ok   PacketLogger: present"
else
  echo "WARN PacketLogger: not found (manual install required)"
  echo "     Download: Apple Developer Downloads → Additional Tools for Xcode → PacketLogger.app"
  echo "     Drag to /Applications or ~/Applications; no brew formula available."
fi

exit $fail
