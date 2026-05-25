# heat-engine-spec

Spec-of-record for the heat-stress calculation engine shared between:
- **HeatCompass** (consumer Flutter app)
- **HeatCompass Console** (B2B TypeScript stack)

This repo owns the contract. Both implementations must conform.

## Layout

- `spec/tier<N>-<name>/` — hand-authored JSON Schemas + CSV fixtures + primary-source citations.
- `packages/spec-types-ts/` — published as `@heatcompass/heat-engine-spec` on npm.
- `packages/spec-types-dart/` — published as `heat_engine_spec` on pub.dev.

## Tier roadmap

| Version | Tier | Contents |
|---|---|---|
| 0.1.0 | T1 — Foundation | wet-bulb (Stull 2011), USMC 6200.1E flag mapping |
| 0.2.0 | T2 — WBGT family | Liljegren simplified, USMC WBGT (°C and °F) |
| 0.3.0 | T3 — Atmospheric add-ons | Altitude-adjusted, equipment-adjusted, dewpoint |
| 1.0.0 | T4 — Apparent-temperature siblings | Heat index (Rothfusz), wind chill |

## Governance

Changes to existing fixture values that flip pass/fail = MINOR version bump.
New fixture additions or tolerance widening = PATCH bump.
Schema field changes pre-1.0 = MINOR bump. Post-1.0 = MAJOR.

See `docs/superpowers/specs/2026-05-25-heat-engine-spec-design.md` in `HeatCompass/console` for full design.

## Publishing (operator-only)

Two secrets must be set on the repo before tagging a release:

- `NPM_TOKEN` — automation token from `@heatcompass` npm org. Generate via
  https://www.npmjs.com/settings/heatcompass/tokens, type "Automation".
- `PUB_CREDENTIALS` — contents of `~/.config/dart/pub-credentials.json` from a
  `dart pub login` session under the verified publisher. Save raw JSON as the
  secret value.

Tagging:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The release workflow then publishes both packages.
