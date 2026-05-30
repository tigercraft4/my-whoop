"""Enumerate the WHOOP 5.0 GATT table programmatically (Bleak cross-check of the nRF Connect survey).

Port of re/gatt_dump.py adapted for 5.0 (Phase 2, Wave 2 — D-04). Run AFTER the nRF Connect
visual survey (Wave 1) has confirmed the UUIDs in FINDINGS_5.md. This script closes the Phase 1
handle->UUID loop (D-02) from the Bleak side: it prints every service/characteristic with its
integer handle and flags the three Phase 1 handles (0x099b cmd-in, 0x099d cmd-resp, 0x09a3 data).

macOS note: device_local_5.DEVICE_UUID must be a CoreBluetooth peripheral UUID string, NOT a MAC
address — CoreBluetooth does not expose MAC addresses. bleak 3.x uses the `client.services`
property (the old async service-fetch coroutine was removed in bleak 1.0+ — iterate directly).

Bleak handle note: on macOS/CoreBluetooth, char.handle is the *declaration* handle; the *value*
handle is declaration + 1. Phase 1 PacketLogger captures used value handles, so we match on
char.handle + 1 against the PHASE1_HANDLES set.

Run from inside re/survey_5/ so `device_local_5` is importable:
    cd re/survey_5 && .venv/bin/python survey_gatt_5.py
"""
import asyncio
import json

from bleak import BleakClient, BleakScanner

from device_local_5 import DEVICE_UUID as ADDR

# Phase 1 ATT value handles (re/capture/evidence/2026-05-30-ios.meta.yaml).
# Bleak returns declaration handles; value handle = declaration + 1 (macOS/CoreBluetooth).
# Corrected by Wave 2 programmatic survey:
#   0x099b -> FD4B0002 (cmd-in),  0x099d -> FD4B0003 (cmd-resp),  0x09a3 -> FD4B0005 (data)
PHASE1_HANDLES = {0x099b, 0x099d, 0x09a3}

OUT_PATH = "gatt_dump_5.json"


async def main():
    print("Scanning to get device handle...")
    dev = await BleakScanner.find_device_by_address(ADDR, timeout=15.0)
    if dev is None:
        print("Device not found in scan. Is it awake/in range? (WHOOP app force-quit?)")
        return
    print(f"Found: {dev.name} ({dev.address})")
    print("Connecting...")

    result = {"device": dev.name, "address": str(dev.address), "services": []}

    async with BleakClient(dev) as client:
        print(f"Connected: {client.is_connected}\n")
        print("=== GATT SERVICES & CHARACTERISTICS ===")
        for service in client.services:
            print(f"\n[Service 0x{service.handle:04x}] {service.uuid}  ({service.description})")
            svc = {
                "uuid": service.uuid,
                "handle": service.handle,
                "description": service.description,
                "characteristics": [],
            }
            for char in service.characteristics:
                props = ",".join(char.properties)
                flag = " <<< PHASE1 MATCH" if (char.handle + 1) in PHASE1_HANDLES else ""
                print(
                    f"  [Char 0x{char.handle:04x}] {char.uuid}  props=({props})"
                    f"  ({char.description}){flag}"
                )
                descs = []
                for desc in char.descriptors:
                    print(f"    [Desc 0x{desc.handle:04x}] {desc.uuid}")
                    descs.append({"uuid": desc.uuid, "handle": desc.handle})
                svc["characteristics"].append({
                    "uuid": char.uuid,
                    "handle": char.handle,
                    "properties": list(char.properties),
                    "descriptors": descs,
                })
            result["services"].append(svc)

    matched = [
        f"0x{c['handle']+1:04x}->{c['uuid']}"
        for s in result["services"]
        for c in s["characteristics"]
        if (c["handle"] + 1) in PHASE1_HANDLES
    ]
    print(f"\nPhase 1 handle matches: {matched if matched else 'NONE (check bonding / handle range)'}")

    with open(OUT_PATH, "w") as f:
        json.dump(result, f, indent=2)
    print(f"\n{OUT_PATH} written ({len(result['services'])} services)")


asyncio.run(main())
