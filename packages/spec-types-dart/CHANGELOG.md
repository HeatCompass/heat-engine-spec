## Unreleased

### Fixed
- `fetchWeatherCascade` fetches NWS observations with the documented requests
  (`/points/{lat},{lng}`, its station list, then
  `/stations/{id}/observations/latest`) and a `User-Agent` header. The path it
  used before does not exist on `api.weather.gov`, so the NWS tier always
  failed against the live service.
- `windMps` is in metres per second. NWS reports km/h and Open-Meteo defaults
  to km/h; both were copied unconverted. NWS km/h is divided by 3.6 and
  Open-Meteo is asked for `wind_speed_unit=ms`.

## 0.1.1 - 2026-05-28

### Fixed
- `loadWetBulbFixtures()` and the other fixture loaders could not locate the
  bundled CSVs when this package was consumed as a hosted (pub.dev) dependency:
  `_readBundledFixture` resolved `lib/fixtures/<file>` against a package-root URI
  lacking a trailing slash, dropping the `heat_engine_spec-<ver>` directory. Path
  deps were unaffected. The loader now forces a trailing slash before resolving.
  No API or spec-contract changes.

## 0.1.0 - 2026-05-25

Initial release. Tier 1 of the [heat-engine-spec](https://github.com/HeatCompass/heat-engine-spec) contract.

### Added
- `WetBulbInput`/`WetBulbOutput` types for the Stull (2011) wet-bulb formula.
- `FlagMappingInput`/`FlagMappingOutput` types for USMC 6200.1E flag mapping.
- `EnvironmentalFlag` enum (`white|green|yellow|red|black`) and `HeatRiskLevelLabel` enum (`low|moderate|high|extreme|critical`).
- `loadWetBulbFixtures()` and `loadFlagMappingFixtures()` loaders that read 38 wet-bulb + 20 flag-mapping CSV rows bundled into the package.
- `WetBulbFixtureRow` and `FlagMappingFixtureRow` row types.
