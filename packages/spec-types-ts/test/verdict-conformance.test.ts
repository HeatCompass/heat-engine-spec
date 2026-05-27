import { describe, it, expect } from 'vitest';
import { loadVerdictFixtures } from '../src/fixtures.js';
import { promoteVerdict } from '../src/verdict.js';
import { canonicalJson } from '../src/canonicalJson.js';
import { SPEC_VERSION } from '../src/specVersion.js';

const FIXED_CLOCK = () => new Date('2026-05-26T17:00:00.000Z');

describe('verdict conformance against existing 8-row fixture', () => {
  const rows = loadVerdictFixtures();

  it('loads >= 8 rows', () => {
    expect(rows.length).toBeGreaterThanOrEqual(8);
  });

  for (const row of rows) {
    it(`${row.id}: ${row.priorFlag ?? 'null'} → ${row.currentFlag}`, () => {
      const ctx = { clock: FIXED_CLOCK };
      const { result, audit } = promoteVerdict(
        {
          priorVerdict: row.priorVerdict,
          priorFlag: row.priorFlag,
          currentFlag: row.currentFlag,
          hasAlternateAvailable: row.hasAlternateAvailable,
        },
        ctx,
      );

      expect(result).not.toBeNull();
      expect(result!.verdict).toBe(row.expectedVerdict);
      expect(result!.changedFromPrior).toBe(row.expectedChangedFromPrior);
      expect(result!.promotionRule).toBe(row.expectedPromotionRule);

      expect(audit.spec_version).toBe(SPEC_VERSION);
      expect(audit.function).toBe('promoteVerdict');
      expect(audit.citation).toBe('heat-engine-spec design doc §2.5');
      expect(audit.computed_at).toBe('2026-05-26T17:00:00.000Z');
      expect(audit.constants).toEqual({});
      expect(audit.inputs).toEqual({
        priorVerdict: row.priorVerdict,
        priorFlag: row.priorFlag,
        currentFlag: row.currentFlag,
        hasAlternateAvailable: row.hasAlternateAvailable,
      });
      expect(audit.prior_flag).toBe(row.priorFlag);
      expect(audit.next_flag).toBe(row.currentFlag);
      expect(audit.promotion_rule).toBe(row.expectedPromotionRule);
    });
  }
});

describe('verdict promotion rule branches', () => {
  const FIXED = { clock: FIXED_CLOCK };

  it('FIRST_RUN_DEFAULT renders summary "first run, …"', () => {
    const { audit } = promoteVerdict(
      {
        priorVerdict: null,
        priorFlag: null,
        currentFlag: 'yellow',
        hasAlternateAvailable: false,
      },
      FIXED,
    );
    expect(audit.result_summary).toBe('first run, yellow → go');
    expect(audit.prior_flag).toBeNull();
  });

  it('NO_CHANGE with held delay adds "(held)"', () => {
    const { result, audit } = promoteVerdict(
      {
        priorVerdict: 'delay',
        priorFlag: 'red',
        currentFlag: 'red',
        hasAlternateAvailable: false,
      },
      FIXED,
    );
    expect(result?.verdict).toBe('delay');
    expect(audit.result_summary).toBe('no_change, red → delay (held)');
  });

  it('NO_CHANGE without held delay omits "(held)"', () => {
    const { audit } = promoteVerdict(
      {
        priorVerdict: 'go',
        priorFlag: 'green',
        currentFlag: 'green',
        hasAlternateAvailable: false,
      },
      FIXED,
    );
    expect(audit.result_summary).toBe('no_change, green → go');
  });

  it('ALTERNATE_AVAILABLE_AT_BLACK fires at black with alternate=true', () => {
    const { result, audit } = promoteVerdict(
      {
        priorVerdict: 'go',
        priorFlag: 'yellow',
        currentFlag: 'black',
        hasAlternateAvailable: true,
      },
      FIXED,
    );
    expect(result?.verdict).toBe('alternate');
    expect(result?.promotionRule).toBe('ALTERNATE_AVAILABLE_AT_BLACK');
    expect(audit.result_summary).toBe('yellow → black + alternate → alternate');
  });

  it('ESCALATE rule fires at red without alternate', () => {
    const { result, audit } = promoteVerdict(
      {
        priorVerdict: 'go',
        priorFlag: 'green',
        currentFlag: 'red',
        hasAlternateAvailable: false,
      },
      FIXED,
    );
    expect(result?.verdict).toBe('delay');
    expect(audit.result_summary).toBe('green → red, escalate to delay');
  });

  it('ESCALATE rule fires at black when no alternate', () => {
    const { result, audit } = promoteVerdict(
      {
        priorVerdict: 'go',
        priorFlag: 'yellow',
        currentFlag: 'black',
        hasAlternateAvailable: false,
      },
      FIXED,
    );
    expect(result?.verdict).toBe('delay');
    expect(result?.promotionRule).toBe('ESCALATE_TO_DELAY_ON_RED_OR_BLACK');
    expect(audit.result_summary).toBe('yellow → black, escalate to delay');
  });

  it('DEESCALATE rule fires when leaving red/black', () => {
    const { result, audit } = promoteVerdict(
      {
        priorVerdict: 'delay',
        priorFlag: 'red',
        currentFlag: 'green',
        hasAlternateAvailable: false,
      },
      FIXED,
    );
    expect(result?.verdict).toBe('go');
    expect(audit.result_summary).toBe('red → green, deescalate to go');
  });
});

describe('verdict invalid input', () => {
  const FIXED = { clock: FIXED_CLOCK };

  it('invalid currentFlag returns null with invalid_input audit', () => {
    const { result, audit } = promoteVerdict(
      {
        priorVerdict: 'go',
        priorFlag: 'green',
        currentFlag: 'purple' as 'white',
        hasAlternateAvailable: false,
      },
      FIXED,
    );
    expect(result).toBeNull();
    expect(audit.result_summary).toBe('invalid_input:currentFlag');
  });

  it('invalid priorVerdict returns null with invalid_input audit', () => {
    const { result, audit } = promoteVerdict(
      {
        priorVerdict: 'maybe' as 'go',
        priorFlag: 'green',
        currentFlag: 'red',
        hasAlternateAvailable: false,
      },
      FIXED,
    );
    expect(result).toBeNull();
    expect(audit.result_summary).toBe('invalid_input:priorVerdict');
  });

  it('canonical audit JSON sorts keys alphabetically and includes verdict fields', () => {
    const { audit } = promoteVerdict(
      {
        priorVerdict: 'go',
        priorFlag: 'yellow',
        currentFlag: 'black',
        hasAlternateAvailable: true,
      },
      FIXED,
    );
    const json = canonicalJson(audit as unknown as Record<string, unknown>);
    expect(json).toContain('"promotion_rule":"ALTERNATE_AVAILABLE_AT_BLACK"');
    expect(json).toContain('"prior_flag":"yellow"');
    expect(json).toContain('"next_flag":"black"');
    expect(json.indexOf('"next_flag"')).toBeLessThan(json.indexOf('"prior_flag"'));
  });
});
