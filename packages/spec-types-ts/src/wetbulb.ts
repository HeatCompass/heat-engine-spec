// Stull (2011) wet-bulb temperature reference implementation.
//
// Returns Approach B { result, audit }. The result carries wetBulbC +
// wetBulbF (a convenience conversion) and, when RH is clamped to the
// validity range, the clamped value. The audit captures the 6 Stull
// constants, the input pair (post-clamp displayed in the summary), and a
// human-readable result_summary that doubles as the OSHA-CSV cell.
//
// Validity range: RH in [5, 100], tempC in [-20, 50]. Outside the range,
// the function still returns a result, but the audit's result_summary
// includes the marker 'out_of_validity_range'. Never throws on numeric
// input; returns { result: null, audit: {...} } on NaN / non-finite.

import type { SpecContext, SpecReturn } from './audit.js';
import { buildAudit } from './audit.js';
import type { WetBulbInput, WetBulbOutput } from './types.js';

const STULL_A = 0.151977;
const STULL_B = 8.313659;
const STULL_C = 1.676331;
const STULL_D = 0.00391838;
const STULL_E = 0.023101;
const STULL_OFFSET = -4.686035;
const RH_CLAMP_MIN = 5;
const RH_CLAMP_MAX = 100;
const CITATION = 'Stull (2011) eq. 1';

// Result type widens WetBulbOutput with the optional clampedRhPct marker.
export type WetBulbResultPlus = WetBulbOutput & { clampedRhPct?: number };

export function calculateWetBulb(
  input: WetBulbInput,
  ctx?: SpecContext,
): SpecReturn<WetBulbResultPlus> {
  const { tempC, rhPercent } = input;

  if (!Number.isFinite(tempC) || !Number.isFinite(rhPercent)) {
    const badField = !Number.isFinite(tempC) ? 'tempC' : 'rhPercent';
    return {
      result: null,
      audit: buildAudit({
        fn: 'calculateWetBulb',
        inputs: encodeInputs(tempC, rhPercent),
        constants: {},
        citation: CITATION,
        resultSummary: `invalid_input:${badField}`,
        ctx,
      }),
    };
  }

  const clamped =
    rhPercent < RH_CLAMP_MIN ? RH_CLAMP_MIN : rhPercent > RH_CLAMP_MAX ? RH_CLAMP_MAX : rhPercent;
  const wasClamped = clamped !== rhPercent;
  const outOfValidity = tempC < -20 || tempC > 50;

  const term1 = tempC * Math.atan(STULL_A * Math.sqrt(clamped + STULL_B));
  const term2 = Math.atan(tempC + clamped);
  const term3 = Math.atan(clamped - STULL_C);
  const term4 = STULL_D * Math.pow(clamped, 1.5) * Math.atan(STULL_E * clamped);
  const wetBulbC = term1 + term2 - term3 + term4 + STULL_OFFSET;
  const wetBulbF = (wetBulbC * 9.0) / 5.0 + 32.0;

  const result: WetBulbResultPlus = { wetBulbC, wetBulbF };
  if (wasClamped) result.clampedRhPct = clamped;

  const constants: Record<string, number> = {
    stull_a: STULL_A,
    stull_b: STULL_B,
    stull_c: STULL_C,
    stull_d: STULL_D,
    stull_e: STULL_E,
    stull_offset: STULL_OFFSET,
  };
  if (wasClamped) {
    constants.rh_clamp_min = RH_CLAMP_MIN;
    constants.rh_clamp_max = RH_CLAMP_MAX;
  }

  const markers: string[] = [];
  if (wasClamped) markers.push('rh_clamped');
  if (outOfValidity) markers.push('out_of_validity_range');
  const markerStr = markers.length ? ` (${markers.join(',')})` : '';
  const rhDisplay = wasClamped ? `${formatNum(rhPercent)}→${formatNum(clamped)}%` : `${formatNum(clamped)}%`;
  const summary = `T=${tempC.toFixed(1)}°C RH=${rhDisplay}${markerStr} → Tw=${wetBulbC.toFixed(2)}°C`;

  return {
    result,
    audit: buildAudit({
      fn: 'calculateWetBulb',
      inputs: { tempC, rhPercent },
      constants,
      citation: CITATION,
      resultSummary: summary,
      ctx,
    }),
  };
}

// Convenience: bare F-in/F-out wrapper using the same audit envelope.
export function calculateWetBulbF(
  tempF: number,
  rhPercent: number,
  ctx?: SpecContext,
): SpecReturn<WetBulbResultPlus> {
  const tempC = ((tempF - 32) * 5) / 9;
  return calculateWetBulb({ tempC, rhPercent }, ctx);
}

export function fahrenheitToCelsius(tempF: number): number {
  return ((tempF - 32) * 5) / 9;
}

export function celsiusToFahrenheit(tempC: number): number {
  return (tempC * 9) / 5 + 32;
}

function encodeInputs(tempC: number, rhPercent: number): Record<string, unknown> {
  return {
    tempC: Number.isNaN(tempC) ? 'NaN' : tempC,
    rhPercent: Number.isNaN(rhPercent) ? 'NaN' : rhPercent,
  };
}

function formatNum(n: number): string {
  // Display rhPercent as an int when whole; mirrors Python/CSV format.
  return n === Math.trunc(n) ? String(Math.trunc(n)) : String(n);
}
