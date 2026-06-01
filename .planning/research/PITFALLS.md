# Pitfalls Research — OpenWhoop v4.0

**Domain:** Ghidra Swift binary RE + SwiftUI 1:1 proprietary redesign + BLE/HRV bug fixes + mixed Swift/Python repo cleanup
**Researched:** 2026-06-01
**Confidence:** HIGH on BLE offset bugs (grounded in retrospective + actual code); HIGH on Ghidra Swift ARM64 RE (well-documented domain with consistent failure modes); MEDIUM on SwiftUI proprietary UI replication (project-specific); HIGH on repo reorganisation (well-understood pitfalls for mixed-language repos).

> This file covers v4.0 pitfalls only. v2.0 and v3.0 pitfalls (HealthKit, algorithm integration,
> backfill, JADX, SwiftUI restructure) are documented in the version of this file tagged at those
> milestones. Pitfalls already addressed in prior milestones are not repeated here unless a new
> variant applies.

---

## Area 1 — Ghidra: Reverse-Engineering Obfuscated Swift Binaries (ARM64)

### G-P1: Swift name mangling makes symbol lookup unreliable — demangled names are hypotheses, not facts

**What goes wrong:**
Swift compiles to mangled symbols (`_$s12SomeFoo...`). Ghidra's Swift demangler is incomplete for
complex generic types, closures, and protocol witness tables. A class named
`SleepPerformanceCalculator` in Ghidra may actually be `_SleepPerformanceCalculator_private` or an
anonymous helper. When you search for a class name and find a result, you may have found an
unrelated symbol with a similar mangled prefix.

v3.0 precedent: IPA analysis confirmed class names like `SleepPerformanceCalculator` and
`TrainingStateCalculator` directly drove ALG-10..13 implementation. That success was possible
because WHOOP does **not** obfuscate class names (they appear in Objective-C runtime metadata
and Swift reflection). If v4.0 analysis targets more obfuscated code paths (UI layout logic,
proprietary algorithm coefficients), mangled names will be less reliable.

**Why it happens:**
Ghidra's Swift support is still maturing. Closures are compiled as anonymous types; generic
specialisations produce long mangled suffixes. A match on the human-readable demangled name
does not guarantee the function is what you think it is.

**How to avoid:**
- Verify every function by cross-referencing: (a) demangled name, (b) caller context (what
  calls this function), (c) decompiled body structure (does it read the fields you expect?).
- Use `class-dump` or `swift-demangle` on the raw binary before opening Ghidra — build a
  reference name list independently, then match in Ghidra rather than relying solely on
  Ghidra's built-in demangler.
- When a class name cannot be verified by all three criteria, tag the finding as HYPOTHESIS
  in FINDINGS_5.md (same discipline as protocol fields).

**Warning signs:**
- Ghidra shows a function body with zero cross-references — likely a dead code artefact or
  demangler error, not the real implementation.
- A demangled name contains `_private` suffix or long numeric suffix — likely a specialisation
  of a different function.
- The 477k-function corpus means false positive matches by name substring are frequent. Any
  search returning > 5 results for a UI class name warrants manual disambiguation.

**Phase to address:** Ghidra deep-dive phase (Phase 1 of v4.0).

---

### G-P2: ARM64 Swift calling conventions differ from C — Ghidra's default decompilation is wrong for Swift

**What goes wrong:**
Ghidra decompiles ARM64 as generic C. Swift on ARM64 uses:
- `x20` as the Swift self register (not `x0` as in C);
- indirect return via `x8` for large structs (not on the stack as C might show);
- `@convention(swift)` functions pass error via an extra pointer argument in `x21`;
- `@MainActor` functions dispatch through the Swift runtime, adding an indirection layer.

When Ghidra decompiles a Swift `@MainActor` method, it often shows a signature with extra
spurious pointer arguments that are actually actor isolation bookkeeping, not real parameters.

**Why it happens:**
Ghidra's decompiler is architected around C/C++ calling conventions. Swift's ABI deviations are
significant enough that automatically-generated pseudocode is unreliable for argument counting
and type identification.

**How to avoid:**
- Use Ghidra's decompiler output as a **structural hint** only (what calls what, what branch
  conditions exist, what constants are loaded). Never trust the argument list or type
  annotations at face value.
- For UI layout classes: focus on identifying string constants (SwiftUI modifier names,
  colour literal hex values, spacing constants loaded as immediates) rather than trying to
  reconstruct the function signature.
- Use the `bridge_mcp_ghidra.py` MCP bridge to batch-query function lists and cross-reference
  results across many functions, reducing the manual burden per function.

**Warning signs:**
- Decompiled function shows 6+ pointer arguments for what appears to be a simple accessor —
  almost certainly a Swift ABI artefact.
- `param_1->field_0x10` patterns in decompiled output for a function believed to be a
  `@Published` property — the offset arithmetic is real but the field names are invented by Ghidra.

**Phase to address:** Ghidra deep-dive phase; document in FINDINGS_5.md with explicit
HYPOTHESIS tags on any UI field derived from decompiled struct offsets.

---

### G-P3: Treating Ghidra findings as ground truth without cross-validation locks in wrong UI specs

**What goes wrong:**
A colour constant found in Ghidra decompilation (`0xFF1A1A2E` as a load immediate) is treated as
the confirmed WHOOP background colour. The SwiftUI redesign is built around it. Later PacketLogger
or screenshot comparison reveals the actual background is `0xFF0D0D1A` — a different constant from
a different function. Every card in the app has the wrong background.

