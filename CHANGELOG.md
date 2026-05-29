# Changelog

All notable changes to `heat-engine-spec` are recorded here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html);
pre-1.0 uses the npm convention: `0.MINOR.PATCH` where MINOR = breaking, PATCH = non-breaking.

## [Unreleased]

## [0.1.1] — 2026-05-28
### Fixed
- Fixture loaders (`loadWetBulbFixtures()` et al.) could not locate the bundled
  CSVs when `heat_engine_spec` was consumed as a **hosted (pub.dev) dependency**.
  `_readBundledFixture` resolved `lib/fixtures/<file>` against a package-root URI
  with no trailing slash, so URI resolution dropped the version directory
  (`.../heat_engine_spec-0.1.0`) and looked one level too high. Path dependencies
  happened to carry the slash and were unaffected — which is why the consumer
  conformance tests passed pre-publish but failed once they switched to the
  published package. The loader now forces a trailing slash before resolving.

No API or spec-contract changes. `SPEC_VERSION` is bumped only to satisfy the
release workflow's version-sync assertion (Dart/TS constants + manifests + tag).

## [0.1.0] — 2026-05-27
### Added
Tier 1 release. Establishes the cross-language contract for the HeatCompass
Console (TypeScript) and the HeatCompass consumer Flutter app (Dart).

- **`calculateWetBulb`** — Stull (2011) wet-bulb temperature from temperature
  and relative humidity. 38-row Python-generated CSV fixture; cross-language
  Stull values agree to within 1e-5 °C.
- **`flagFromWetBulbF`, `flagFromWetBulbC`** — USMC 6200.1E flag bands
  (white / green / yellow / red / black). 20-row fixture.
- **`workRestForFlag`** — USMC 6200.1E §3.2 work/rest matrix, including the
  two cease-work cells (red/unacclim, black/either). 10-row fixture.
- **`fetchWeatherCascade`** — Async NWS → Open-Meteo → simulated fallback with
  injectable `HttpAdapter`. Child audits + `source_chain` + `sources_tried` +
  `fallback_reason` wired through the audit envelope. 6 JSON replay scenarios.
- **`promoteVerdict`** — 5-rule go/delay/alternate state machine
  (`FIRST_RUN_DEFAULT`, `NO_CHANGE`, `ALTERNATE_AVAILABLE_AT_BLACK`,
  `ESCALATE_TO_DELAY_ON_RED_OR_BLACK`, `DEESCALATE_TO_GO`). 8-row fixture.
- **Audit envelope (Approach B).** Every primary function returns
  `{ result, audit }` where `audit` is a tree-structured `AuditRecord` with
  citation, constants used, function name, inputs, computed_at (from an
  injectable clock), and optional children.
- **Canonical JSON serializer** (`canonicalJson` in TS, `canonicalJson` in
  Dart) — produces byte-identical output across languages over any
  JSON-serializable value with deterministic key ordering.
- **Cross-language conformance.** TS 134/134 + Dart 129/129 conformance tests
  run against the same fixtures. CI gates on four jobs: `schema-validate`,
  `ts-conformance`, `dart-conformance`, `cross-lang-equiv`.

### Packages
- `@heatcompass/heat-engine-spec` — TypeScript reference impl + types,
  published on npm.
- `heat_engine_spec` — Dart reference impl + types, published on pub.dev.
