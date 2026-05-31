# Reverse-engineering

Scripts and notes from decoding the WHOOP BLE protocol. This directory covers **WHOOP 4.0**
scripts; for **WHOOP 5.0**, see `survey_5/` and `FINDINGS_5.md`.

## Authoritative references

| Document | What it covers |
|---|---|
| `../FINDINGS_5.md` | **WHOOP 5.0** — full protocol reference: Maverick framing, GATT map, commands, events, biometric decode, historical offload |
| `../FINDINGS.md` | **WHOOP 4.0** — complete protocol reference |

## Directory layout

```
re/
├── survey_5/         WHOOP 5.0 BLE discovery scripts (bleak, isolated venv)
│   ├── survey_gatt_5.py    GATT enumeration
│   ├── bond_5.py           Confirmed-write bonding trigger
│   ├── hr_5.py             Live HR (0x2A37) + battery (0x2A19)
│   ├── decode_5.py         Full-corpus Maverick decoder (Phase 4)
│   ├── validate_frames_5.py 4.0 CRC gate + Maverick consistency check
│   └── README.md           Setup + script guide
├── capture/          Capture runbooks (PacketLogger, btsnoop, Wireshark, JADX)
├── re_harness.py     WHOOP 4.0 RE harness — command probe + live decode
├── decode.py         WHOOP 4.0 frame decoder
├── gatt_dump.py      WHOOP 4.0 GATT enumeration
├── *.py              WHOOP 4.0 analysis scripts
└── device_local.example.py  Device identity template (copy → device_local.py, gitignored)
```

## WHOOP 5.0 RE workspace (`survey_5/`)

See [`survey_5/README.md`](survey_5/README.md) for full setup. Quick start:

```bash
python3.11 -m venv re/survey_5/.venv
source re/survey_5/.venv/bin/activate
pip install -r re/survey_5/requirements.txt        # bleak==3.0.2

cp re/survey_5/device_local_5.example.py re/survey_5/device_local_5.py
# Edit DEVICE_UUID — your Mac's CoreBluetooth UUID for the WHOOP 5.0 strap

cd re/survey_5
.venv/bin/python survey_gatt_5.py   # GATT enumeration
.venv/bin/python bond_5.py          # bonding trigger
.venv/bin/python hr_5.py            # live HR + battery
.venv/bin/python validate_frames_5.py  # CRC gate + Maverick check
.venv/bin/python decode_5.py           # full-corpus decode
```

**Key 5.0 findings:**
- Custom service: `FD4B0001-CCE1-4033-93CE-002D5875F58A`
- Framing: Maverick outer wrapper (`[0xAA][0x01][len u16][role][token 3B][body]`); 4.0 CRC gate passes 0%
- Write/read asymmetry: phone sends 4.0-format commands; WHOOP sends Maverick-format responses
- Body decode: offset +4 from Maverick body start (after `[type][seq]`)

## WHOOP 4.0 scripts

These scripts depend on third-party clones that are intentionally **not** committed (gitignored):

- `whoomp/` — github.com/jogolden/whoomp — firmware-extracted protocol reference
- `whoop-reader/` — provides the local Python venv (`whoop-reader/.venv`) used to run the 4.0
  scripts and `../scripts/gen_golden.py`

Clone/recreate these locally to run the 4.0 RE scripts; they are not needed to build the app.

```bash
cp re/device_local.example.py re/device_local.py  # fill in your 4.0 device identifiers
```

## Capture runbooks

See [`capture/README.md`](capture/README.md) for step-by-step guides on:
- **PacketLogger** (iOS, Mac) — primary 5.0 and 4.0 capture source
- **btsnoop** (Android) — secondary reference capture
- **Wireshark** — ATT/GATT analysis of `.pklg` and `.btsnoop` files
- **JADX-GUI** — WHOOP APK decompilation for enum cross-reference
