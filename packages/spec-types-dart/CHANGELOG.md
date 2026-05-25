## 0.1.0 - 2026-05-25

Initial release. Tier 1 of the [heat-engine-spec](https://github.com/HeatCompass/heat-engine-spec) contract.

### Added
- `WetBulbInput`/`WetBulbOutput` types for the Stull (2011) wet-bulb formula.
- `FlagMappingInput`/`FlagMappingOutput` types for USMC 6200.1E flag mapping.
- `EnvironmentalFlag` enum (`white|green|yellow|red|black`) and `HeatRiskLevelLabel` enum (`low|moderate|high|extreme|critical`).
- `loadWetBulbFixtures()` and `loadFlagMappingFixtures()` loaders that read 38 wet-bulb + 20 flag-mapping CSV rows bundled into the package.
- `WetBulbFixtureRow` and `FlagMappingFixtureRow` row types.