This is the Ghidra equivalent of the haptics payload assumption failure in v2.0 (assumed
`[2, 3, 0, 0, 0]`, actually 13-byte DRV2605 payload — only caught by PacketLogger).

**Why it happens:**
Large ARM64 binaries load many constants; without knowing which function is actually called at
runtime for a given UI element, a constant found in a plausibly-named function may belong to a
dead code path or a different screen.

**How to avoid:**
- For visual constants (colours, font sizes, spacing): validate against the official WHOOP app
  running on-device via Xcode's View Debugger (attach to the WHOOP app process, inspect the
  live view hierarchy). This gives ground-truth values, not decompiled approximations.
- For algorithmic constants (formula coefficients, threshold values): cross-validate against
  observed biometric outputs. If the formula produces a Recovery score that diverges from the
  official app's score for the same input data, the constant is wrong.
- Tag every Ghidra-derived constant as HYPOTHESIS until confirmed by at least one of:
  (a) live View Debugger inspection, (b) consistent output match, (c) PacketLogger trace.

**Warning signs:**
- A constant appears in multiple unrelated functions — you likely found a shared constant pool
  entry, not a UI-specific value.
- The decompiled function body has no cross-references from UI code (no call site in a known
  SwiftUI view class) — the constant may be from a non-UI subsystem.

**Phase to address:** Ghidra deep-dive phase (constant extraction); UI implementation phase
(validation gate before each screen is marked VERIFIED).

---

### G-P4: 477k functions — unbounded exploration without a map wastes sessions

**What goes wrong:**
The Ghidra MCP bridge exposes `list_methods(offset, limit)`. With 477,000 functions, a naive
exploration ("let's look at all UI-related functions") produces hundreds of findings with no
priority order. The session ends with a large list of HYPOTHESIS entries and no VERIFIED ones.

**Why it happens:**
Swift iOS apps do not have a clean module boundary visible to Ghidra. UI code, algorithm code,
networking code, and third-party libraries are all compiled into the same binary.

**How to avoid:**
- Build a target list **before** opening Ghidra. From v3.0 IPA analysis, the following class
  prefixes were identified: `WHOOP` prefix (UI), `Recovery*`, `Sleep*`, `Strain*`, `Training*`.
  Use these as the starting namespace filter via `list_classes` with prefix matching.
- Prioritise functions with known cross-references to `SwiftUI` framework stubs (identified by
  `_$s7SwiftUI` prefix in callee list) — these are actual view body functions.
- Timebox each Ghidra session to one screen or one algorithm. Write findings to FINDINGS_5.md
  before moving to the next target. Never leave a session with uncommitted findings.
- Use the existing `bridge_mcp_ghidra.py` MCP tool with `decompile_function` for targeted
  per-function deep dives, not bulk exploration.

**Warning signs:**
- A single session produces > 20 HYPOTHESIS entries with 0 VERIFIED — the scope was too broad.
- The same class name appears > 3 times with different suffixes — you're seeing generic
  specialisations; focus on the unspecialised base version.

**Phase to address:** Ghidra deep-dive phase; enforce one-screen-per-session discipline.

---

### G-P5: Confusing WHOOP 4.0 vs 5.0 artefacts when the IPA targets both generations

**What goes wrong:**
The WHOOP iOS app 5.37.0 supports both Gen4 and Gen5 hardware. The binary contains code paths
for both. A UI function found via Ghidra may be Gen4-specific (e.g. a legacy recovery card
layout) that was replaced in Gen5. Implementing a redesign from the Gen4 code path produces
a UI that does not match the physical WHOOP 5.0 experience.

v3.0 precedent: the endData offset bug was exactly this — frame[17:25] was the Gen4 offset,
frame[21:29] was the Maverick/Gen5 offset. The same risk applies to UI code paths.

**Why it happens:**
Feature flags and hardware-generation branching in the binary produce duplicate code paths.
Without runtime context, Ghidra cannot tell which branch executes for Gen5.

**How to avoid:**
- When two functions implement the same UI concept (e.g. `recoveryCardView` and
  `recoveryCardViewV2`), always prefer the one whose name or caller contains `5`, `gen5`,
  `maverick`, or `v2` (newer).
- Where no naming signal exists, compare with the live WHOOP app on a Gen5 device using Xcode
  View Debugger — the live code path is the correct one.
- Note in FINDINGS_5.md which generation each finding targets.

**Warning signs:**
- A function implementing a known UI element appears twice with identical structure but
  different constants — likely a Gen4/Gen5 fork.
- The function's only callers are inside a branch checking a device-generation flag.

**Phase to address:** Ghidra deep-dive phase; flag all findings with `[Gen5-confirmed?]` tag.

---

## Area 2 — SwiftUI: Replicating Proprietary iOS UI from RE Findings

### UI-P1: RE findings describe intent, not SwiftUI structure — direct translation fails

**What goes wrong:**
Ghidra reveals that the Recovery card shows `recovery_score: Int` at the top with a font size
loaded as `34.0`. Implementing this as `Text("\(score)").font(.system(size: 34))` produces the
right number in the right approximate size, but the actual WHOOP card uses a custom font weight,
a specific line height, and a character spacing adjustment that collectively produce the visual
identity. The result looks "almost right" — harder to notice and fix than something obviously
broken.

**Why it happens:**
RE findings capture data values and constants. They do not capture SwiftUI modifier chains,
view composition hierarchy, or the interplay of `ViewModifier` types that produce the final
rendering.

