# Roadmap — WHOOP 5.0

**Project:** my-whoop (clean fork for WHOOP 5.0)

---

## Milestones

- ✅ **v1.0 — WHOOP 5.0 Protocol + iOS App** — Phases 1–5 (shipped 2026-05-31)
- 📋 **v2.0** — TBD (run `/gsd-new-milestone` to define)

---

## Phases

<details>
<summary>✅ v1.0 — WHOOP 5.0 Protocol + iOS App (Phases 1–5) — SHIPPED 2026-05-31</summary>

- [x] Phase 1: Capture Foundation (3/3 plans) — completed 2026-05-30
- [x] Phase 2: GATT Survey & Bonding (4/4 plans) — completed 2026-05-30
- [x] Phase 3: Framing Confirmation — Critical Gate (3/3 plans) — completed 2026-05-30
- [x] Phase 4: Protocol Decode & Schema (5/5 plans) — completed 2026-05-30
- [x] Phase 5: iOS App & Server Port (6/6 plans) — completed 2026-05-31

Full archive: `.planning/milestones/v1.0-ROADMAP.md`

</details>

---

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Capture Foundation | v1.0 | 3/3 | Complete | 2026-05-30 |
| 2. GATT Survey & Bonding | v1.0 | 4/4 | Complete | 2026-05-30 |
| 3. Framing Confirmation | v1.0 | 3/3 | Complete | 2026-05-30 |
| 4. Protocol Decode & Schema | v1.0 | 5/5 | Complete | 2026-05-30 |
| 5. iOS App & Server Port | v1.0 | 6/6 | Complete | 2026-05-31 |

---

## Backlog

### Phase 999.1: Follow-up — Phase 1 Android device items (BACKLOG)

**Goal:** Resolve Phase 1 verification failures that require a physical Android device
**Source phase:** 1
**Deferred at:** 2026-05-30 during /gsd-progress --next advancement to Phase 2
**Root cause:** No Android device available during Phase 1 execution — runbooks are complete and ready
**Plans:**
- [ ] Android btsnoop live capture: enable HCI snoop, run `adb bugreport`, produce evidence triplet under `re/capture/evidence/` (ROADMAP criterion 2, TOOL-02)
- [ ] JADX-GUI APK live navigation: pull split APK via `adb shell pm path`, navigate to Maverick/packet-type enums, produce enum notes cross-referenced against whoop-vault r52 (ROADMAP criterion 4, TOOL-03)

**Unblocked by:** Access to a physical Android device running the WHOOP app

### Phase 999.2: Hardware validation — v1.0 UNCERTAIN items (BACKLOG)

**Goal:** Validate the 5 hardware-dependent items deferred at v1.0 close
**Deferred at:** 2026-05-31 during v1.0 milestone close
**Plans:**
- [ ] IOS-03/04/05: Today/Sleep/Trends views — requires WHOOP with unsynced data (don't use official app for 1+ week)
- [ ] IOS-06: 14+ day historical backfill with safe-trim invariant (same session as above)
- [ ] IOS-08: Background reconnect after force-quit — 30s test on physical iPhone
- [ ] PROTO-02 D-03b: SMP PacketLogger capture during official-app re-bonding
- [ ] PROTO-11/12/13/14: IMU/SpO2/skin temp/respiration — requires dedicated TOGGLE_IMU_MODE capture session

**Unblocked by:** Physical iPhone + WHOOP with fresh data; available development session
