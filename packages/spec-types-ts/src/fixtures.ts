import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { parse } from 'csv-parse/sync';
import type {
  WetBulbFixtureRow,
  FlagMappingFixtureRow,
  EnvironmentalFlag,
  HeatRiskLevelLabel,
} from './types.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
// dist/fixtures.js (after build) → ../fixtures/  (sibling to dist/)
// src/fixtures.ts (in test)     → ../fixtures/  (sibling to src/)
const FIXTURES_DIR = resolve(__dirname, '..', 'fixtures');

export function loadWetBulbFixtures(): WetBulbFixtureRow[] {
  const csv = readFileSync(resolve(FIXTURES_DIR, 'wet-bulb.fixtures.csv'), 'utf-8');
  const raw = parse(csv, { columns: true, skip_empty_lines: true }) as Record<string, string>[];
  return raw.map((r) => ({
    id: r.id,
    sourceRef: r.source_ref,
    tempC: Number(r.temp_c),
    rhPercent: Number(r.rh_percent),
    expectedWetBulbC: Number(r.expected_wet_bulb_c),
    expectedWetBulbF: Number(r.expected_wet_bulb_f),
    toleranceC: Number(r.tolerance_c),
    notes: r.notes,
  }));
}

export function loadFlagMappingFixtures(): FlagMappingFixtureRow[] {
  const csv = readFileSync(resolve(FIXTURES_DIR, 'flag-mapping.fixtures.csv'), 'utf-8');
  const raw = parse(csv, { columns: true, skip_empty_lines: true }) as Record<string, string>[];
  return raw.map((r) => ({
    id: r.id,
    sourceRef: r.source_ref,
    wetBulbF: Number(r.wet_bulb_f),
    expectedFlag: r.expected_flag as EnvironmentalFlag,
    expectedFlagDartLabel: r.expected_flag_dart_label as HeatRiskLevelLabel,
    notes: r.notes,
  }));
}
