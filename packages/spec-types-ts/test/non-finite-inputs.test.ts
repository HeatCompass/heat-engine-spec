// JSON has no NaN or Infinity. Audits write such inputs as the strings
// "NaN", "Infinity" and "-Infinity" in both implementations; the expected
// canonical audits below are the same literals as in the Dart test
// (test/non_finite_inputs_test.dart), so the two stay byte-equal.
import { describe, it, expect } from 'vitest';
import { calculateWetBulb } from '../src/wetbulb.js';
import { flagFromWetBulbF } from '../src/flag.js';
import { workRestForFlag } from '../src/refugeBreak.js';
import { canonicalJson } from '../src/canonicalJson.js';

const FIXED = { clock: () => new Date('2026-05-26T17:00:00.000Z') };

describe('non-finite inputs in audits', () => {
  it('flagFromWetBulbF(Infinity)', () => {
    const { result, audit } = flagFromWetBulbF(Infinity, FIXED);
    expect(result).toBeNull();
    expect(canonicalJson(audit as unknown as Record<string, unknown>)).toBe(
      '{"citation":"USMC 6200.1E Table 3-1","computed_at":"2026-05-26T17:00:00.000Z","constants":{},"function":"flagFromWetBulbF","inputs":{"wetBulbF":"Infinity"},"result_summary":"invalid_input:wetBulbF","spec_version":"0.1.1"}',
    );
  });

  it('calculateWetBulb with rhPercent -Infinity', () => {
    const { result, audit } = calculateWetBulb({ tempC: 30, rhPercent: -Infinity }, FIXED);
    expect(result).toBeNull();
    expect(canonicalJson(audit as unknown as Record<string, unknown>)).toBe(
      '{"citation":"Stull (2011) eq. 1","computed_at":"2026-05-26T17:00:00.000Z","constants":{},"function":"calculateWetBulb","inputs":{"rhPercent":"-Infinity","tempC":30},"result_summary":"invalid_input:rhPercent","spec_version":"0.1.1"}',
    );
  });

  it('workRestForFlag with workMinutesRequested Infinity (TS only: Dart takes an int)', () => {
    const { audit } = workRestForFlag({ flag: 'green', acclimatized: true, workMinutesRequested: Infinity }, FIXED);
    expect(audit.inputs).toEqual({ flag: 'green', acclimatized: true, workMinutesRequested: 'Infinity' });
  });

  it('canonicalJson writes non-finite numbers as strings, not null', () => {
    expect(canonicalJson({ a: Infinity, b: -Infinity, c: Number.NaN })).toBe('{"a":"Infinity","b":"-Infinity","c":"NaN"}');
  });
});
