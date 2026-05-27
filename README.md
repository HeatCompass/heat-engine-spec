# heat-engine-spec

Spec-of-record for the heat-stress calculation engine shared between:
- **HeatCompass** (consumer Flutter app)
- **HeatCompass Console** (B2B TypeScript stack)

This repo owns the contract. Both implementations must conform.

## Packages

| Language | Registry | Package |
|---|---|---|
| TypeScript | npm | [`@heatcompass/heat-engine-spec`](https://www.npmjs.com/package/@heatcompass/heat-engine-spec) |
| Dart | pub.dev | [`heat_engine_spec`](https://pub.dev/packages/heat_engine_spec) |

## Quick start

```ts
import {
  calculateWetBulb,
  flagFromWetBulbF,
  promoteVerdict,
} from '@heatcompass/heat-engine-spec';

const wb = calculateWetBulb({ tempC: 30, rhPercent: 60 });
const fg = flagFromWetBulbF(wb.result!.wetBulbF);
const vd = promoteVerdict({
  priorVerdict: null,
  priorFlag: null,
  currentFlag: fg.result!.flag,
  hasAlternateAvailable: false,
});
// wb.audit, fg.audit, vd.audit are tree-structured AuditRecords with citation,
// constants used, inputs, computed_at, and (where applicable) children.
```

```dart
import 'package:heat_engine_spec/heat_engine_spec.dart';

final wb = calculateWetBulb(const WetBulbInput(tempC: 30, rhPercent: 60));
final fg = flagFromWetBulbF(wb.result!.wetBulbF);
final vd = promoteVerdict(VerdictInput(
  priorVerdict: null,
  priorFlag: null,
  currentFlag: fg.result!.flag,
  hasAlternateAvailable: false,
));
```

## Tier 1 surface (v0.1.0)

- `calculateWetBulb` — Stull (2011) wet-bulb temperature
- `flagFromWetBulbF`, `flagFromWetBulbC` — USMC 6200.1E flag bands
- `workRestForFlag` — USMC 6200.1E §3.2 work/rest matrix
- `fetchWeatherCascade` — NWS → Open-Meteo → simulated fallback
- `promoteVerdict` — go/delay/alternate transition rules

Every primary function returns `{ result, audit }` (Approach B audit
envelope). The audit is a tree-structured `AuditRecord` with citation,
constants, inputs, function name, and an ISO 8601 `computed_at` from an
injectable clock. CI enforces byte-equal `canonicalJson(audit)` across TS
and Dart against the cascade-replay fixtures.

## Layout

- `spec/tier<N>-<name>/` — hand-authored JSON Schemas + CSV fixtures + primary-source citations.
- `packages/spec-types-ts/` — published as `@heatcompass/heat-engine-spec` on npm.
- `packages/spec-types-dart/` — published as `heat_engine_spec` on pub.dev.

## Tier roadmap

| Version | Tier | Contents |
|---|---|---|
| 0.1.0 | T1 — Foundation | wet-bulb (Stull 2011), USMC 6200.1E flag mapping, work/rest, weather cascade, verdict promotion |
| 0.2.0 | T2 — WBGT family | Liljegren simplified, USMC WBGT (°C and °F) |
| 0.3.0 | T3 — Atmospheric add-ons | Altitude-adjusted, equipment-adjusted, dewpoint |
| 1.0.0 | T4 — Apparent-temperature siblings | Heat index (Rothfusz), wind chill |

## Governance

Changes to existing fixture values that flip pass/fail = MINOR version bump.
New fixture additions or tolerance widening = PATCH bump.
Schema field changes pre-1.0 = MINOR bump. Post-1.0 = MAJOR.

See `docs/superpowers/specs/2026-05-26-heat-engine-spec-design.md` in
`HeatCompass/console` for the full design.

## Citations

- Stull, R. (2011). Wet-Bulb Temperature from Relative Humidity and Air Temperature. *J. Appl. Meteor. Climatol.* **50**: 2267–2269.
- U.S. Marine Corps Order 6200.1E — Marine Corps Heat Injury Prevention Program.
- National Weather Service `api.weather.gov`.
- Open-Meteo Weather Forecast API `api.open-meteo.com`.

## Publishing (operator-only)

The release workflow publishes both packages atomically when a `v*` tag is
pushed to `main`. Auth is configured as:

- **npm**: `NPM_TOKEN` automation token from `@heatcompass` npm org, set as a
  repo secret. Generate at https://www.npmjs.com/settings/heatcompass/tokens
  (type "Automation").
- **pub.dev**: OIDC trusted publisher entry registered for this repo under
  the `heatcompass.com` verified publisher. No secret needed.

Tagging:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow asserts the tag matches `SPEC_VERSION` / `specVersion` in both
languages and in both package manifests, asserts a `CHANGELOG.md` entry
exists, runs both test suites, then publishes to npm and pub.dev and creates
a GitHub Release.

## License

MIT — see [LICENSE](./LICENSE).
