// Weather-source cascade: NWS → Open-Meteo → simulated.
//
// Each tier is attempted in turn. A source "fails" by HTTP status >= 400,
// missing fields in the response body, JSON parse error, or timeout. On
// fall-through, the failed attempt is recorded as a child audit and a
// SourceAttempt row, and the next tier is attempted.
//
// If both live sources fail, the deterministic simulated sample is
// returned: { tempC: 20, rhPercent: 50, source: 'simulated' }.
//
// HttpAdapter is injectable via SpecContext.httpAdapter (defaults to a
// native fetch wrapper). Tests inject a replay adapter that walks
// ctx.responses[] and serves the first url_pattern match.

import type { SpecContext, SpecReturn, HttpAdapter, SourceAttempt, AuditRecord, WeatherSource } from './audit.js';
import { buildAudit } from './audit.js';
import type { CascadeRequest, CascadeResult, WeatherSample } from './types.js';

const CITATION = 'Cascade order: NWS → Open-Meteo → simulated';
const NWS_CITATION = 'api.weather.gov';
const OPEN_METEO_CITATION = 'api.open-meteo.com';
const NWS_TIMEOUT_MS = 5000;
const OPEN_METEO_TIMEOUT_MS = 5000;
const SIMULATED_TEMP_C = 20;
const SIMULATED_RH_PERCENT = 50;

const SIMULATED_SAMPLE: WeatherSample = {
  tempC: SIMULATED_TEMP_C,
  rhPercent: SIMULATED_RH_PERCENT,
  source: 'simulated',
};

const nativeFetchAdapter: HttpAdapter = async (req) => {
  const ctrl = new AbortController();
  const timeout = setTimeout(() => ctrl.abort(), req.timeoutMs ?? 5000);
  try {
    const res = await fetch(req.url, {
      method: req.method ?? 'GET',
      headers: req.headers,
      body: req.body,
      signal: ctrl.signal,
    });
    return { status: res.status, body: await res.text() };
  } finally {
    clearTimeout(timeout);
  }
};

export async function fetchWeatherCascade(
  req: CascadeRequest,
  ctx?: SpecContext,
): Promise<SpecReturn<CascadeResult>> {
  const adapter = ctx?.httpAdapter ?? nativeFetchAdapter;
  const sourceChain: WeatherSource[] = [];
  const sourcesTried: SourceAttempt[] = [];
  const children: AuditRecord[] = [];

  // Tier 1: NWS
  sourceChain.push('nws');
  const nws = await tryNws(req, adapter, ctx);
  sourcesTried.push(nws.attempt);
  children.push(nws.audit);
  if (nws.sample) {
    return finalize(req, nws.sample, sourceChain, sourcesTried, children, undefined, ctx);
  }

  // Tier 2: Open-Meteo
  sourceChain.push('open-meteo');
  const om = await tryOpenMeteo(req, adapter, ctx);
  sourcesTried.push(om.attempt);
  children.push(om.audit);
  if (om.sample) {
    return finalize(
      req,
      om.sample,
      sourceChain,
      sourcesTried,
      children,
      describeFallback(nws.attempt),
      ctx,
    );
  }

  // Tier 3: simulated
  sourceChain.push('simulated');
  return finalize(
    req,
    SIMULATED_SAMPLE,
    sourceChain,
    sourcesTried,
    children,
    'all_live_sources_failed',
    ctx,
  );
}

function finalize(
  req: CascadeRequest,
  sample: WeatherSample,
  sourceChain: WeatherSource[],
  sourcesTried: SourceAttempt[],
  children: AuditRecord[],
  fallbackReason: string | undefined,
  ctx: SpecContext | undefined,
): SpecReturn<CascadeResult> {
  const isSimulated = sample.source === 'simulated';
  const constants: Record<string, number> = {
    nws_timeout_ms: NWS_TIMEOUT_MS,
    open_meteo_timeout_ms: OPEN_METEO_TIMEOUT_MS,
  };
  if (isSimulated) {
    constants.simulated_temp_c = SIMULATED_TEMP_C;
    constants.simulated_rh_percent = SIMULATED_RH_PERCENT;
  }

  let summary: string;
  if (sample.source === 'nws') {
    summary = `cascade → nws OK (tempC=${formatNum(sample.tempC)}, rhPercent=${formatNum(sample.rhPercent)})`;
  } else if (sample.source === 'open-meteo') {
    summary = `cascade → open-meteo OK (tempC=${formatNum(sample.tempC)}, rhPercent=${formatNum(sample.rhPercent)}) after ${describeFallback(sourcesTried[0]!)}`;
  } else {
    summary = `cascade → simulated (all_live_sources_failed)`;
  }

  const extras: Partial<AuditRecord> = {
    source_chain: sourceChain,
    sources_tried: sourcesTried,
    children,
  };
  if (fallbackReason !== undefined) extras.fallback_reason = fallbackReason;

  return {
    result: { sample },
    audit: buildAudit({
      fn: 'fetchWeatherCascade',
      inputs: encodeInputs(req),
      constants,
      citation: CITATION,
      resultSummary: summary,
      ctx,
      extras,
    }),
  };
}

function describeFallback(attempt: SourceAttempt): string {
  if (attempt.status === 'timeout') return 'nws timeout';
  if (attempt.status === 'error') {
    if (attempt.error?.startsWith('missing_field:')) return 'nws missing fields';
    if (attempt.error?.startsWith('http_')) return `nws ${attempt.error}`;
    return `nws ${attempt.error ?? 'error'}`;
  }
  return 'nws ok';
}

