# Architecture Research

**Domain:** iOS BLE wearable — Ghidra RE + SwiftUI 1:1 redesign over existing offline-first app
**Researched:** 2026-06-01
**Confidence:** HIGH — based on direct reading of source files, existing notes, and Ghidra session findings

---

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│  GHIDRA RE LAYER (Mac, offline, pre-dev)                             │
│  ┌────────────────┐  ┌──────────────────┐  ┌────────────────────┐   │
│  │  IPA 5.37.0    │  │  Ghidra MCP      │  │  RE Scripts        │   │
│  │  (477k funcs)  │  │  (query bridge)  │  │  re/*.py           │   │
│  └───────┬────────┘  └────────┬─────────┘  └────────────────────┘   │
│          └─────────────────────┘                                      │
│                    │ findings → FINDINGS_5.md, notes/                 │
├────────────────────┼─────────────────────────────────────────────────┤
│  iOS APP LAYER     ↓                                                  │
│  ┌─────────────────────────────────────────────────────────────┐     │
│  │  Design/Components/   (card-level UI — replaces existing)   │     │
│  │  RecoveryCard  SleepCard  StrainCard  HypnogramView          │     │
│  │  MetricCard    ZoneRingView  Sparkline  RecoveryRing         │     │
│  └───────────────────────────┬─────────────────────────────────┘     │
│  ┌────────────────────────────┴────────────────────────────────┐     │
│  │  Tabs/   (screen-level views — update in-place)             │     │
│  │  TodayView  SleepView  StrainView  TrendsView  Device       │     │
│  └───────────────────────────┬─────────────────────────────────┘     │
│  ┌────────────────────────────┴────────────────────────────────┐     │
│  │  Metrics Layer                                               │     │
│  │  MetricsRepository (@EnvironmentObject, @Published)         │     │
│  │  LocalMetricsComputer (offline-first, sole truth)           │     │
│  └───────────────────────────┬─────────────────────────────────┘     │
│  ┌────────────────────────────┴────────────────────────────────┐     │
│  │  Collect / BLE Layer                                         │     │
│  │  BLEManager  Backfiller  Collector  WhoopStore (GRDB actor) │     │
│  └─────────────────────────────────────────────────────────────┘     │
├──────────────────────────────────────────────────────────────────────┤
│  SERVER (optional backup — gonzaga / Dockge)                         │
│  FastAPI + TimescaleDB — upload only; server pull disabled           │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Status for v4.0 |
|-----------|----------------|-----------------|
| Ghidra MCP | Query IPA 5.37.0 ARM64 Swift binary for UI structure, labels, data layout | Input tool — used in RE phase, not shipped |
| `re/*.py` scripts | Protocol analysis, biometric offset verification | Existing, expand as needed |
| `Design/DesignTokens.swift` | `WH.*` colour/spacing/font constants — single visual truth | Update tokens if Ghidra reveals IPA colours |
| `Design/Components/*.swift` | Card-level reusable views (RecoveryCard, SleepCard, StrainCard, etc.) | Modify in-place OR replace with 1:1 IPA replica |
| `Tabs/*.swift` | Screen-level tab views; consume MetricsRepository | Update in-place to use revised components |
| `MetricsRepository` | `@EnvironmentObject`; publishes `today`, `lastNight`, trend arrays | No change for v4.0 |
| `LocalMetricsComputer` | Offline-first algorithm engine — sole source of truth | No change for v4.0 |
| `WhoopStore` (GRDB actor) | On-device SQLite; WAL mode; migration versioned | Bug fixes only (schema v9 is current) |
| `BLEManager` | CoreBluetooth orchestrator; Maverick protocol | Bug fixes only |
| Server (FastAPI) | Upload backup only; pull disabled | No change for v4.0 |

---

## Ghidra → SwiftUI Integration Workflow

This is the critical architecture question for v4.0. The workflow has three phases that must not overlap:

### Phase A — RE (Ghidra) — Produces findings, not code

```
Ghidra MCP query (Mac)
  → Identify IPA view controller hierarchy
  → Map Swift class names → screen purpose
  → Extract string constants (labels, units, formats)
  → Identify data fields used per screen
  → Document in FINDINGS_5.md / notes/
  → Commit findings as plain text/markdown BEFORE touching Swift
```

Ghidra output is research only. No code comes out of Ghidra directly. Output goes into:
- `FINDINGS_5.md` — protocol + UI structure additions
- `.planning/notes/` — session findings
- Potentially a new `docs/specs/v4-ui-map.md` — screen-by-screen IPA map

### Phase B — Design Decisions — Translates findings to component decisions

Before writing any Swift, for each screen found in Phase A, decide:

| Decision | Criteria |
|----------|----------|
| Modify existing component | IPA screen structure matches current SwiftUI card; only label/colour/layout changes |
| Replace component | IPA reveals fundamentally different layout (e.g. different metric grouping, new ring type) |
| Add new component | IPA screen has no equivalent in current codebase |

This decision lives in a per-screen spec (e.g. `docs/specs/v4-today-screen.md`).

### Phase C — SwiftUI Implementation — Only after Phase B decisions are documented

```
Ghidra findings (Phase A)
  → Design decisions (Phase B)
  → SwiftUI implementation (Phase C)
      → Update DesignTokens.swift (colours, spacing from IPA)
      → Modify OR replace components in Design/Components/
      → Update Tabs/ views to use revised components
      → Update DesignGallery.swift for QA
```

The three phases run sequentially per screen/feature cluster. Do not interleave RE and implementation.

---

## New vs Modified Components

### Components to MODIFY in-place

These exist and have the right purpose — update layout/labels/metrics to match IPA findings:

| Component | Current File | What Changes |
|-----------|-------------|--------------|
| `RecoveryCard` | `Design/Components/RecoveryCard.swift` | Labels verified IPA; ring colour thresholds confirmed (green ≥67, yellow 33–66, red <34) |
| `SleepCard` | `Design/Components/SleepCard.swift` | Stage bar layout; "SLEEP PERFORMANCE" / "HOURS OF SLEEP" labels already IPA-verified in v3.0 |
| `StrainCard` | `Design/Components/StrainCard.swift` | Gauge arc design; Training State badge |
| `MetricCard` | `Design/Components/MetricCard.swift` | HRV / RHR / Calories / Sleep Needed metric tiles |
| `HypnogramView` | `Tabs/HypnogramView.swift` | Stage colour mapping (already done in v3.0); timeline resolution |
| `RecoveryRing` | `Design/Components/RecoveryRing.swift` | Gradient fill; stroke width from IPA measurements |
| `DesignTokens.swift` | `Design/DesignTokens.swift` | Add/adjust any colour hex values found in IPA |
| `TodayView` | `Tabs/TodayView.swift` | Layout order, ScreenHeader format |
| `SleepView` | `Tabs/SleepView.swift` | Stage breakdown bar, "SKIN TEMP FROM BASELINE" section |
| `StrainView` | `Tabs/StrainView.swift` | Full strain screen layout |
| `TrendsView` | `Tabs/TrendsView.swift` | Metric selector, chart style |

### Components to POTENTIALLY REPLACE (decide after RE)

These may need a full rewrite if the IPA reveals fundamentally different structure:

| Component | Trigger for Replacement |
|-----------|------------------------|
| `ZoneRingView` | If IPA uses a different zone visualisation (stacked bar vs ring) |
| `SevenNightChart` | If IPA sleep week view differs significantly |
| `TrendChartCard` | If IPA trends section uses different chart type |

### New Components (if Ghidra reveals screens with no current equivalent)

To be determined from RE phase. Candidates:
- A "Coach" screen equivalent (WHOOP app has coaching recommendations)
- A detailed Strain drill-down beyond current WorkoutsView
- Day-level recovery detail screen

New components go in `Design/Components/NewComponentName.swift` following the existing pattern: pure `View` structs, init params only, no `@EnvironmentObject` inside.

---

## Bug Fix Architecture

### Where bug fix commits live relative to feature work

Bug fixes and UI feature work are distinct commit streams. The ordering principle:

```
Phase 1: Bug fixes (isolated, non-destructive)
  → Each bug fix is a standalone commit on main
  → Does NOT touch UI component files
  → Does NOT touch DesignTokens.swift

Phase 2: RE findings (Ghidra, markdown only)
  → Commits to FINDINGS_5.md, notes/, docs/specs/
  → No Swift changes

Phase 3: Design token updates (DesignTokens.swift only)
  → Single commit or small PR
  → UI components may break briefly — acceptable

Phase 4: Component updates (Design/Components/ and Tabs/)
  → One commit per component or screen
  → Additive: new components in new files; modified components in-place
```

This ordering ensures:
- Bug fixes are bisect-safe (no mixed-purpose commits)
- RE phase produces a clean audit trail (markdown only)
- UI changes are reversible per component

### Known Bug Fix Targets (from v3.0 analysis and notes)

| Bug | Location | Fix Strategy |
|-----|----------|--------------|
| RR offset / HRV corrupt data | `WhoopStore`, `LocalMetricsComputer` | Isolated fix; no UI changes |
| Backfill stuck mid-session | `BLEManager`, `Backfiller` | Isolated BLE fix; no UI changes |
| UI placeholders not resolving | `TodayView`, `SleepView` | Data pipeline check before UI work |
| WHOOP 4.0 remnants in 5.0 code | Various files | Code audit pass; standalone refactor commits |

### Bug Fix Commit Strategy

Each bug fix is its own commit with the pattern:
```
fix(scope): description of what was wrong and what changed
```

Bug fix commits precede feature commits on the same branch. If a bug fix and a UI change both touch the same file (e.g. `SleepView.swift`), the bug fix ships first in a separate commit.

---

## Recommended Project Structure (v4.0 additions)

No structural changes to the existing layout. Additions only:

```
ios/OpenWhoop/
└── Design/
    ├── Components/
    │   ├── [existing components — modified in-place]
    │   └── [new components from RE — new files]
    └── DesignTokens.swift   ← primary v4.0 change target

docs/
└── specs/
    └── v4-ui-map.md         ← NEW: IPA screen-by-screen map from Ghidra

FINDINGS_5.md                ← extended with UI findings from Ghidra
```

No new Swift Packages. No new app targets. No new server routes.

---

## Architectural Patterns

### Pattern 1: RE-First, Code-Second

**What:** All Ghidra querying completes and produces a written findings document before any Swift file is modified.

**When to use:** Every v4.0 feature that originates from IPA analysis.

**Trade-offs:** Adds a mandatory RE step before coding; prevents incomplete IPA analysis leading to mid-implementation pivots.

### Pattern 2: Modify-in-Place Over Rebuild

**What:** Existing component files are updated rather than replaced unless the IPA reveals a fundamentally incompatible structure.

**When to use:** Label changes, colour updates, metric reordering, ring stroke adjustments.

**Trade-offs:** Preserves git history and reduces merge surface. Replacement is reserved for cases where IPA structure and current SwiftUI structure genuinely differ.

### Pattern 3: DesignTokens as Single Gate

**What:** All visual constants (colour hex, spacing values, font sizes) live in `DesignTokens.swift` (`WH.*` namespace). Component files reference only `WH.*` tokens — no hardcoded hex or pt values.

**When to use:** Every new or updated component for v4.0.

**Trade-offs:** One token update propagates to all consumers. Means DesignTokens must be updated before components, not after.

### Pattern 4: Pure View structs for components

**What:** Card/component views take init parameters only. No `@EnvironmentObject` inside `Design/Components/`. All data binding at the tab-level parent.

**When to use:** Every component in `Design/Components/`.

**Trade-offs:** Enforces testability and composability. DesignGallery can render any component without a MetricsRepository mock.

### Pattern 5: Isolated Bug Fixes

**What:** Bug fix commits change one logical layer and do not touch UI layout code. UI commits change layout code and do not touch data pipeline logic.

**When to use:** All v4.0 work.

**Trade-offs:** More commits, cleaner history, easier bisect.

---

## Data Flow (unchanged from v3.0)

### Algorithm source of truth

```
WhoopStore (GRDB)
  → LocalMetricsComputer.computeAll()
      → Recovery (HRV baseline 28 nights, Winsorized-EWMA)
      → Strain (TRIMP zones)
      → Sleep Performance (ALG-10)
      → Training State (ALG-11, recovery_to_strain.json bundled)
      → Sleep Needed (ALG-12)
      → Calories (ALG-13, Mifflin-St Jeor + Keytel workout)
  → WhoopStore upsert (dailyMetric table, v9 schema)
  → MetricsRepository.load()
  → @Published → SwiftUI re-render
```

Server path is backup-only and does not affect v4.0 UI work. `pullFromServer()` is a no-op.

### UI consumption pattern (preserved in v4.0)

```
Tab view (e.g. TodayView)
  @EnvironmentObject var metrics: MetricsRepository
  var today: DailyMetric? = metrics.today
  var lastNight: CachedSleepSession? = metrics.lastNight

  → RecoveryCard(score: today?.recovery, hrv: today?.avgHrv, ...)
  → SleepCard(session: lastNight, ...)
  → StrainCard(strain: today?.strain, trainingState: today?.trainingState, ...)
```

Components receive typed values, not the repository itself.

---

## Integration Points

### Ghidra MCP → Swift Implementation

| Ghidra Finding Type | How It Enters the Codebase |
|--------------------|---------------------------|
| UI label string constants | `DesignTokens.swift` or hardcoded in View struct (not l10n needed) |
| Colour hex values | `WH.Color.*` in `DesignTokens.swift` |
| Screen hierarchy / component grouping | `Tabs/*.swift` layout restructure |
| Data field names / metric order | Component init param order in `Design/Components/*.swift` |
| Algorithm coefficients | `LocalMetricsComputer` (already correct; Keytel confirmed via Ghidra) |
| Protocol packet offsets | `WhoopProtocol` Swift Package (bug fixes) |

### Internal Boundaries

| Boundary | Communication | v4.0 Change? |
|----------|---------------|--------------|
| Ghidra MCP → Swift | Markdown findings docs → manual implementation | One-way; no automated code gen |
| Tabs → Components | Function call (init params) | No change to pattern |
| Tabs → MetricsRepository | `@EnvironmentObject` read | No change |
| MetricsRepository → LocalMetricsComputer | Direct call on `BLEManager.onBackfillComplete` | No change |
| LocalMetricsComputer → WhoopStore | GRDB actor calls | No change |
| iOS → Server | Uploader POST (upload only; pull disabled) | No change |

---

## Anti-Patterns

### Anti-Pattern 1: Coding Before RE Is Complete

**What people do:** Start updating `RecoveryCard.swift` while still querying Ghidra for the Recovery screen layout.

**Why it's wrong:** Mid-implementation Ghidra findings often require restructuring the partially written component, wasting time and producing messy diffs.

**Do this instead:** Complete the Ghidra query for a screen, document findings in a spec, then implement. For large milestones, complete all RE before any Swift changes.

### Anti-Pattern 2: Mixing Bug Fixes and UI Changes in One Commit

**What people do:** Fix the RR offset bug while also updating the HRV label in MetricCard.

**Why it's wrong:** Makes bisect impossible. If the RR fix is reverted, the label change is also reverted (or requires cherry-pick).

**Do this instead:** Separate commits with separate scopes. `fix(hrv): remove RR offset` and `feat(ui): update HRV label to match IPA` are two commits.

### Anti-Pattern 3: Hardcoding Values Found in IPA

**What people do:** See `recoveryGreen = #16EC06` in Ghidra output, hardcode it inside `RecoveryCard.swift`.

**Why it's wrong:** Next time a colour needs changing, it must be found and updated in every component instead of one token file.

**Do this instead:** Update `WH.Color.recoveryGreen` in `DesignTokens.swift`; component references `WH.Color.recoveryGreen` already.

### Anti-Pattern 4: Adding @EnvironmentObject to Component Views

**What people do:** Give `RecoveryCard` a `@EnvironmentObject var metrics: MetricsRepository` to avoid passing parameters.

**Why it's wrong:** Breaks `DesignGallery` preview, makes component untestable in isolation, couples visual component to data layer.

**Do this instead:** Pass typed values from the parent tab view. Component receives only what it displays.

### Anti-Pattern 5: Restructuring the Repo Mid-Milestone

**What people do:** Move `ios/OpenWhoop/Tabs/` to `ios/OpenWhoop/Screens/` mid-feature development.

**Why it's wrong:** Creates a massive rename diff that obscures the actual feature work, breaks in-progress branches, and confuses git blame.

**Do this instead:** Repo cleanup is its own isolated phase with no concurrent feature work. The notes indicate "reorganizar o repositório" — this should be a standalone phase after all bug fixes and before UI work, or at the very end.

---

## Phase Build Order for v4.0

The build order follows the dependency graph of what unblocks what:

```
Phase 1: Bug Fixes (isolated, no UI)
  ↓ (fixes data pipeline integrity)

Phase 2: Ghidra RE — Full IPA screen map
  ↓ (produces specs, no Swift)

Phase 3: Repo Cleanup (rename/reorganise files)
  ↓ (clean slate for UI work)

Phase 4: DesignTokens update (token-level only)
  ↓ (components can now reference correct tokens)

Phase 5: Component updates (Design/Components/ and Tabs/)
  — one component per plan, RE-spec-driven
  — modify in-place or replace per Phase 2 decision

Phase 6: Hardware validation (PROTO-11/12/13/14)
  — parallel with Phase 5 where possible
  — gated on physical WHOOP + iPhone session
```

Phase 3 (repo cleanup) must complete before Phase 4–5 to avoid renames conflicting with active UI diffs. Phase 6 is hardware-dependent and can run in parallel with any software phase when hardware is available.

---

## Scaling Considerations

This is a single-device, single-user iOS app. Scaling concerns are not applicable. The constraints that matter:

| Concern | Current approach | v4.0 change? |
|---------|-----------------|-------------|
| App binary size | 61 Swift files, ~15k LOC — fine | Adding ~5–10 component files; negligible |
| GRDB migration safety | Versioned migrations v1–v9; actor-isolated | Bug fix migrations add v10+ |
| BLE reliability | Maverick protocol, safe-trim invariant | Bug fixes only |
| Offline-first | LocalMetricsComputer is sole truth | Preserved |

---

## Sources

- Direct reading of `ios/OpenWhoop/Design/`, `Tabs/`, `BLE/`, `Metrics/` — HIGH confidence
- `.planning/notes/ghidra-ios-algorithm-findings.md` — Ghidra session 2026-06-01 — HIGH confidence
- `.planning/notes/ghidra-ios-phases-scope.md` — Ghidra utility analysis — HIGH confidence
- `.planning/codebase/ARCHITECTURE.md` — existing codebase architecture — HIGH confidence
- `.planning/codebase/STRUCTURE.md` — existing codebase structure — HIGH confidence
- `.planning/research/ARCHITECTURE.md` (v2.0) — prior milestone architecture research — HIGH confidence
- `.planning/notes/2026-06-01-ble-sync-discoveries.md` — protocol discoveries — HIGH confidence

---
*Architecture research for: iOS v4.0 — Ghidra RE + 1:1 UI Redesign + Bug Fixes*
*Researched: 2026-06-01*
