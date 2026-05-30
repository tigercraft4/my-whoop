# WHOOP 5.0 survey workspace (`re/survey_5/`)

Isolated WHOOP **5.0** in-discovery BLE scripts (Phase 2), kept separate from the 4.0
production scripts in `re/` (decision D-04). The canonical findings document is
[`../../FINDINGS_5.md`](../../FINDINGS_5.md) — read it first for the confirmed GATT map,
the legacy-UUID verdict, the bonding outcome, and the Phase 2 success-criteria map.

## Setup

These scripts need **Python 3.10+** (bleak 3.x drops 3.9). Create the venv with a
Homebrew/pyenv Python 3.11:

```bash
python3.11 -m venv re/survey_5/.venv
source re/survey_5/.venv/bin/activate
pip install -r re/survey_5/requirements.txt   # bleak==3.0.2
```

The `.venv/` is gitignored.

## Device identity (gitignored)

The real CoreBluetooth peripheral UUID / serial lives only in
`re/survey_5/device_local_5.py`, which is **gitignored**. Create it from the committed
template and fill in your Mac's CoreBluetooth UUID for the strap:

```bash
cp re/survey_5/device_local_5.example.py re/survey_5/device_local_5.py
# edit DEVICE_UUID — it is Mac-specific (CoreBluetooth UUID, NOT a MAC; may change after a BT reset)
```

`gatt_dump_5.json` (written by `survey_gatt_5.py`) is also gitignored — it embeds the
real device name + CoreBluetooth address and stays local only.

## Scripts

Run from inside the workspace, e.g. `cd re/survey_5 && .venv/bin/python survey_gatt_5.py`.
Force-quit the official WHOOP app first — only one BLE central can connect at a time.

| Script | Purpose |
|---|---|
| `survey_gatt_5.py` | GATT enumeration (`client.services`) + Phase 1 handle→UUID cross-check; writes `gatt_dump_5.json` |
| `bond_5.py` | Confirmed-write (`response=True`) bonding trigger on cmd-in; documents the iOS-only result + D-03b SMP fallback |
| `hr_5.py` | Standard HR (`0x2A37`) notify subscription + battery (`0x2A19`) read using the validated `parse_hr` |

## Bonding fallback runbooks

The confirmed-write trick does **not** auto-bond on macOS (see `FINDINGS_5.md` §3). For the
SMP-visible pairing evidence (ROADMAP criterion 3), capture the official app's handshake:

- [`../capture/ios-packetlogger.md`](../capture/ios-packetlogger.md) — PacketLogger SMP capture of the official-app pairing (D-03b fallback)
- [`../capture/wireshark.md`](../capture/wireshark.md) — `tshark -Y btsmp` analysis of the captured handshake

Scrub BD_ADDR and any pairing-key bytes before committing any `.hex` evidence
(DISCLAIMER §2 + evidence policy).
