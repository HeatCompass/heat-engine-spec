import { describe, it, expect } from 'vitest';
import { loadWetBulbFixtures } from '../src/fixtures.js';
import { calculateWetBulb } from '../src/wetbulb.js';
import { canonicalJson } from '../src/canonicalJson.js';
import { buildAudit } from '../src/audit.js';
import { SPEC_VERSION } from '../src/specVersion.js';

const FIXED_CLOCK = () => new Date('2026-05-26T17:00:00.000Z');

const STULL_CONSTANTS = {
  stull_a: 0.151977,
  stull_b: 8.313659,
  stull_c: 1.676331,
  stull_d: 0.00391838,
  stull_e: 0.023101,
  stull_offset: -4.686035,
};

describe('wetbulb conformance against existing 38-row fixture', () => {
  const rows = loadWetBulbFixtures();

  it('loads >= 38 rows', () => {
    expect(rows.length).toBeGreaterThanOrEqual(38);
  });

  for (const row of rows) {
    it(`${row.id}: T=${row.tempC}°C RH=${row.rhPercent}% → expected ${row.expectedWetBulbC.toFixed(6)}°C`, () => {
      const ctx = { clock: FIXED_CLOCK };
      const { result, audit } = calculateWetBulb(
        { tempC: row.tempC, rhPercent: row.rhPercent },
        ctx,
      );

      // Result: numeric closeness within fixture-declared tolerance.
      expect(result).not.toBeNull();
      expect(Math.abs(result!.wetBulbC - row.expectedWetBulbC)).toBeLessThanOrEqual(row.toleranceC);
      expect(Math.abs(result!.wetBulbF - row.expectedWetBulbF)).toBeLessThanOrEqual(row.toleranceC * 9 / 5 + 1e-9);

      // Audit: structural sanity (full byte-equality kicked over to the
      // cross-lang-equiv CI gate, since the audit's wetBulbC display
      // depends on impl-side toFixed which TS and Dart both render the
      // same way for these rows but isn't worth fixture-pinning here).
      expect(audit.spec_version).toBe(SPEC_VERSION);
      expect(audit.function).toBe('calculateWetBulb');
      expect(audit.citation).toBe('Stull (2011) eq. 1');
      expect(audit.computed_at).toBe('2026-05-26T17:00:00.000Z');
      expect(audit.inputs).toEqual({ tempC: row.tempC, rhPercent: row.rhPercent });
      expect(audit.constants).toEqual(STULL_CONSTANTS);
      expect(audit.result_summary).toMatch(/^T=.*°C RH=.*% → Tw=.*°C$/);
    });
  }
});

describe('wetbulb invalid input branches', () => {
  it('NaN tempC returns null result with invalid_input:tempC audit', () => {
    const { result, audit } = calculateWetBulb(
      { tempC: Number.NaN, rhPercent: 50 },
      { clock: () => new Date('2026-05-26T17:00:00.000Z') },
    );
    expect(result).toBeNull();
    expect(audit.result_summary).toBe('invalid_input:tempC');
    expect(audit.constants).toEqual({});
    expect(audit.inputs).toEqual({ tempC: 'NaN', rhPercent: 50 });
  });

  it('RH=120 is clamped to 100 and marked in audit', () => {
    const { result, audit } = calculateWetBulb(
      { tempC: 25, rhPercent: 120 },
      { clock: () => new Date('2026-05-26T17:00:00.000Z') },
    );
    expect(result).not.toBeNull();
    expect(result!.clampedRhPct).toBe(100);
    expect(audit.result_summary).toContain('rh_clamped');
    expect(audit.constants).toMatchObject({ rh_clamp_min: 5, rh_clamp_max: 100 });
  });

  it('tempC=60 (out of validity) computes a result but marks the audit', () => {
    const { result, audit } = calculateWetBulb(
      { tempC: 60, rhPercent: 50 },
      { clock: () => new Date('2026-05-26T17:00:00.000Z') },
    );
    expect(result).not.toBeNull();
    expect(audit.result_summary).toContain('out_of_validity_range');
  });

  it('canonical audit JSON sorts keys alphabetically', () => {
    const { audit } = calculateWetBulb(
      { tempC: 20, rhPercent: 50 },
      { clock: () => new Date('2026-05-26T17:00:00.000Z') },
    );
    const json = canonicalJson(audit as unknown as Record<string, unknown>);
    // Verify the audit is canonical-serializable and key-sorted.
    expect(json).toContain('"citation":"Stull (2011) eq. 1"');
    expect(json.indexOf('"citation"')).toBeLessThan(json.indexOf('"computed_at"'));
    expect(json.indexOf('"function"')).toBeLessThan(json.indexOf('"inputs"'));
  });
});
