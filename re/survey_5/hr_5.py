"""Read standard BLE services on the WHOOP 5.0: battery, manufacturer, and Heart Rate
Measurement (HR + RR).

Near-verbatim port of re/standard_ble.py (4.0). The standard GATT UUIDs are identical
across 4.0 and 5.0 — the only change is the device import (device_local_5). Run AFTER
bond_5.py in the same fresh-state session to confirm the bond unlocks notifications
end-to-end (standard characteristics also work unbonded, but running after bond proves
the full chain). HR reads 0 / no-contact while charging off-wrist — wear the strap
during the run to confirm live BPM.
"""
import asyncio
from bleak import BleakClient, BleakScanner

from device_local_5 import DEVICE_UUID as ADDR
BATTERY = "00002a19-0000-1000-8000-00805f9b34fb"
MANUF = "00002a29-0000-1000-8000-00805f9b34fb"
HR_MEAS = "00002a37-0000-1000-8000-00805f9b34fb"


def parse_hr(data: bytearray):
    """Parse standard Heart Rate Measurement (0x2A37): flags, HR, optional RR intervals."""
    if len(data) < 2:
        return 0, [], list(data)
    flags = data[0]
    hr_16bit = flags & 0x01
    idx = 1
    if hr_16bit:
        hr = int.from_bytes(data[idx:idx + 2], "little"); idx += 2
    else:
        hr = data[idx]; idx += 1
    rr_present = (flags >> 4) & 0x01
    rrs = []
    if rr_present:
        while idx + 2 <= len(data):
            rr_raw = int.from_bytes(data[idx:idx + 2], "little")
            rrs.append(round(rr_raw / 1024 * 1000, 1))  # 1/1024s units -> ms
            idx += 2
    return hr, rrs, list(data)


async def main():
    dev = await BleakScanner.find_device_by_address(ADDR, timeout=15.0)
    if dev is None:
        print("Device not found."); return
    async with BleakClient(dev) as client:
        print(f"Connected: {client.is_connected}\n")
        batt = await client.read_gatt_char(BATTERY)
        print(f"Battery: {int(batt[0])}%")
        try:
            manuf = await client.read_gatt_char(MANUF)
            print(f"Manufacturer: {manuf.decode(errors='replace')}")
        except Exception as e:
            print(f"Manufacturer read failed: {e}")

        print("\nSubscribing to Heart Rate Measurement (0x2A37) for 12s...")
        print("(HR will read 0 / no-contact while charging off-wrist — that's expected.)")
        count = 0

        def cb(_, data: bytearray):
            nonlocal count
            count += 1
            hr, rrs, raw = parse_hr(data)
            print(f"  HR={hr} bpm  RR={rrs}  raw={raw}")

        await client.start_notify(HR_MEAS, cb)
        await asyncio.sleep(12)
        await client.stop_notify(HR_MEAS)
        print(f"\nReceived {count} HR notifications.")


asyncio.run(main())
