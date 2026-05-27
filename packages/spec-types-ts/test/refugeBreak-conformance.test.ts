import { describe, it, expect } from 'vitest';
import { loadRefugeBreakFixtures } from '../src/fixtures.js';
import { workRestForFlag } from '../src/refugeBreak.js';
import { canonicalJson } from '../src/canonicalJson.js';
import { SPEC_VERSION } from '../src/specVersion.js';

const FIXED_CLOCK = () => new Date('2026-05-26T17:00:00.000Z');

describe('refugeBreak conformance against existing 10-row fixture', () => {
  const rows = loadRefugeBreakFixtures();

  it('loads >= 10 rows', () => {
    expect(rows.length).toBeGreaterThanOrEqual(10);
  });

  for (const row of rows) {
    it(`${row.id}: ${row.flag}/${row.acclimatized ? 'acclim' : 'unacclim'}`, () => {
      const ctx = { clock: FIXED_CLOCK };
      const { result, audit } = workRestForFlag(
        {
          flag: row.flag,
          acclimatized: row.acclimatized,
          workMinutesRequested: row.workMinutesRequested,
        },
        ctx,
      );

      expect(result).not.toBeNull();
      expect(result!.workMinutes).toBe(row.expectedWorkMinutes);
      expect(result!.restMinutes).toBe(row.expectedRestMinutes);
      expect(result!.cyclesUntilReassessRequired).toBe(
        row.expectedCyclesUntilReassessRequired,
      );
      expect(result!.ceaseWork).toBe(row.expectedCeaseWork);

      expect(audit.spec_version).toBe(SPEC_VERSION);
      expect(audit.function).toBe('workRestForFlag');
      expect(audit.citation).toBe('USMC 6200.1E §3.2');
      expect(audit.computed_at).toBe('2026-05-26T17:00:00.000Z');
      expect(audit.inputs).toEqual({
        flag: row.flag,
        acclimatized: row.acclimatized,
        workMinutesRequested: row.workMinutesRequested,
      });
      if (row.expectedCeaseWork) {
        expect(audit.constants).toEqual({});
        expect(audit.result_summary).toBe(
          `${row.flag}/${row.acclimatized ? 'acclim' : 'unacclim'} → cease_work`,
        );
      } else {
        const branch = row.acclimatized ? 'acclim' : 'unacclim';
        expect(audit.constants).toMatchObject({
          [`${row.flag}_work_${branch}`]: row.expectedWorkMinutes,
          [`${row.flag}_rest_${branch}`]: row.expectedRestMinutes,
        });
        expect(audit.result_summary).toMatch(
          /^(white|green|yellow|red|black)\/(acclim|unacclim) → \d+w\/\d+r/,
        );
      }
    });
  }
});

describe('refugeBreak summary phrasing edges', () => {
  const FIXED = { clock: FIXED_CLOCK };

  it('reassess=1 phrases as "reassess every cycle"', () => {
    const { result, audit } = workRestForFlag(
      { flag: 'black', acclimatized: true, workMinutesRequested: 60 },
      FIXED,
    );
    expect(result?.cyclesUntilReassessRequired).toBe(1);
    expect(audit.result_summary).toBe('black/acclim → 10w/50r, reassess every cycle');
    expect(audit.constants).toEqual({
      black_work_acclim: 10,
      black_rest_acclim: 50,
      black_reassess_cycles: 1,
    });
  });

  it('reassess>1 acclim uses _reassess_cycles key', () => {
    const { audit } = workRestForFlag(
      { flag: 'yellow', acclimatized: true, workMinutesRequested: 60 },
      FIXED,
    );
    expect(audit.constants).toEqual({
      yellow_work_acclim: 45,
      yellow_rest_acclim: 15,
      yellow_reassess_cycles: 6,
    });
    expect(audit.result_summary).toBe(
      'yellow/acclim → 45w/15r, reassess after 6 cycles',
    );
  });

  it('reassess>1 unacclim uses _reassess_cycles_unacclim key', () => {
    const { audit } = workRestForFlag(
      { flag: 'yellow', acclimatized: false, workMinutesRequested: 60 },
      FIXED,
    );
    expect(audit.constants).toEqual({
      yellow_work_unacclim: 30,
      yellow_rest_unacclim: 30,
      yellow_reassess_cycles_unacclim: 4,
    });
  });

  it('cease branch returns 0/0 with empty constants', () => {
    const { result, audit } = workRestForFlag(
      { flag: 'red', acclimatized: false, workMinutesRequested: 60 },
      FIXED,
    );
    expect(result).toEqual({
      workMinutes: 0,
      restMinutes: 0,
      cyclesUntilReassessRequired: null,
      ceaseWork: true,
    });
    expect(audit.constants).toEqual({});
    expect(audit.result_summary).toBe('red/unacclim → cease_work');
  });
});

describe('refugeBreak invalid input', () => {
  const FIXED = { clock: FIXED_CLOCK };

  it('non-positive workMinutesRequested adds non_positive_work_window marker', () => {
    const { result, audit } = workRestForFlag(
      { flag: 'green', acclimatized: true, workMinutesRequested: 0 },
      FIXED,
    );
    expect(result?.workMinutes).toBe(50);
    expect(audit.result_summary).toBe(
      'green/acclim → 50w/10r (non_positive_work_window)',
    );
  });

  it('NaN workMinutesRequested returns null with invalid_input audit', () => {
    const { result, audit } = workRestForFlag(
      { flag: 'green', acclimatized: true, workMinutesRequested: Number.NaN },
      FIXED,
    );
    expect(result).toBeNull();
    expect(audit.result_summary).toBe('invalid_input:workMinutesRequested');
    expect(audit.inputs).toEqual({
      flag: 'green',
      acclimatized: true,
      workMinutesRequested: 'NaN',
    });
    expect(audit.constants).toEqual({});
  });

  it('invalid flag (cast through unknown) returns null with invalid_input audit', () => {
    const { result, audit } = workRestForFlag(
      {
        flag: 'purple' as unknown as 'white',
        acclimatized: true,
        workMinutesRequested: 60,
      },
      FIXED,
    );
    expect(result).toBeNull();
    expect(audit.result_summary).toBe('invalid_input:flag');
  });

  it('canonical audit JSON sorts keys alphabetically', () => {
    const { audit } = workRestForFlag(
      { flag: 'yellow', acclimatized: true, workMinutesRequested: 60 },
      FIXED,
    );
    const json = canonicalJson(audit as unknown as Record<string, unknown>);
    expect(json).toContain('"citation":"USMC 6200.1E §3.2"');
    expect(json.indexOf('"computed_at"')).toBeLessThan(json.indexOf('"constants"'));
  });
});
