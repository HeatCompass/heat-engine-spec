import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { parse } from 'csv-parse/sync';
import type {
  WetBulbFixtureRow,
  FlagMappingFixtureRow,
  RefugeBreakFixtureRow,
  VerdictFixtureRow,
  EnvironmentalFlag,
  HeatRiskLevelLabel,
  Verdict,
  PromotionRule,
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

export function loadRefugeBreakFixtures(): RefugeBreakFixtureRow[] {
  const csv = readFileSync(resolve(FIXTURES_DIR, 'refuge-break.fixtures.csv'), 'utf-8');
  const raw = parse(csv, { columns: true, skip_empty_lines: true }) as Record<string, string>[];
  return raw.map((r) => ({
    id: r.id,
    sourceRef: r.source_ref,
    flag: r.flag as EnvironmentalFlag,
    acclimatized: r.acclimatized === 'true',
    workMinutesRequested: Number(r.work_minutes_requested),
    expectedWorkMinutes: Number(r.expected_work_minutes),
    expectedRestMinutes: Number(r.expected_rest_minutes),
    expectedCyclesUntilReassessRequired:
      r.expected_cycles_until_reassess_required === ''
        ? null
        : Number(r.expected_cycles_until_reassess_required),
    expectedCeaseWork: r.expected_cease_work === 'true',
    notes: r.notes,
  }));
}

export function loadVerdictFixtures(): VerdictFixtureRow[] {
  const csv = readFileSync(resolve(FIXTURES_DIR, 'verdict-promotion.fixtures.csv'), 'utf-8');
  const raw = parse(csv, { columns: true, skip_empty_lines: true }) as Record<string, string>[];
  return raw.map((r) => ({
    id: r.id,
    sourceRef: r.source_ref,
    priorVerdict: r.prior_verdict === '' ? null : (r.prior_verdict as Verdict),
    priorFlag: r.prior_flag === '' ? null : (r.prior_flag as EnvironmentalFlag),
    currentFlag: r.current_flag as EnvironmentalFlag,
    hasAlternateAvailable: r.has_alternate_available === 'true',
    expectedVerdict: r.expected_verdict as Verdict,
    expectedChangedFromPrior: r.expected_changed_from_prior === 'true',
    expectedPromotionRule: r.expected_promotion_rule as PromotionRule,
    notes: r.notes,
  }));
}
