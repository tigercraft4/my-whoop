"""Bond to the WHOOP 5.0 via the confirmed-write trick — no official app needed.

Port of re/bond_attempt.py (4.0) to the 5.0 custom service. Triggers CoreBluetooth's
implicit "just-works" bonding by issuing a confirmed write (ATT Write Request,
response=True) on the 5.0 cmd-in characteristic (D-03). The 5.0 inner framing is not
yet confirmed (Phase 3 territory), so this script uses RAW bytes only — no inner-frame
parsing, no sys.path hack.

Fresh-state setup REQUIRED before running (Common Pitfalls 1-3):
  1. Force-quit the official WHOOP app on iPhone (Pitfall 1 — one BLE central at a time).
  2. Forget Device on iPhone.
  3. Remove the strap from macOS System Settings -> Bluetooth (Option+click -> Remove)
     so the Mac re-negotiates a clean bond (Pitfall 2). The macOS peripheral UUID can
     change after these events (Pitfall 3) — re-scan and refresh device_local_5.py if so.

Fallback (D-03b) if the confirmed write does NOT trigger bonding:
  Capture the official app's SMP pairing handshake via PacketLogger per
  re/capture/ios-packetlogger.md, then analyze with `tshark -Y btsmp` to identify the
  exact write sequence (RESEARCH §SMP Capture and Filter Reference). SMP packets visible
  in PacketLogger is the ROADMAP criterion 3 proof.
"""
import asyncio
import time

from bleak import BleakClient, BleakScanner

from device_local_5 import DEVICE_UUID as ADDR

# Confirmed WHOOP 5.0 UUIDs (nRF Connect survey, Wave 1 — 02-01-SUMMARY / FINDINGS_5.md).
# Custom service: FD4B0001-CCE1-4033-93CE-002D5875F58A
CMD_IN_5 = "FD4B0002-CCE1-4033-93CE-002D5875F58A"   # cmd-in,   write,  handle 0x099b
CMD_RESP_5 = "FD4B0003-CCE1-4033-93CE-002D5875F58A"  # cmd-resp, notify, handle 0x099d
EVENTS_5 = "FD4B0004-CCE1-4033-93CE-002D5875F58A"    # events,   notify, handle 0x09a3

_PLACEHOLDER = "XXXX"
for _name, _uuid in (("CMD_IN_5", CMD_IN_5), ("CMD_RESP_5", CMD_RESP_5), ("EVENTS_5", EVENTS_5)):
    if _PLACEHOLDER in _uuid.upper():
        print(f"WARNING: {_name} is still a placeholder ({_uuid}) — fill from FINDINGS_5.md before running.")

t0 = time.time()


def mk(name):
    def cb(_, data):
        # 5.0 framing unconfirmed — print raw hex only (no inner-frame parse).
        print(f"[{time.time()-t0:5.1f}s] {name}: {bytes(data).hex()}", flush=True)
    return cb


async def main():
    print("Scanning for the strap (fresh-state setup must be done first)...", flush=True)
    dev = await BleakScanner.find_device_by_address(ADDR, timeout=15.0)
    if dev is None:
        print("Device not found in scan. Is it awake/in range? App force-quit?")
        return
    print(f"Found: {dev.name} ({dev.address})", flush=True)

    async with BleakClient(dev) as client:
        print(f"Connected: {client.is_connected}", flush=True)

        # 1. Explicit pair attempt — raises NotImplementedError on macOS CoreBluetooth.
        #    This is EXPECTED; the confirmed write below is the real bonding trigger.
        try:
            res = await client.pair()
            print(f"client.pair() returned: {res}", flush=True)
        except Exception as e:
            print(f"client.pair() raised: {type(e).__name__}: {e} (expected on macOS)", flush=True)

        # 2. Subscribe to the custom notify channels first so any BLE_BONDED / response
        #    event is observable. Raw-hex callback (framing unconfirmed).
        try:
            await client.start_notify(CMD_RESP_5, mk("cmd_resp"))
            await client.start_notify(EVENTS_5, mk("events"))
        except Exception as e:
            print(f"start_notify raised: {type(e).__name__}: {e}", flush=True)

        # 3. Bonding trigger: confirmed write (response=True) on cmd-in.
        #    response=True is MANDATORY — Write Without Response (ATT Write Command)
        #    does NOT trigger encryption negotiation (RESEARCH §Anti-Patterns).
        #    Raw single null byte payload (5.0 framing not yet confirmed).
        print("\n--- confirmed write on cmd-in (may trigger pairing dialog / bonding) ---", flush=True)
        try:
            await client.write_gatt_char(CMD_IN_5, b"\x00", response=True)
            print(">>> confirmed write sent (CMD_IN_5, b'\\x00', response=True)", flush=True)
        except Exception as e:
            print(f"confirmed write raised: {type(e).__name__}: {e}", flush=True)

        # 4. Observe any BLE_BONDED event / notifications.
        print("Waiting 5s to observe bonding outcome / events...", flush=True)
        await asyncio.sleep(5)
        print("Done. If no bonding occurred, use the PacketLogger SMP fallback (D-03b).", flush=True)


asyncio.run(main())
