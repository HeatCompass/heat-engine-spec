import { describe, it, expect } from 'vitest';
import { loadCascadeFixtures } from '../src/fixtures.js';
import { fetchWeatherCascade } from '../src/cascade.js';
import { canonicalJson } from '../src/canonicalJson.js';
import type { HttpAdapter } from '../src/audit.js';
import type { CascadeReplayResponse } from '../src/types.js';

function buildReplayAdapter(responses: CascadeReplayResponse[]): HttpAdapter {
  return async (req) => {
    const match = responses.find((r) => new RegExp(r.url_pattern).test(req.url));
    if (!match) throw new Error(`no replay response for ${req.url}`);
    if (match.simulate === 'timeout') {
      throw new Error('timeout');
    }
    const body =
      match.body_json !== undefined
        ? JSON.stringify(match.body_json)
        : match.body_text ?? '';
    return { status: match.status, body };
  };
}

describe('cascade conformance against existing 6 replay fixtures', () => {
  const rows = loadCascadeFixtures();

  it('loads >= 6 rows', () => {
    expect(rows.length).toBeGreaterThanOrEqual(6);
  });

  for (const row of rows) {
    it(`${row.fileName}::${row.id}`, async () => {
      const ctx = {
        clock: () => new Date(row.ctx.clock_iso),
        httpAdapter: buildReplayAdapter(row.ctx.responses),
      };
      const { result, audit } = await fetchWeatherCascade(row.input, ctx);
      if (row.expectedResult === null) {
        expect(result).toBeNull();
      } else {
        expect(result).toEqual(row.expectedResult);
      }
      expect(canonicalJson(audit as unknown as Record<string, unknown>)).toBe(
        canonicalJson(row.expectedAudit),
      );
    });
  }
});

describe('cascade input forwarding', () => {
  it('passes isoTimestamp through to audit inputs when provided', async () => {
    const responses: CascadeReplayResponse[] = [
      {
        url_pattern: 'api\\.weather\\.gov/.*/observations/latest',
        status: 200,
        body_json: {
          properties: {
            temperature: { value: 25 },
            relativeHumidity: { value: 50 },
          },
        },
      },
    ];
    const ctx = {
      clock: () => new Date('2026-05-26T17:00:00.000Z'),
      httpAdapter: buildReplayAdapter(responses),
    };
    const { result, audit } = await fetchWeatherCascade(
      { lat: 1, lng: 2, isoTimestamp: '2026-05-26T16:00:00.000Z' },
      ctx,
    );
    expect(result?.sample.source).toBe('nws');
    expect(audit.inputs).toEqual({
      lat: 1,
      lng: 2,
      isoTimestamp: '2026-05-26T16:00:00.000Z',
    });
  });
});
