// Approach B audit envelope types + builder helper.
//
// Every primary spec function (calculateWetBulb, flagFromWetBulbF,
// workRestForFlag, fetchWeatherCascade, promoteVerdict) returns
// `{ result, audit }` where `audit` conforms to AuditRecord (which mirrors
// spec/tier1-foundation/audit.schema.json).
//
// `buildAudit` is the single allocation point: it stamps spec_version
// (from specVersion.ts) and computed_at (from the SpecContext clock,
// defaulting to `new Date()`). This keeps the audit shape consistent
// across every callsite.

import { SPEC_VERSION } from './specVersion.js';
import type { EnvironmentalFlag } from './types.js';

export type WeatherSource = 'nws' | 'open-meteo' | 'simulated';

export type SourceAttempt = {
  source: WeatherSource;
  status: 'ok' | 'error' | 'timeout';
  duration_ms: number;
  error?: string;
};

export type AuditRecord = {
  spec_version: string;
  function: string;
  inputs: Record<string, unknown>;
  constants: Record<string, number>;
  citation: string;
  result_summary: string;
  computed_at: string; // ISO 8601 with .000Z millisecond precision
  children?: AuditRecord[];
  // cascade-only:
  source_chain?: WeatherSource[];
  sources_tried?: SourceAttempt[];
  fallback_reason?: string;
  // verdict-only:
  prior_flag?: EnvironmentalFlag | null;
  next_flag?: EnvironmentalFlag;
  promotion_rule?: string;
};

export type HttpAdapter = (req: {
  url: string;
  method?: 'GET' | 'POST';
  headers?: Record<string, string>;
  body?: string;
  timeoutMs?: number;
}) => Promise<{ status: number; body: string }>;

export type SpecContext = {
  clock?: () => Date;
  httpAdapter?: HttpAdapter; // cascade only
};

export type SpecReturn<T> = { result: T | null; audit: AuditRecord };

/**
 * A numeric input as an audit records it. JSON has no NaN or Infinity, so
 * those are written as the strings "NaN", "Infinity" and "-Infinity", the
 * same text the Dart implementation writes. (Infinity used to reach the
 * serializer as a number and come out as null.)
 */
export function auditNumber(n: number): number | string {
  return Number.isFinite(n) ? n : String(n);
}

export function buildAudit(args: {
  fn: string;
  inputs: Record<string, unknown>;
  constants: Record<string, number>;
  citation: string;
  resultSummary: string;
  ctx?: SpecContext;
  extras?: Partial<AuditRecord>;
}): AuditRecord {
  const clock = args.ctx?.clock ?? (() => new Date());
  const now = clock();
  const base: AuditRecord = {
    spec_version: SPEC_VERSION,
    function: args.fn,
    inputs: args.inputs,
    constants: args.constants,
    citation: args.citation,
    result_summary: args.resultSummary,
    computed_at: toIsoUtcMillis(now),
  };
  if (args.extras) Object.assign(base, args.extras);
  return base;
}

// Force the `.000Z` form even when ms component is 0 — keeps the pattern
// regex in audit.schema.json happy and cross-lang byte-equal with Dart.
function toIsoUtcMillis(d: Date): string {
  const iso = d.toISOString(); // already 'YYYY-MM-DDTHH:mm:ss.sssZ'
  return iso;
}
