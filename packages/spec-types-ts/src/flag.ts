// USMC 6200.1E environmental-flag mapping.
//
// Returns Approach B { result, audit } where result is the existing
// FlagMappingOutput shape — { flag, flagDartLabel } — so callers in both
// the HeatCompass Console (uses 'flag') and the consumer app (uses
// 'flagDartLabel') can drop in without translation.
//
// Bands defined in °F per USMC primary source: white < 80, green [80, 85),
// yellow [85, 88), red [88, 90), black ≥ 90.

import type { SpecContext, SpecReturn } from './audit.js';
import { buildAudit } from './audit.js';
import type {
  EnvironmentalFlag,
  FlagMappingInput,
  FlagMappingOutput,
  HeatRiskLevelLabel,
} from './types.js';
import { celsiusToFahrenheit } from './wetbulb.js';

const WHITE_MAX = 80;
const GREEN_MAX = 85;
const YELLOW_MAX = 88;
const RED_MAX = 90;
const OBSERVED_MIN = -50; // negative wetBulbF physically possible only in extreme arctic
const OBSERVED_MAX = 200;
const CITATION = 'USMC 6200.1E Table 3-1';

const FLAG_TO_DART_LABEL: Record<EnvironmentalFlag, HeatRiskLevelLabel> = {
  white: 'low',
  green: 'moderate',
  yellow: 'high',
  red: 'extreme',
  black: 'critical',
};

export function flagFromWetBulbF(
  inputOrValue: FlagMappingInput | number,
  ctx?: SpecContext,
): SpecReturn<FlagMappingOutput> {
  const wetBulbF =
    typeof inputOrValue === 'number' ? inputOrValue : inputOrValue.wetBulbF;

  if (!Number.isFinite(wetBulbF)) {
    return {
      result: null,
      audit: buildAudit({
        fn: 'flagFromWetBulbF',
        inputs: { wetBulbF: Number.isNaN(wetBulbF) ? 'NaN' : wetBulbF },
        constants: {},
        citation: CITATION,
        resultSummary: 'invalid_input:wetBulbF',
        ctx,
      }),
    };
  }

  const flag = bandFor(wetBulbF);
  const flagDartLabel = FLAG_TO_DART_LABEL[flag];
  const outOfObservedRange = wetBulbF < OBSERVED_MIN || wetBulbF > OBSERVED_MAX;
  const markerStr = outOfObservedRange ? ' (out_of_observed_range)' : '';

  return {
    result: { flag, flagDartLabel },
    audit: buildAudit({
      fn: 'flagFromWetBulbF',
      inputs: { wetBulbF },
      constants: {
        white_max: WHITE_MAX,
        green_max: GREEN_MAX,
        yellow_max: YELLOW_MAX,
        red_max: RED_MAX,
      },
      citation: CITATION,
      resultSummary: `wetBulbF=${formatNum(wetBulbF)} → ${flag}${markerStr}`,
      ctx,
    }),
  };
}

/// Convenience: degrees-Celsius wrapper. Internally converts to °F (via
/// celsiusToFahrenheit) then calls flagFromWetBulbF. Nests the inner audit
/// as a child so the conversion step is recorded.
export function flagFromWetBulbC(
  wetBulbC: number,
  ctx?: SpecContext,
): SpecReturn<FlagMappingOutput> {
  if (!Number.isFinite(wetBulbC)) {
    return {
      result: null,
      audit: buildAudit({
        fn: 'flagFromWetBulbC',
        inputs: { wetBulbC: Number.isNaN(wetBulbC) ? 'NaN' : wetBulbC },
        constants: {},
        citation: CITATION,
        resultSummary: 'invalid_input:wetBulbC',
        ctx,
      }),
    };
  }
  const wetBulbF = celsiusToFahrenheit(wetBulbC);
  const inner = flagFromWetBulbF(wetBulbF, ctx);
  return {
    result: inner.result,
    audit: buildAudit({
      fn: 'flagFromWetBulbC',
      inputs: { wetBulbC },
      constants: {
        white_max: WHITE_MAX,
        green_max: GREEN_MAX,
        yellow_max: YELLOW_MAX,
        red_max: RED_MAX,
      },
      citation: CITATION,
      resultSummary: `wetBulbC=${formatNum(wetBulbC)} → wetBulbF=${wetBulbF.toFixed(4)} → ${inner.result?.flag ?? 'null'}`,
      ctx,
      extras: { children: [inner.audit] },
    }),
  };
}

function bandFor(wetBulbF: number): EnvironmentalFlag {
  if (wetBulbF < WHITE_MAX) return 'white';
  if (wetBulbF < GREEN_MAX) return 'green';
  if (wetBulbF < YELLOW_MAX) return 'yellow';
  if (wetBulbF < RED_MAX) return 'red';
  return 'black';
}

function formatNum(n: number): string {
  return n === Math.trunc(n) ? String(Math.trunc(n)) : String(n);
}