**How to avoid:**
- Use Xcode's View Debugger (attach to the WHOOP process) to inspect the live SwiftUI view
  hierarchy, not just decompiled constants. The View Debugger shows modifier chains directly.
- Define all visual constants in `DesignTokens.swift` (`WH.` namespace) before implementing
  any screen. A card implementation that references `WH.Font.score` is independently testable
  and revisable without touching view code.
- Create a `DesignGallery` entry for each new component before wiring it to data. Compare
  side-by-side with a screenshot of the official app (do not copy assets — compare visually).

**Warning signs:**
- A view is implemented without a corresponding `DesignTokens.swift` entry — fonts and colours
  are hardcoded inline. This is always wrong.
- A component passes a "looks right" visual check but has no `DesignGallery` entry — it has
  never been compared systematically.

**Phase to address:** UI implementation phase; DesignTokens gate before each screen.

---

### UI-P2: RE-derived layout breaks on non-canonical device sizes and Dynamic Type

**What goes wrong:**
WHOOP's app is designed for specific iPhone screen sizes. A spacing constant of `16.0` found
in Ghidra works correctly on an iPhone 15 Pro Max but clips content on an iPhone SE or with
large accessibility text. The RE finding is a specific-device constant, not a responsive
design specification.

**Why it happens:**
RE extracts what the binary does for the captured execution, not what it should do across all
configurations. Apple's HIG requires Dynamic Type support (iOS accessibility mandate); WHOOP's
own app may or may not be compliant.

**How to avoid:**
- Map every Ghidra-derived spacing constant to the nearest `WH.Spacing.*` token (relative
  spacing, not fixed points). Use `scaledMetric` for font-size-adjacent spacing.
- Test each implemented screen on at minimum: iPhone SE (small), iPhone 15 (standard),
  iPhone 16 Pro Max (large), and with Accessibility → Larger Text at maximum.
- Accept that the RE-derived layout is the Gen5-device reference layout, not the definitive
  spec. The SwiftUI implementation adapts it.

**Warning signs:**
- A view uses `frame(width: X, height: Y)` with hardcoded constants from Ghidra — will clip.
- A `Text` view with a fixed font size instead of a `Font` token — will not scale with
  Dynamic Type.

**Phase to address:** UI implementation phase; device-size regression check per screen.

---

### UI-P3: Placeholder data passes visual QA but hides binding bugs until real data flows

**What goes wrong:**
A Recovery card is built with hardcoded values (`score: 87, hrv: 62, rhr: 54`) to match the
Ghidra-derived layout. It passes visual review. When wired to `MetricsRepository.today`, the
optional chain produces `nil` for all three values and the card renders with em-dashes — the
layout breaks because the hardcoded version never exercised the nil path.

v2.0 precedent: `SleepView.swift:139` had a placeholder headline metric never replaced with
real data (CONCERNS.md). This pattern is a known recurring failure mode.

**Why it happens:**
SwiftUI previews use hardcoded values; real data is only available on a physical device with
an active WHOOP connection or a populated store. The gap between preview-passing and
real-data-working is where placeholder bugs live.

**How to avoid:**
- Implement every view with an explicit `empty` state and a `loaded` state. Never write a view
  whose only state is the happy path.
- Add a `PreviewProvider` that exercises the nil/empty state alongside the populated state.
  If the nil state crashes or renders incorrectly in preview, it will crash with real data.
- The DesignGallery (`ios/OpenWhoop/Design/DesignGallery.swift`) must include both states
  before a component is marked complete.

**Warning signs:**
- A `MetricCard` view contains `?? "--"` optionals that were never tested with a nil input.
- A view's `PreviewProvider` uses hardcoded struct literals instead of the `empty` factory.

**Phase to address:** UI implementation phase; enforced via PreviewProvider gate.

---

### UI-P4: Replicating WHOOP's animation and transition timing from RE is impractical — scope it out

**What goes wrong:**
Ghidra can reveal `withAnimation(.spring(response: 0.4, dampingFraction: 0.7))` as a constant
call, but replicating the exact feel of a branded transition requires fine-tuning that RE cannot
provide. Attempting to exactly replicate animation timing from a decompiled binary wastes
disproportionate time on an unverifiable result.

**Why it happens:**
Animation parameters are easy to find in decompiled code but hard to validate — the human
eye is the only instrument, and it is unreliable for sub-100ms differences.

**How to avoid:**
- Scope v4.0 UI redesign to static layout, typography, colour, and spacing. Use SwiftUI's
  standard `.easeInOut` transitions unless an animation is grossly wrong. Mark animation
  tuning as a post-v4.0 concern.
