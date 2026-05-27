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
# For each schema, build a -r flag list of every *other* schema in the dir
# so cross-file $refs (e.g., cascade-fixtures.schema.json → audit.schema.json)
# resolve without colliding with the schema being compiled as the main `-s`.
for schema in spec/tier1-foundation/*.schema.json; do
  echo "  - $schema"
  REF_FLAGS=()
  for other in spec/tier1-foundation/*.schema.json; do
    if [[ "$other" != "$schema" ]]; then
      REF_FLAGS+=(-r "$other")
    fi
  done
  npx --yes ajv-cli compile -s "$schema" --spec=draft2020 "${REF_FLAGS[@]}" > /dev/null
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

EXPECTED_RB_HEADER="id,source_ref,flag,acclimatized,work_minutes_requested,expected_work_minutes,expected_rest_minutes,expected_cycles_until_reassess_required,expected_cease_work,notes"
ACTUAL_RB_HEADER=$(head -1 spec/tier1-foundation/refuge-break.fixtures.csv | tr -d '\r')
if [[ "$ACTUAL_RB_HEADER" != "$EXPECTED_RB_HEADER" ]]; then
  echo "FAIL: refuge-break.fixtures.csv header mismatch."
  echo "  expected: $EXPECTED_RB_HEADER"
  echo "  actual:   $ACTUAL_RB_HEADER"
  exit 1
fi

EXPECTED_VP_HEADER="id,source_ref,prior_verdict,prior_flag,current_flag,has_alternate_available,expected_verdict,expected_changed_from_prior,expected_promotion_rule,notes"
ACTUAL_VP_HEADER=$(head -1 spec/tier1-foundation/verdict-promotion.fixtures.csv | tr -d '\r')
if [[ "$ACTUAL_VP_HEADER" != "$EXPECTED_VP_HEADER" ]]; then
  echo "FAIL: verdict-promotion.fixtures.csv header mismatch."
  echo "  expected: $EXPECTED_VP_HEADER"
  echo "  actual:   $ACTUAL_VP_HEADER"
  exit 1
fi

echo "==> Validating cascade-replay JSON fixtures against cascade-fixtures.schema.json"
if [[ -d spec/tier1-foundation/cascade-replay ]]; then
  for f in spec/tier1-foundation/cascade-replay/*.json; do
    [[ -f "$f" ]] || continue
    echo "  - $f"
    npx --yes ajv-cli validate \
      -s spec/tier1-foundation/cascade-fixtures.schema.json \
      -r spec/tier1-foundation/audit.schema.json \
      -d "$f" --spec=draft2020 > /dev/null
  done
fi

echo "==> Validating source_ref resolution"

# Extract all defined refs from references.md (lines starting with `## `).
DEFINED_REFS=$(grep -E '^## ' spec/tier1-foundation/references.md | sed 's/^## //' | sort -u)

# Extract all used refs from every fixture CSV (column 2, skip header).
USED_REFS=$(
  for f in spec/tier1-foundation/*.fixtures.csv; do
    tail -n +2 "$f" | cut -d, -f2
  done | sort -u
)

for ref in $USED_REFS; do
  if ! echo "$DEFINED_REFS" | grep -qx "$ref"; then
    echo "FAIL: source_ref '$ref' used in a fixture row but not defined in references.md"
    exit 1
  fi
done

echo "==> All validations passed."
