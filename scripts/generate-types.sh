#!/usr/bin/env bash
set -euo pipefail

# Regenerates TS types in packages/spec-types-ts/src/generated/ from JSON Schemas
# in spec/. Run from repo root: ./scripts/generate-types.sh
#
# CI runs this then `git diff --exit-code` to ensure committed output matches schemas.

cd "$(dirname "$0")/.."

OUT_DIR="packages/spec-types-ts/src/generated/tier1"
mkdir -p "$OUT_DIR"

for schema in spec/tier1-foundation/*.schema.json; do
  base=$(basename "$schema" .schema.json)
  out="$OUT_DIR/$base.d.ts"
  echo "  $schema -> $out"
  npx --yes -p json-schema-to-typescript@^15.0.0 json2ts \
    --input "$schema" \
    --output "$out" \
    --bannerComment "/* DO NOT EDIT. Generated from $schema by scripts/generate-types.sh */"
done

echo "==> Generated TS types in $OUT_DIR."