- Exception: if a specific animation (e.g. the Recovery ring fill) is load-bearing for the
  UX (it is in WHOOP's app), timebox one session to it and accept the result.

**Warning signs:**
- More than 30 minutes spent on a single animation parameter — stop and defer.
- An animation constant from Ghidra is being debated without a side-by-side comparison
  against the running WHOOP app.

**Phase to address:** UI implementation phase; animation polish marked out-of-scope in
phase acceptance criteria.

---

### UI-P5: Legal boundary violation — reproducing copyrighted UI code from Ghidra decompilation

**What goes wrong:**
A decompiled Swift function body is copied verbatim into the OpenWhoop codebase and adapted
slightly. Even if the logic is reimplemented, the structural similarity to decompiled output
creates a copyright risk.

PROJECT.md constraint: "Copiar assets, artwork ou código proprietário do WHOOP — apenas
referência para estrutura de dados/UI."

**Why it happens:**
Decompiled code looks like real code. The line between "understanding the algorithm" and
"reproducing the implementation" is not always obvious when working quickly.

**How to avoid:**
- Use a "clean room" discipline: Ghidra findings are documented in FINDINGS_5.md as
  observations ("Recovery card shows score as a large number at top, with three sub-metrics
  below in a row"). A separate implementation session writes the SwiftUI code from the spec,
  not from the decompiled output.
- Never paste decompiled Ghidra pseudocode into Swift files, even as a comment.
- All RE findings must pass through FINDINGS_5.md before reaching the codebase. If a finding
  is not in FINDINGS_5.md, it has not been reviewed for legal risk.

**Warning signs:**
- A Swift file contains a comment with a Ghidra function address or decompiled variable name
  (`param_1->field_0x18`) — the clean-room boundary was crossed.
- A new algorithm implementation matches decompiled coefficient arrays exactly without an
  independent derivation.

**Phase to address:** All phases; FINDINGS_5.md gate is the enforcement mechanism.

---

## Area 3 — BLE Parsing: HRV/RR Offset Errors and Backfill Bugs

### BLE-P1: Byte offset arithmetic errors are silent — wrong values, not crashes

**What goes wrong:**
An HRV or RR interval is decoded from the wrong byte range of a Maverick frame. The decoded
value is a plausible number (e.g. 680ms instead of 640ms) — not a crash, not NaN, not an
obvious error. It passes unit tests if the test fixture was generated from the same wrong
offset. The bug surfaces only when the output diverges from the official WHOOP app's HRV
display, which requires a dedicated comparison session.

v2.0/v3.0 precedent: the endData offset bug (`frame[17:25]` vs `frame[21:29]`) is exactly
this failure mode. It caused the trim cursor to never advance — a functional failure that
happened to be detectable. RR offset errors are worse because the output is still a valid
millisecond value.

**Why it happens:**
- Gen4 and Maverick (Gen5) frames have different inner layouts. The Maverick outer wrapper
  shifts all inner field offsets by +4 bytes (4-byte role prefix).
- New RR or HRV fields added to the schema may reference Gen4 offsets from memory or from
  old FINDINGS documentation without verifying against current Maverick captures.

**How to avoid:**
- Every offset used in a frame decoder must have a corresponding golden fixture test that
  uses a real captured Maverick frame (not a synthetic one). The fixture must cover
  both the live path and the historical offload path.
- When adding a new field offset, cross-reference against `whoop_protocol_5.json` confidence
  tags: HYPOTHESIS offsets require a capture validation before merging to main.
- Run `scripts/gen_golden.py` against fresh captures after any offset change and verify the
  Python and Swift decoders agree.

**Warning signs:**
- A new field offset is introduced without a fixture update in `frames.json` + `golden.json`.
- An RR value in the decoded output is consistently 4 bytes off from the expected value —
  classic Maverick wrapper shift.
- The parity test (`ParityTests.swift`) passes but the on-device value diverges from the
  official app — the fixture was generated from the same wrong code.

**Phase to address:** Bug fix phase; every offset change requires a fixture regression test
as a merge gate.

---

### BLE-P2: Corrupt RR intervals with NaN/Inf values propagate into RMSSD and crash algorithms

**What goes wrong:**
A gravity sample or RR interval decoded with a corrupt value (e.g. a NaN from an unvalidated
float cast, or a zero from a missed null check) propagates into `LocalMetricsComputer`.
`RMSSD = sqrt(mean(diffs^2))` — a single NaN in the RR array produces NaN for the entire
night's HRV. The UI shows `--` or a placeholder, not a clear error.

v3.0 fix history: `fix(backfill): skip gravity samples with NaN/Inf components` (commit
4d6b225) — this pattern already occurred for gravity; RR intervals are the next likely vector.

**Why it happens:**
The WHOOP 5.0 strap occasionally transmits malformed samples (incomplete frames, clock-domain
artifacts). The decoder may produce structurally valid but numerically invalid values.

**How to avoid:**
- Validate every RR interval value at the decode boundary: `rr_ms` must be in [200, 2000]ms.
  Values outside this range are physiologically impossible and must be discarded, not clamped.
- `LocalMetricsComputer.computeHRV` must guard against empty input and NaN RMSSD before
  writing to the store.
- Add a `testHRVWithCorruptRRValues` unit test that injects NaN, Inf, zero, and out-of-range
  RR values and verifies the algorithm produces `nil`, not NaN.

**Warning signs:**
- HRV shows `--` in the UI after a full-night backfill that successfully decoded HR samples.
- `DailyMetric.hrv` is stored as `NULL` in the DB but `hrSample` count for the same day
  is non-zero — the algorithm ran on corrupt input and produced no usable output.

**Phase to address:** Bug fix phase; add guard at decode boundary before algorithm integration.

---

### BLE-P3: Backfill cursor stuck — reproducing the v2.0 failure in a new code path

**What goes wrong:**
After a bug fix or refactor in `Backfiller.swift`, the `strap_trim` cursor stops advancing
again. The strap retransmits the same chunk indefinitely. The bug is not visible in logs
unless explicit cursor-advance logging is present.

Root cause taxonomy from v2.0: (a) offset error causing `HISTORY_END` to be misclassified as
`.other`; (b) a store write failure silently swallowed by `finishChunk`; (c) the
`connectHandshakeDone` guard causing a premature re-handshake that resets the offload state.

**Why it happens:**
Any change to `Backfiller.swift`, `BLEManager.swift` handshake sequence, or
`WhoopStore.setCursor` call site can reintroduce the stuck-cursor invariant violation.

**How to avoid:**
- The safe-trim invariant must be tested explicitly: inject a store write failure into a
  `SpyStore` and verify the chunk is not acked (cursor does not advance, no `ackTrim()` is
  sent). This test exists in the backlog (CONCERNS.md) — it must be written as a merge gate
  for any `Backfiller` change.
- Add a debug log line: `"[Backfiller] cursor advanced to \(cursor)"` on every successful
  `setCursor` call. If this line is not seen during a backfill session, the cursor is stuck.
- After any BLE-related change, run a full backfill on-device and verify the type-47 frame
  counter (`BF: frame #N`) reaches the expected count and the cursor advances past the initial
  position.

**Warning signs:**
- The WHOOP strap transmits the same `HISTORY_START` marker more than once in a session
  (strap is retransmitting from the last acked position).
- `strap_trim` cursor value in the store has not changed after a 5-minute backfill session.
- `Backfiller.finishChunk` is called but no subsequent `ackTrim()` log line appears.

**Phase to address:** Bug fix phase; safe-trim invariant test as merge gate.

---

### BLE-P4: V128 HRV/RR offsets are not yet VERIFIED — treating HYPOTHESIS as VERIFIED

**What goes wrong:**
The v128 frame format (HISTORICAL_DATA type 47) has RR offsets that were identified in the
commit `fix(hrv): remove unverified RR offsets from V128 and purge corrupt data` (e65fa31).
This implies the previous offsets were wrong and have been removed. If the v4.0 work assumes
those offsets have been re-verified when they have not, new decode code will silently produce
wrong RR values again.

**Why it happens:**
After a fix that removes a wrong offset, there is a temptation to treat the absence of the
bug as confirmation that the new code is correct. It is not — it only confirms the old code
was wrong.

**How to avoid:**
- Check `whoop_protocol_5.json` for the confidence tag on every V128 field before referencing
  its offset in any decode code. Only `VERIFIED` fields should be used in production code paths.
- HYPOTHESIS V128 offsets must be captured via a dedicated PacketLogger session before
  being promoted to VERIFIED. This is a hardware session requirement — schedule it explicitly.
- Run `SchemaSyncTests.swift` after any schema change to ensure the bundled schema matches
  the canonical protocol file.

**Warning signs:**
- A V128 field offset is referenced in Swift code but its `confidence` in
  `whoop_protocol_5.json` is `"HYPOTHESIS"`.
- A new RR decode test passes with a synthetic fixture but has never been run against a
  real Maverick V128 frame from a PacketLogger capture.

**Phase to address:** Bug fix phase; schema confidence gate before any V128 offset reference.

---

## Area 4 — Repo Reorganisation: Mixed Swift/Python Project

### REPO-P1: Moving files breaks Xcode target membership silently — the project.yml is the source of truth

**What goes wrong:**
A Swift file is moved from `ios/OpenWhoop/BLE/` to a new `ios/OpenWhoop/Protocol/` directory
as part of a cleanup. The file is present on disk. Xcode's `.xcodeproj` still references the
old path. The app compiles only if XcodeGen is re-run, which regenerates `project.yml`
references. If XcodeGen is not run, the file is missing from the compiled target — either a
compile error (if the move is clean) or a silent duplicate (if the original was not deleted).

**Why it happens:**
The project uses XcodeGen (`project.yml`) as the Xcode project source of truth. Direct
manipulation of the file system does not update `project.yml`, and direct manipulation of
`.xcodeproj` is overwritten on the next XcodeGen run.

**How to avoid:**
- All Swift file moves must be accompanied by an immediate `xcodegen generate` run and a
  build verification (`xcodebuild build -scheme OpenWhoop`).
- Never move files via Finder or `mv` without updating `project.yml` group definitions
  beforehand.
- The reorganisation phase should batch all file moves into a single commit that includes:
  the file moves, the updated `project.yml`, and a green `xcodebuild build` result.

**Warning signs:**
- `xcodebuild build` produces "file not found" for a file that exists on disk.
- Xcode shows a file in the navigator with a red icon (unresolved reference).
- `git status` shows a deleted file and a new file at the new path — the `project.yml` was
  not updated to match.

**Phase to address:** Repo cleanup phase; `xcodebuild build` as the mandatory post-move gate.

---

### REPO-P2: Swift Package path changes break SPM resolution and WhoopProtocol tests

**What goes wrong:**
`Packages/WhoopProtocol/` and `Packages/WhoopStore/` are referenced in `ios/project.yml` as
local SPM dependencies with relative paths. If either package directory is moved (e.g. into a
new `packages/` top-level directory), SPM cannot resolve the dependency, the Xcode project
fails to open cleanly, and all cross-package tests fail.

**Why it happens:**
SPM local package references use path-relative resolution. Both `project.yml` and any
`Package.swift` that references another local package must be updated simultaneously.

**How to avoid:**
- Do not move `Packages/WhoopProtocol` or `Packages/WhoopStore` unless the path change is
  explicitly planned and all referencing `Package.swift` and `project.yml` files are
  updated atomically.
- Before any package move: `grep -r "WhoopProtocol\|WhoopStore" . --include="*.yml" --include="*.swift" --include="Package.swift"` to find all reference sites.
- After any package move: `swift package resolve` from the `ios/` directory, then
  `xcodebuild build`.

**Warning signs:**
- Xcode shows "package not found" for a local package that exists on disk.
- `swift package resolve` exits with a path error.

**Phase to address:** Repo cleanup phase; SPM resolution check as post-move gate.

---

### REPO-P3: Renaming Python modules breaks RE script imports without a clear error

**What goes wrong:**
`re/analyze_final.py` imports from `whoop_protocol` (the Python package at
`server/packages/whoop-protocol/`). If the server directory is restructured and the package
install path changes, all RE scripts fail with `ModuleNotFoundError: No module named 'whoop_protocol'`.
This is a silent breakage — the scripts still exist, they just cannot be run.

**Why it happens:**
Python RE scripts depend on the `whoop-protocol` package being installed (`pip install -e`).
Restructuring `server/packages/` invalidates the editable install symlink without any
compiler or test runner catching it.

**How to avoid:**
- If `server/packages/whoop-protocol/` is moved, all `re/*.py` scripts that import from it
  require `pip install -e <new-path>` to re-establish the editable install.
- Add a `re/README.md` (if it does not exist) documenting the setup requirement explicitly.
- Run `python -c "import whoop_protocol; print(whoop_protocol.__file__)"` after any
  server directory restructure to verify the import path.

**Warning signs:**
- `python re/analyze_final.py` exits with `ModuleNotFoundError` after a directory move.
- `pip show whoop-protocol` shows a path that no longer exists.

**Phase to address:** Repo cleanup phase; Python import smoke-test after any server restructure.

---

### REPO-P4: Leaving 4.0 artefacts in a 5.0 codebase creates permanent confusion

**What goes wrong:**
The STRUCTURE.md still references `whoop_protocol.json` as "Schema defining all WHOOP 4.0
frame layouts" (as of analysis date 2026-05-30). The notes file `2026-06-01-analisa-codigo-verifica-4-0.md`
confirms that 4.0 artefacts are still present in the codebase. If the cleanup is partial
(some files updated, others not), new contributors and future Claude sessions make
incorrect assumptions about which code targets which generation.

The planning notes themselves state: "analisa todo o codigo e verifica o que está para o 4.0,
e remove adapta tudo para a whoop para a 5.0 deve estar coisas erradas ainda com a 4.0".

**Why it happens:**
The project started as a 4.0 fork. v1.0 established the 5.0 framing but did not do a full
audit of all documentation references. Comments, doc strings, and planning files retain 4.0
references even when the underlying code was updated.

**How to avoid:**
- Before marking the cleanup phase complete, run:
  `grep -r "4\.0\|gen4\|Gen4\|WHOOP 4" . --include="*.swift" --include="*.py" --include="*.md" --include="*.json"`
  and resolve every occurrence: either update to 5.0, remove, or annotate with a comment
  explaining why the 4.0 reference is intentional (e.g. "write commands use Gen4 format —
  D-11 asymmetric framing").
- STRUCTURE.md, ARCHITECTURE.md, FINDINGS_5.md, and all inline Swift comments must pass
  this grep before the cleanup phase is closed.
- Exception: `FINDINGS.md` (the Gen4 reference file) may retain 4.0 content — it is
  explicitly a Gen4 reference. Distinguish it clearly from `FINDINGS_5.md`.

**Warning signs:**
- A Swift source file contains a comment referencing `0xAA 0x01` (Maverick magic) but the
  surrounding code uses Gen4 offsets.
- `whoop_protocol.json` is referenced in documentation without the `_5` suffix disambiguation.
- A Python RE script is named without a `_5` suffix but operates on Maverick frames.

**Phase to address:** Repo cleanup phase; grep-based audit as completion gate.

---

### REPO-P5: Moving `re/` scripts without updating `device_local.py` references breaks all RE tooling

**What goes wrong:**
All 70+ RE scripts in `re/` import from `device_local.py` (gitignored, personal device
identifiers). If scripts are reorganised into subdirectories (`re/protocol/`, `re/ui/`) without
updating the import path, every script silently breaks.

**Why it happens:**
`device_local.py` is not in the repo (gitignored). Its path is relative to each script.
Moving scripts invalidates the relative import without any test catching it.

**How to avoid:**
- Do not reorganise the `re/` directory into subdirectories unless the device_local import
  pattern is refactored to an absolute import (e.g. via a `re/conftest.py` or
  `re/__init__.py` that injects the path).
- The simpler approach: leave `re/` flat. The directory is a RE toolbox, not production
  code. Flat is fine for 70 scripts.
- If reorganisation is necessary, update all imports as part of the same commit and verify
  with `python -c "import device_local"` from each subdirectory.

**Warning signs:**
- `python re/some_script.py` fails with `ModuleNotFoundError: No module named 'device_local'`
  after a directory move.

**Phase to address:** Repo cleanup phase; flat `re/` structure preferred to avoid this
entirely.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Implement UI from Ghidra constants without View Debugger validation | Faster implementation | Wrong colours/spacing locked in, hard to diff later | Never — spend 10 min on View Debugger for each screen |
| Use HYPOTHESIS V128 offsets in production decode path | Avoids a capture session | Silent wrong HRV values that diverge from official app | Never — HYPOTHESIS fields must be gated out of prod |
| Move files without running `xcodegen generate` | Faster refactor | Silent Xcode target membership breaks | Never |
| Keep 4.0 references in 5.0 code with a "// TODO" | Avoids a documentation pass | Future sessions assume wrong generation, bugs reappear | Never — clean up in the cleanup phase itself |
| Skip golden fixture update after offset change | Saves time on fixture generation | Parity test passes on wrong values; real-device divergence | Never — fixtures are the only offset regression guard |
| Build UI in happy-path-only mode (no nil/empty state) | Faster to preview | Crashes or blank UI with real data (v2.0 SleepView bug repeated) | Never for any MetricCard component |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Ghidra MCP bridge | Calling `decompile_function` with an ambiguous name and trusting the first result | Always call `list_classes` first with a namespace filter; verify call sites before trusting a decompilation |
| Xcode View Debugger + WHOOP app | Attaching to a release build that has been stripped — no view names visible | WHOOP app is a release build; use accessibility inspector as a fallback; or capture a screenshot and compare manually |
| `whoop_protocol_5.json` schema sync | Editing the canonical file but forgetting to run `scripts/sync-schema.sh` | Run `SchemaSyncTests.swift` in CI; it fails if bundled and canonical diverge |
| GRDB migration | Adding a column without incrementing the migration version number | Always increment `DatabaseMigrator` version; test migration from v8→v9 on a populated store, not just a fresh store |
| `LocalMetricsComputer` + NaN RR | Passing unvalidated RR array from `WhoopStore.rrIntervals` | Filter at the decode boundary in `Backfiller`; never pass raw store values to the algorithm |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Ghidra decompiling all 477k functions at session start | Ghidra hangs for minutes; MCP bridge timeouts | Use `list_classes` with filters; `decompile_function` one function at a time | Always — never bulk-decompile |
| Running `pullDerivedWindow` (60 sequential GETs) on cold start | App feels frozen for 30–60s after first launch | Batch endpoint (already in CONCERNS.md backlog) — do not make this worse in v4.0 by adding more sequential pulls | Cold start with > 30 days of data |
| Saving HealthKit samples inside the BLE notification handler | Blocks `@MainActor` during BLE data bursts; missed frames | Always dispatch HealthKit writes to a background task; keep the BLE path latency-free | Under sustained HR notification rate (1 sample/sec) |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Committing Ghidra analysis session files (.gzf, .rep) that may contain extracted binary segments | Legal/IP exposure if they embed decompiled WHOOP code | Add `*.gzf`, `*.rep`, `*.ghidra/` to `.gitignore`; only commit FINDINGS_5.md observations |
| Logging decoded biometric values at DEBUG level in production builds | Health data in device logs, visible to any process with log access | Wrap all biometric log lines in `#if DEBUG`; production builds should log frame counts only |
| Exposing the Ghidra HTTP server (port 8080) on a non-loopback interface | Remote access to full binary decompilation | Ensure `bridge_mcp_ghidra.py` connects only to `127.0.0.1:8080`; never bind Ghidra's server to `0.0.0.0` |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| UI shows RE-derived labels that don't match WHOOP (e.g. "HRV RMSSD" instead of "HRV") | User comparing with the official app sees a discrepancy that undermines trust | Copy the exact label string from FINDINGS_5.md IPA analysis; use v3.0 precedent (SLEEP PERFORMANCE, HOURS OF SLEEP verified via IPA) |
| Recovery ring animation runs every time the view appears (not just on new data) | Distracting re-animation on every tab switch | Gate the animation trigger on `lastRefreshedAt` change, not on `onAppear` |
| Ghidra-derived screen layout implemented at fixed-width only | Clips on iPhone SE; empty space on Pro Max | Use proportional layout (`GeometryReader` or `.frame(maxWidth: .infinity)`) for all card widths |
| DesignGallery left wired as a production tab | Extra tab visible to user | Guard with `#if DEBUG` — already flagged in CONCERNS.md, must be fixed in cleanup phase |

---

## "Looks Done But Isn't" Checklist

- [ ] **Ghidra finding:** Every constant in FINDINGS_5.md is tagged VERIFIED or HYPOTHESIS — no untagged entries.
- [ ] **Ghidra finding:** Every class identified has been verified by caller context, not just by demangled name.
- [ ] **SwiftUI screen:** Every screen has a `PreviewProvider` that exercises the empty/nil state.
- [ ] **SwiftUI screen:** Every screen has a corresponding `DesignGallery` entry that has been compared against a screenshot of the official WHOOP app.
- [ ] **HRV/RR offset:** Every changed offset has a golden fixture update (`frames.json` + `golden.json`) and a passing `ParityTests.swift`.
- [ ] **HRV/RR offset:** The V128 confidence tag in `whoop_protocol_5.json` is VERIFIED, not HYPOTHESIS, before the offset is used in production.
- [ ] **Backfill fix:** The safe-trim invariant test (inject store write failure, verify no ackTrim) is written and passing.
- [ ] **Repo cleanup:** `grep -r "4\.0\|gen4\|Gen4" . --include="*.swift"` returns zero results (or each result is annotated as intentional D-11 reference).
- [ ] **Repo cleanup:** `xcodebuild build` passes after every file move.
- [ ] **Repo cleanup:** `SchemaSyncTests.swift` passes (bundled schema == canonical).
- [ ] **Repo cleanup:** `DesignGallery` is guarded with `#if DEBUG`.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wrong Ghidra offset used in production decode | MEDIUM | Identify correct offset from PacketLogger capture; update `whoop_protocol_5.json`; regenerate golden fixtures; patch Swift decoder; run parity tests |
| Wrong V128 RR offsets producing bad HRV | MEDIUM | Run `fix(hrv): remove unverified RR offsets` pattern (already established in e65fa31); purge corrupt data from store via a migration or manual SQL delete; re-run backfill |
| Backfill cursor stuck (re-introduced) | HIGH (requires hardware session) | Add `setCursor` debug log; on-device backfill session; identify which invariant was broken (offset, store failure, handshake storm); targeted fix + safe-trim test |
| Xcode target membership broken by file move | LOW | Re-run `xcodegen generate`; verify all files have green icons in navigator; `xcodebuild build` |
| Python RE scripts broken by directory move | LOW | `pip install -e <new-path>` for whoop-protocol; verify `import whoop_protocol` from each affected script |
| Legal exposure from pasted decompiled code | HIGH | Remove immediately; review git history; replace with clean-room reimplementation documented from FINDINGS_5.md observations only |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| G-P1: Swift name mangling — demangled names are hypotheses | Ghidra deep-dive | Every Ghidra class in FINDINGS_5.md has a VERIFIED or HYPOTHESIS tag; none untagged |
| G-P2: ARM64 Swift calling convention misread | Ghidra deep-dive | No decompiled argument list trusted without caller context verification |
| G-P3: Ghidra constants treated as ground truth | Ghidra deep-dive + UI implementation | Every visual constant validated via View Debugger or output comparison before implementation |
| G-P4: Unbounded Ghidra exploration | Ghidra deep-dive | Session scoped to one screen; FINDINGS_5.md entry committed before next screen |
| G-P5: Gen4 vs Gen5 code path confusion | Ghidra deep-dive | All FINDINGS_5.md entries tagged [Gen5-confirmed?]; ambiguous ones flagged HYPOTHESIS |
| UI-P1: RE findings describe intent, not SwiftUI structure | UI implementation | DesignTokens.swift updated before each screen; no hardcoded constants in view files |
| UI-P2: RE layout breaks on non-canonical device sizes | UI implementation | Screen tested on iPhone SE + iPhone 16 Pro Max + Accessibility Large Text |
| UI-P3: Placeholder data hides nil binding bugs | UI implementation | PreviewProvider for empty state exists and does not crash |
| UI-P4: Animation timing over-scoped | UI implementation | Animation polish explicitly out of scope in phase acceptance criteria |
| UI-P5: Legal boundary — decompiled code reproduced | All phases | Clean-room discipline; no Ghidra pseudocode in Swift files; FINDINGS_5.md gate enforced |
| BLE-P1: Byte offset arithmetic errors are silent | Bug fix phase | Every changed offset has a golden fixture and passes ParityTests |
| BLE-P2: NaN/Inf RR values propagate into RMSSD | Bug fix phase | `testHRVWithCorruptRRValues` unit test passes with NaN, Inf, zero, out-of-range inputs |
| BLE-P3: Backfill cursor stuck re-introduced | Bug fix phase | Safe-trim invariant test (SpyStore write failure → no ackTrim) passes |
| BLE-P4: V128 HYPOTHESIS offsets treated as VERIFIED | Bug fix phase | Schema confidence check: no HYPOTHESIS offset referenced in production Swift decode |
| REPO-P1: File moves break Xcode target membership | Repo cleanup phase | `xcodebuild build` green after every file move commit |
| REPO-P2: SPM package path changes break resolution | Repo cleanup phase | `swift package resolve` green; no "package not found" in Xcode |
| REPO-P3: Python module rename breaks RE scripts | Repo cleanup phase | `python -c "import whoop_protocol"` passes after any server restructure |
| REPO-P4: 4.0 artefacts remain in 5.0 codebase | Repo cleanup phase | `grep -r "4\.0\|gen4\|Gen4"` returns zero unintentional results in Swift/Python source |
| REPO-P5: `re/` script moves break device_local imports | Repo cleanup phase | Flat `re/` structure maintained; no subdirectory reorganisation |

---

## Sources

- Project RETROSPECTIVE.md — v1.0/v2.0/v3.0 lessons: endData offset bug, haptics payload assumption, IPA class-name RE pattern, safe-trim invariant, offline-first architecture
- Project CONCERNS.md — `_cachedSchema` Swift 6 concurrency issue, `pullDerivedWindow` serial HTTP, `finishChunk` silent error swallowing, `BLEManager` 8-flag reset requirement, placeholder SleepView headline
- Project ARCHITECTURE.md — BLE pipeline data flow, Maverick frame paths, safe-trim invariant definition
- Project TESTING.md — SpyStore pattern, golden fixture structure, parity test gate, schema sync test
- Git log entries: e65fa31 (V128 RR offsets removed), 4d6b225 (LocalMetricsComputer BLE disconnect), 17896ce (gravity NaN skip), 4c17952 (HISTORICAL_DATA v128 decode), c354f39 (STATE.md session discoveries)
- Known v2.0 failure: endData offset `frame[17:25]` vs correct `frame[21:29]` (Maverick +4 byte shift)
- Known v3.0 fix: RunAppDrivenHapticsCommandPacket payload — assumption wrong, PacketLogger verified
- Ghidra Swift ARM64 RE domain: Swift ABI documentation (x20 self register, x8 indirect return, x21 error register) — HIGH confidence from Swift ABI specification

---
*Pitfalls research for: WHOOP 5.0 iOS client — v4.0 Ghidra RE + UI redesign + BLE bug fixes + repo cleanup*
*Researched: 2026-06-01*
