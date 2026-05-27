#!/usr/bin/env bash
set -euo pipefail

# Regenerates TS types in packages/spec-types-ts/src/generated/ from JSON Schemas
# in spec/. Run from repo root: ./scripts/generate-types.sh
#
# CI runs this then `git diff --exit-code` to ensure committed output matches schemas.

cd "$(dirname "$0")/.."

OUT_DIR="packages/spec-types-ts/src/generated/tier1"
mkdir -p "$OUT_DIR"

# Only schemas whose TS types are consumed via packages/spec-types-ts/src/types.ts
# are generated here. The audit envelope (audit.schema.json) is hand-written in
# packages/spec-types-ts/src/audit.ts, and the Phase D module types
# (refuge-break-*, verdict-*, cascade-*, cascade-fixtures) are hand-written
# directly in types.ts because they're richer than what json2ts can emit (e.g.
# discriminated unions, narrowed enum literals, optional fields with semantic
# defaults). The schemas still exist and are validated in CI for JSON-shape
# conformance via scripts/validate-fixtures.sh.
GENERATE=(
  wet-bulb-input
  wet-bulb-output
  flag-mapping-input
  flag-mapping-output
)

for base in "${GENERATE[@]}"; do
  schema="spec/tier1-foundation/$base.schema.json"
  out="$OUT_DIR/$base.d.ts"
  echo "  $schema -> $out"
  npx --yes -p json-schema-to-typescript@^15.0.0 json2ts \
    --input "$schema" \
    --output "$out" \
    --bannerComment "/* DO NOT EDIT. Generated from $schema by scripts/generate-types.sh */"
done

echo "==> Generated TS types in $OUT_DIR."
