# Deferred Items — Phase 05 (ios-app-server-port)

## From Plan 05-01 (decoder port to 5.0)

### 4.0 parity test suite fails after the D-01 schema switch (deferred to 05-02)

Switching `loadSchema()` / `schemaResourceURL()` from `whoop_protocol.json` (4.0) to
`whoop_protocol_5.json` (5.0) changes the packet layouts the decoder uses. The pre-existing
4.0 parity/golden tests assert against 4.0 schema field offsets and 4.0 golden fixtures, so
they now fail. The plan's `<verification>` is explicitly `swift build` only, and SWIFT-03/04
state "paridade validada em 05-02" — i.e. 5.0 parity (with 5.0 golden fixtures) is the
explicit scope of the next wave plan, NOT this one.

Failing tests (run `swift test` in `Packages/WhoopProtocol`):

- `HistoricalStreamsParityTests.testSwiftHistoricalMatchesPythonGolden`
- `HistoricalV24Tests.testV24BiometricFields`
- `HistoricalV24Tests.testV24ExtractHistoricalStreams`
- `HistoricalV24Tests.testUnmappedVersionFallsBackGracefully`
- Likely also: `SchemaTests`, `ParityTests`, `PostHooksTests`, `StreamsParityTests`,
  `BiometricStreamsParityTests`, `SchemaSyncTests.testBundleModuleSchemaAlsoMatchesCanonical`,
  `HistoricalMetaTests` — all bound to the 4.0 schema / 4.0 golden fixtures.

These are NOT regressions in this plan's code (the decoder builds and the new Maverick path
is independently tested in `MaverickTests`). They are the planned consequence of moving the
canonical schema to 5.0. Do NOT fabricate 5.0 offsets/fixtures to make them pass — wait for
real 5.0 captures and the 05-02 parity work.

**Resolution owner:** Plan 05-02 (5.0 parity + golden fixtures).

**RESOLVED in 05-02 (commit 0ce7c4d):** The 4.0-fixture-bound suites cannot pass against the
now-5.0 runtime schema, and fabricating 5.0 offsets is forbidden (the 5.0 captures have no
type-47 V24 / type-43 IMU; PROJECT.md puts 4.0 support out of scope for this fork). Instead a
test-only `overrideSchemaResource("whoop_protocol")` hook was added to `loadSchema()`
(production default stays `whoop_protocol_5`), and every 4.0-protocol test pins itself to the
4.0 schema in `setUp`/`tearDown`: `ParityTests`, `StreamsParityTests`, `StreamsTests`,
`SchemaTests`, `InterpreterEnvelopeTests`, `HistoricalV24Tests`, `HistoricalStreamsParityTests`,
`BiometricStreamsParityTests`. The new 5.0 parity guard is `Parity5Tests` over
`frames_5.json`/`golden_5.json`. `swift test` now passes all 72 tests (4.0 + 5.0).
