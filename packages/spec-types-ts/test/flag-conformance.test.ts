import { describe, it, expect } from 'vitest';
import { loadFlagMappingFixtures } from '../src/fixtures.js';
import { flagFromWetBulbF, flagFromWetBulbC } from '../src/flag.js';
import { canonicalJson } from '../src/canonicalJson.js';
import { SPEC_VERSION } from '../src/specVersion.js';

const FIXED_CLOCK = () => new Date('2026-05-26T17:00:00.000Z');
const BOUNDARY_CONSTANTS = {
  white_max: 80,
  green_max: 85,
  yellow_max: 88,
  red_max: 90,
};

describe('flag conformance against existing 20-row fixture', () => {
  const rows = loadFlagMappingFixtures();

  it('loads >= 20 rows', () => {
    expect(rows.length).toBeGreaterThanOrEqual(20);
  });

  for (const row of rows) {
    it(`${row.id}: wetBulbF=${row.wetBulbF} → ${row.expectedFlag}/${row.expectedFlagDartLabel}`, () => {
      const ctx = { clock: FIXED_CLOCK };
      const { result, audit } = flagFromWetBulbF(row.wetBulbF, ctx);
      expect(result).not.toBeNull();
      expect(result!.flag).toBe(row.expectedFlag);
      expect(result!.flagDartLabel).toBe(row.expectedFlagDartLabel);

      expect(audit.spec_version).toBe(SPEC_VERSION);
      expect(audit.function).toBe('flagFromWetBulbF');
      expect(audit.citation).toBe('USMC 6200.1E Table 3-1');
      expect(audit.computed_at).toBe('2026-05-26T17:00:00.000Z');
      expect(audit.inputs).toEqual({ wetBulbF: row.wetBulbF });
      expect(audit.constants).toEqual(BOUNDARY_CONSTANTS);
      expect(audit.result_summary).toMatch(/^wetBulbF=.+ → (white|green|yellow|red|black)/);
    });
  }
});

describe('flag edge cases + invalid input', () => {
  const FIXED = { clock: FIXED_CLOCK };

  it('NaN returns null result with invalid_input audit', () => {
    const { result, audit } = flagFromWetBulbF(Number.NaN, FIXED);
    expect(result).toBeNull();
    expect(audit.result_summary).toBe('invalid_input:wetBulbF');
    expect(audit.inputs).toEqual({ wetBulbF: 'NaN' });
    expect(audit.constants).toEqual({});
  });

  it('out_of_observed_range marker fires at extreme values', () => {
    const { result, audit } = flagFromWetBulbF(250, FIXED);
    expect(result?.flag).toBe('black');
    expect(audit.result_summary).toContain('out_of_observed_range');
  });

  it('accepts FlagMappingInput object form', () => {
    const { result } = flagFromWetBulbF({ wetBulbF: 85 }, FIXED);
    expect(result?.flag).toBe('yellow');
  });

  it('flagFromWetBulbC converts then nests the F-form audit as a child', () => {
    const { result, audit } = flagFromWetBulbC(30, FIXED); // 30°C ≈ 86°F → yellow
    expect(result?.flag).toBe('yellow');
    expect(audit.function).toBe('flagFromWetBulbC');
    expect(audit.children).toHaveLength(1);
    expect(audit.children![0]!.function).toBe('flagFromWetBulbF');
  });

  it('flagFromWetBulbC with NaN returns null + invalid_input audit', () => {
    const { result, audit } = flagFromWetBulbC(Number.NaN, FIXED);
    expect(result).toBeNull();
    expect(audit.result_summary).toBe('invalid_input:wetBulbC');
  });

  it('canonical audit JSON sorts keys alphabetically', () => {
    const { audit } = flagFromWetBulbF(85, FIXED);
    const json = canonicalJson(audit as unknown as Record<string, unknown>);
    expect(json).toContain('"citation":"USMC 6200.1E Table 3-1"');
    expect(json.indexOf('"computed_at"')).toBeLessThan(json.indexOf('"constants"'));
  });
});
