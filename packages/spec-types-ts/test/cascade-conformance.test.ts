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

// The first two NWS requests (point metadata, then its observation stations),
// as the replay fixtures give them.
const NWS_POINT_AND_STATIONS: CascadeReplayResponse[] = [
  {
    url_pattern: 'api\\.weather\\.gov/points/',
    status: 200,
    body_json: { properties: { observationStations: 'https://api.weather.gov/gridpoints/MTR/85,105/stations' } },
  },
  {
    url_pattern: 'api\\.weather\\.gov/gridpoints/.*/stations$',
    status: 200,
    body_json: { features: [{ properties: { stationIdentifier: 'SFOC1' } }] },
  },
];

describe('cascade input forwarding', () => {
  it('passes isoTimestamp through to audit inputs when provided', async () => {
    const responses: CascadeReplayResponse[] = [
      ...NWS_POINT_AND_STATIONS,
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

describe('NWS request flow (points → stations → latest observation)', () => {
  const observation: CascadeReplayResponse = {
    url_pattern: 'api\\.weather\\.gov/stations/[^/]+/observations/latest$',
    status: 200,
    body_json: { properties: { temperature: { value: 25 }, relativeHumidity: { value: 50 } } },
  };
  const ctxWith = (responses: CascadeReplayResponse[], seen: { url: string; headers?: Record<string, string> }[] = []) => ({
    clock: () => new Date('2026-05-26T17:00:00.000Z'),
    httpAdapter: (async (req) => {
      seen.push({ url: req.url, headers: req.headers });
      return buildReplayAdapter(responses)(req);
    }) as HttpAdapter,
  });

  it('asks for the point, then its stations, then the first station\'s latest observation', async () => {
    const seen: { url: string; headers?: Record<string, string> }[] = [];
    const { result } = await fetchWeatherCascade({ lat: 37.7749, lng: -122.4194 }, ctxWith([...NWS_POINT_AND_STATIONS, observation], seen));
    expect(result?.sample.source).toBe('nws');
    expect(seen.map((r) => r.url)).toEqual([
      'https://api.weather.gov/points/37.7749,-122.4194',
      'https://api.weather.gov/gridpoints/MTR/85,105/stations',
      'https://api.weather.gov/stations/SFOC1/observations/latest',
    ]);
    // NWS answers 403 to requests without a User-Agent.
    for (const r of seen) expect(r.headers?.['User-Agent']).toMatch(/heat-engine-spec/);
  });

  it('a point without observationStations fails the NWS tier', async () => {
    const responses: CascadeReplayResponse[] = [
      { url_pattern: 'api\\.weather\\.gov/points/', status: 200, body_json: { properties: {} } },
    ];
    const { audit } = await fetchWeatherCascade({ lat: 1, lng: 2 }, ctxWith(responses));
    expect(audit.sources_tried?.[0]).toEqual({
      source: 'nws',
      status: 'error',
      duration_ms: 0,
      error: 'missing_field:observationStations',
    });
  });

  it('an empty station list fails the NWS tier', async () => {
    const responses: CascadeReplayResponse[] = [
      NWS_POINT_AND_STATIONS[0]!,
      { url_pattern: 'api\\.weather\\.gov/gridpoints/', status: 200, body_json: { features: [] } },
    ];
    const { audit } = await fetchWeatherCascade({ lat: 1, lng: 2 }, ctxWith(responses));
    expect(audit.sources_tried?.[0]?.error).toBe('missing_field:stationIdentifier');
  });

  it('an HTTP error on the point request is that tier\'s error', async () => {
    const responses: CascadeReplayResponse[] = [
      { url_pattern: 'api\\.weather\\.gov/points/', status: 404, body_text: 'not found' },
    ];
    const { audit } = await fetchWeatherCascade({ lat: 1, lng: 2 }, ctxWith(responses));
    expect(audit.sources_tried?.[0]?.error).toBe('http_404');
  });
});
