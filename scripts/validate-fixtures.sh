#!/usr/bin/env bash
set -euo pipefail

# Validates that:
#   (a) every JSON Schema parses (via `ajv compile`)
#   (b) every fixture CSV has the expected column header
#   (c) every fixture row's source_ref resolves to a heading in references.md
#
# Run from repo root: ./scripts/validate-fixtures.sh

cd "$(dirname "$0")/.."

echo "==> Validating JSON Schemas (ajv compile)"
for schema in spec/tier1-foundation/*.schema.json; do
  echo "  - $schema"
  npx --yes ajv-cli compile -s "$schema" --spec=draft2020 > /dev/null
done

echo "==> Validating fixture column headers"

EXPECTED_WB_HEADER="id,source_ref,temp_c,rh_percent,expected_wet_bulb_c,expected_wet_bulb_f,tolerance_c,notes"
ACTUAL_WB_HEADER=$(head -1 spec/tier1-foundation/wet-bulb.fixtures.csv | tr -d '\r')
if [[ "$ACTUAL_WB_HEADER" != "$EXPECTED_WB_HEADER" ]]; then
  echo "FAIL: wet-bulb.fixtures.csv header mismatch."
  echo "  expected: $EXPECTED_WB_HEADER"
  echo "  actual:   $ACTUAL_WB_HEADER"
  exit 1
fi

EXPECTED_FM_HEADER="id,source_ref,wet_bulb_f,expected_flag,expected_flag_dart_label,notes"
ACTUAL_FM_HEADER=$(head -1 spec/tier1-foundation/flag-mapping.fixtures.csv)
if [[ "$ACTUAL_FM_HEADER" != "$EXPECTED_FM_HEADER" ]]; then
  echo "FAIL: flag-mapping.fixtures.csv header mismatch."
  echo "  expected: $EXPECTED_FM_HEADER"
  echo "  actual:   $ACTUAL_FM_HEADER"
  exit 1
fi

echo "==> Validating source_ref resolution"

# Extract all defined refs from references.md (lines starting with `## `).
DEFINED_REFS=$(grep -E '^## ' spec/tier1-foundation/references.md | sed 's/^## //' | sort -u)

# Extract all used refs from both fixtures (column 2, skip header).
USED_REFS=$( {
  tail -n +2 spec/tier1-foundation/wet-bulb.fixtures.csv | cut -d, -f2
  tail -n +2 spec/tier1-foundation/flag-mapping.fixtures.csv | cut -d, -f2
} | sort -u)

for ref in $USED_REFS; do
  if ! echo "$DEFINED_REFS" | grep -qx "$ref"; then
    echo "FAIL: source_ref '$ref' used in a fixture row but not defined in references.md"
    exit 1
  fi
done

echo "==> All validations passed."
