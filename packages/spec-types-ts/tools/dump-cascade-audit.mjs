// One-off dump tool: runs each cascade replay scenario through the
// compiled impl and prints { id, audit } JSON for hand-copying into
// the fixture files. Not part of the package.
import { fetchWeatherCascade } from '../dist/cascade.js';
import { canonicalJson } from '../dist/canonicalJson.js';

const FIXED_CLOCK = () => new Date('2026-05-26T17:00:00.000Z');

function buildReplay(responses) {
  return async (req) => {
    const match = responses.find((r) => new RegExp(r.url_pattern).test(req.url));
    if (!match) throw new Error(`no replay response for ${req.url}`);
    if (match.simulate === 'timeout') {
      // Replay-friendly timeout: throw synchronously so we don't wait 5s
      throw new Error('timeout');
    }
    const body =
      match.body_json !== undefined
        ? JSON.stringify(match.body_json)
        : match.body_text ?? '';
    return { status: match.status, body };
  };
}

const SCENARIOS = [
  {
    id: 'nws-success',
    description: 'NWS returns a valid observation on the first try.',
    input: { lat: 37.7749, lng: -122.4194 },
    responses: [
      {
        url_pattern: 'api\\.weather\\.gov/.*/observations/latest',
        status: 200,
        body_json: {
          properties: {
            temperature: { value: 22.5 },
            relativeHumidity: { value: 58 },
            windSpeed: { value: 3.1 },
          },
        },
      },
    ],
  },
  {
    id: 'nws-missing-falls-to-openmeteo',
    description: 'NWS returns 200 with null temperature; cascade falls to Open-Meteo.',
    input: { lat: 37.7749, lng: -122.4194 },
    responses: [
      {
        url_pattern: 'api\\.weather\\.gov/.*/observations/latest',
        status: 200,
        body_json: {
          properties: {
            temperature: { value: null },
            relativeHumidity: { value: 58 },
          },
        },
      },
      {
        url_pattern: 'api\\.open-meteo\\.com/.*',
        status: 200,
        body_json: {
          current: {
            temperature_2m: 21.8,
            relative_humidity_2m: 60,
            wind_speed_10m: 2.4,
          },
        },
      },
    ],
  },
  {
    id: 'both-fail-simulated',
    description: 'NWS HTTP 500 and Open-Meteo HTTP 500 — cascade returns the simulated fallback.',
    input: { lat: 37.7749, lng: -122.4194 },
    responses: [
      {
        url_pattern: 'api\\.weather\\.gov/.*/observations/latest',
        status: 500,
        body_text: 'internal server error',
      },
      {
        url_pattern: 'api\\.open-meteo\\.com/.*',
        status: 500,
        body_text: 'internal server error',
      },
    ],
  },
  {
    id: 'nws-http-500',
    description: 'NWS returns HTTP 500; cascade falls to Open-Meteo.',
    input: { lat: 37.7749, lng: -122.4194 },
    responses: [
      {
        url_pattern: 'api\\.weather\\.gov/.*/observations/latest',
        status: 500,
        body_text: 'internal server error',
      },
      {
        url_pattern: 'api\\.open-meteo\\.com/.*',
        status: 200,
        body_json: {
          current: {
            temperature_2m: 19.4,
            relative_humidity_2m: 72,
          },
        },
      },
    ],
  },
  {
    id: 'openmeteo-timeout',
    description: 'NWS missing fields then Open-Meteo times out — cascade falls to simulated.',
    input: { lat: 37.7749, lng: -122.4194 },
    responses: [
      {
        url_pattern: 'api\\.weather\\.gov/.*/observations/latest',
        status: 200,
        body_json: {
          properties: {
            temperature: { value: null },
            relativeHumidity: { value: 50 },
          },
        },
      },
      {
        url_pattern: 'api\\.open-meteo\\.com/.*',
        status: 200,
        simulate: 'timeout',
      },
    ],
  },
  {
    id: 'malformed-json',
    description: 'NWS returns 200 with malformed JSON; cascade falls to Open-Meteo.',
    input: { lat: 37.7749, lng: -122.4194 },
    responses: [
      {
        url_pattern: 'api\\.weather\\.gov/.*/observations/latest',
        status: 200,
        body_text: '{not valid json',
      },
      {
        url_pattern: 'api\\.open-meteo\\.com/.*',
        status: 200,
        body_json: {
          current: {
            temperature_2m: 18.2,
            relative_humidity_2m: 65,
          },
        },
      },
    ],
  },
];

for (const scenario of SCENARIOS) {
  const ctx = { clock: FIXED_CLOCK, httpAdapter: buildReplay(scenario.responses) };
  const { result, audit } = await fetchWeatherCascade(scenario.input, ctx);
  process.stdout.write(`=== ${scenario.id} ===\n`);
  process.stdout.write(`result: ${canonicalJson(result)}\n`);
  process.stdout.write(`audit: ${canonicalJson(audit)}\n`);
}
