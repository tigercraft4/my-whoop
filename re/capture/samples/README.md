# Raw captures live here — gitignored, never committed.
# These are personal identifiers — this directory's contents must never be committed.
#
# What belongs here (all gitignored via re/capture/samples/* in root .gitignore):
#   - Raw iOS BLE captures: *.pklg files from PacketLogger
#   - Raw Android HCI logs: *.btsnoop / btsnoop_hci.log from adb bugreport extraction
#   - Decompiled APK / JADX project output: apk/ subdirectory
#
# Why gitignored: raw captures may contain Bluetooth device IDs and SMP bonding material
# (DISCLAIMER §2; D-02). Decompiled APK source is proprietary material (DISCLAIMER §2; D-04).
#
# What to commit instead: redacted hex excerpts + SHA256 checksums + metadata sidecars
# go under re/capture/evidence/ (which IS committed).
#
# See re/capture/README.md for the full redaction workflow and evidence checklist.
