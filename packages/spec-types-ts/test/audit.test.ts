import { describe, it, expect } from 'vitest';
import { buildAudit, type AuditRecord } from '../src/audit.js';
import { canonicalJson } from '../src/canonicalJson.js';
import { SPEC_VERSION } from '../src/specVersion.js';

const FIXED_CLOCK = () => new Date('2026-05-26T17:00:00.000Z');

describe('buildAudit', () => {
  it('stamps spec_version from the SPEC_VERSION constant', () => {
    const a = buildAudit({
      fn: 'testFn',
      inputs: { x: 1 },
      constants: {},
      citation: 'test',
      resultSummary: 'ok',
      ctx: { clock: FIXED_CLOCK },
    });
    expect(a.spec_version).toBe(SPEC_VERSION);
  });

  it('uses the injected clock when provided', () => {
    const a = buildAudit({
      fn: 'testFn',
      inputs: {},
      constants: {},
      citation: 'test',
      resultSummary: 'ok',
      ctx: { clock: FIXED_CLOCK },
    });
    expect(a.computed_at).toBe('2026-05-26T17:00:00.000Z');
  });

  it('defaults to new Date() when no clock is injected', () => {
    const before = Date.now();
    const a = buildAudit({
      fn: 'testFn',
      inputs: {},
      constants: {},
      citation: 'test',
      resultSummary: 'ok',
    });
    const after = Date.now();
    const stamped = Date.parse(a.computed_at);
    expect(stamped).toBeGreaterThanOrEqual(before);
    expect(stamped).toBeLessThanOrEqual(after);
  });

  it('merges extras on top of base record', () => {
    const a = buildAudit({
      fn: 'fetchWeatherCascade',
      inputs: { lat: 0, lng: 0 },
      constants: { nws_timeout_ms: 5000 },
      citation: 'cascade',
      resultSummary: 'ok',
      ctx: { clock: FIXED_CLOCK },
      extras: {
        source_chain: ['nws'],
        fallback_reason: 'none',
      },
    });
    expect(a.source_chain).toEqual(['nws']);
    expect(a.fallback_reason).toBe('none');
  });

  it('serializes to canonical JSON with sorted keys', () => {
    const a = buildAudit({
      fn: 'testFn',
      inputs: { x: 1 },
      constants: { c: 2 },
      citation: 'cite',
      resultSummary: 'r',
      ctx: { clock: FIXED_CLOCK },
    });
    const json = canonicalJson(a as unknown as Record<string, unknown>);
    expect(json).toBe(
      '{"citation":"cite","computed_at":"2026-05-26T17:00:00.000Z","constants":{"c":2},"function":"testFn","inputs":{"x":1},"result_summary":"r","spec_version":"' +
        SPEC_VERSION +
        '"}',
    );
  });

  it('produces ISO 8601 with .000Z millisecond precision', () => {
    const a: AuditRecord = buildAudit({
      fn: 'testFn',
      inputs: {},
      constants: {},
      citation: 'c',
      resultSummary: 'r',
      ctx: { clock: () => new Date(0) }, // 1970-01-01T00:00:00.000Z
    });
    expect(a.computed_at).toBe('1970-01-01T00:00:00.000Z');
    expect(a.computed_at).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
  });
});