interface SourceTry {
  sample: WeatherSample | null;
  attempt: SourceAttempt;
  audit: AuditRecord;
}

async function tryNws(req: CascadeRequest, adapter: HttpAdapter, ctx: SpecContext | undefined): Promise<SourceTry> {
  const url = `https://api.weather.gov/points/${req.lat},${req.lng}/observations/latest`;
  return tryFetch('nws', url, NWS_TIMEOUT_MS, NWS_CITATION, adapter, parseNws, req, ctx);
}

async function tryOpenMeteo(req: CascadeRequest, adapter: HttpAdapter, ctx: SpecContext | undefined): Promise<SourceTry> {
  const url = `https://api.open-meteo.com/v1/forecast?latitude=${req.lat}&longitude=${req.lng}&current=temperature_2m,relative_humidity_2m,wind_speed_10m`;
  return tryFetch('open-meteo', url, OPEN_METEO_TIMEOUT_MS, OPEN_METEO_CITATION, adapter, parseOpenMeteo, req, ctx);
}

async function tryFetch(
  source: WeatherSource,
  url: string,
  timeoutMs: number,
  citation: string,
  adapter: HttpAdapter,
  parser: (body: unknown) => WeatherSample | { error: string },
  req: CascadeRequest,
  ctx: SpecContext | undefined,
): Promise<SourceTry> {
  let attempt: SourceAttempt = { source, status: 'ok', duration_ms: 0 };
  let sample: WeatherSample | null = null;
  let summary = `${source} OK in 0ms`;

  try {
    const res = await adapter({ url, timeoutMs });
    if (res.status >= 400) {
      attempt = { source, status: 'error', duration_ms: 0, error: `http_${res.status}` };
      summary = `${source} http_${res.status}`;
    } else {
      let parsed: unknown = null;
      let parseFailed = false;
      try {
        parsed = JSON.parse(res.body);
      } catch {
        parseFailed = true;
        attempt = { source, status: 'error', duration_ms: 0, error: 'parse_error' };
        summary = `${source} parse_error`;
      }
      if (!parseFailed) {
        const out = parser(parsed);
        if ('error' in out) {
          attempt = { source, status: 'error', duration_ms: 0, error: out.error };
          summary = `${source} ${out.error}`;
        } else {
          sample = out;
          attempt = { source, status: 'ok', duration_ms: 0 };
          summary = `${source} OK in 0ms`;
        }
      }
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (msg === 'timeout' || msg.toLowerCase().includes('abort')) {
      attempt = { source, status: 'timeout', duration_ms: timeoutMs, error: 'timeout' };
      summary = `${source} timeout`;
    } else {
      attempt = { source, status: 'error', duration_ms: 0, error: msg };
      summary = `${source} ${msg}`;
    }
  }

  const constants: Record<string, number> =
    source === 'nws'
      ? { nws_timeout_ms: NWS_TIMEOUT_MS }
      : { open_meteo_timeout_ms: OPEN_METEO_TIMEOUT_MS };

  const audit = buildAudit({
    fn: `fetchWeatherCascade.${source}`,
    inputs: encodeInputs(req),
    constants,
    citation,
    resultSummary: summary,
    ctx,
  });

  return { sample, attempt, audit };
}

interface NwsBody {
  properties?: {
    temperature?: { value: number | null };
    relativeHumidity?: { value: number | null };
    windSpeed?: { value: number | null };
  };
}

function parseNws(body: unknown): WeatherSample | { error: string } {
  const b = body as NwsBody;
  const t = b?.properties?.temperature?.value;
  const rh = b?.properties?.relativeHumidity?.value;
  if (t === null || t === undefined) return { error: 'missing_field:temperature' };
  if (rh === null || rh === undefined) return { error: 'missing_field:relativeHumidity' };
  const ws = b?.properties?.windSpeed?.value;
  const sample: WeatherSample = { tempC: t, rhPercent: rh, source: 'nws' };
  if (ws !== null && ws !== undefined) sample.windMps = ws;
  return sample;
}

interface OpenMeteoBody {
  current?: {
    temperature_2m?: number;
    relative_humidity_2m?: number;
    wind_speed_10m?: number;
  };
}

function parseOpenMeteo(body: unknown): WeatherSample | { error: string } {
  const b = body as OpenMeteoBody;
  const t = b?.current?.temperature_2m;
  const rh = b?.current?.relative_humidity_2m;
  if (t === undefined) return { error: 'missing_field:temperature_2m' };
  if (rh === undefined) return { error: 'missing_field:relative_humidity_2m' };
  const ws = b?.current?.wind_speed_10m;
  const sample: WeatherSample = { tempC: t, rhPercent: rh, source: 'open-meteo' };
  if (ws !== undefined) sample.windMps = ws;
  return sample;
}

function encodeInputs(req: CascadeRequest): Record<string, unknown> {
  const out: Record<string, unknown> = { lat: req.lat, lng: req.lng };
  if (req.isoTimestamp !== undefined) out.isoTimestamp = req.isoTimestamp;
  return out;
}

function formatNum(n: number): string {
  return n === Math.trunc(n) ? String(Math.trunc(n)) : String(n);
}
