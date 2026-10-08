# Changelog

All notable changes to `heat-engine-spec` are recorded here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html);
pre-1.0 uses the npm convention: `0.MINOR.PATCH` where MINOR = breaking, PATCH = non-breaking.

## [Unreleased]

Found by rebuilding the engine from a written specification
([regen-heat-engine](https://github.com/craigm26/regen-heat-engine); its
decisions D-006 to D-009 and D-013).

### Fixed
- **NWS observations come from endpoints that exist.** `fetchWeatherCascade`
  requested `https://api.weather.gov/points/{lat},{lng}/observations/latest`,
  which the NWS API does not have (it answers 404), so with the live service
  the cascade always fell back to Open-Meteo. The NWS tier now makes the
  documented three requests: `/points/{lat},{lng}`, then the point's
  `observationStations` list, then `/stations/{id}/observations/latest` for
  the first station. NWS requests send a `User-Agent` (NWS answers 403
  without one). Each request has the NWS timeout (5 s), so a slow NWS can
  take up to 15 s before the cascade moves on. A point without
  `observationStations`, or an empty station list, fails the tier with
  `missing_field:observationStations` or `missing_field:stationIdentifier`.
  The cascade-replay fixtures gain replay answers for the first two
  requests; their expected results and audits are unchanged.
- **`windMps` is in metres per second.** NWS reports wind in km/h (`unitCode`
  `wmoUnit:km_h-1`) and Open-Meteo's default unit is km/h; both were copied
  into `windMps` unchanged, 3.6 times too large. NWS km/h (or a missing unit
  code) is divided by 3.6, m/s is kept, and any other unit leaves `windMps`
  out. Open-Meteo is asked for `wind_speed_unit=ms`, and a km/h answer is
  still converted. Fixture change: `nws-success` now expects `windMps`
  0.8611111111111112 (3.1 km/h) instead of 3.1. Audits do not contain wind.
- TypeScript: a `null` Open-Meteo `temperature_2m` or `relative_humidity_2m`
  counts as missing and falls through to the next source, as in Dart and for
  NWS. It used to produce a sample with `tempC: null`.
- TypeScript: an `Infinity` or `-Infinity` input was written to its audit as
  `null`, where Dart wrote `"Infinity"`. Both now write `"NaN"`, `"Infinity"`
  and `"-Infinity"`, and the TypeScript `canonicalJson` writes a non-finite
  number as that string instead of `null`, as the Dart one does.

### Changed
- `wet-bulb-input.schema.json`: `rhPercent` maximum 99 → 100. Both
  implementations clamp RH to [5, 100] and test that 120 becomes 100; the
  schema said they must clamp to [5, 99]. It still states Stull's validated
  range, [5, 99].

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
