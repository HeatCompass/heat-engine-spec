// Verdict-promotion state machine.
//
// Resolves the go/delay/alternate decision from priorVerdict + priorFlag +
// currentFlag + hasAlternateAvailable. Five named rules in priority order:
//
//   1. FIRST_RUN_DEFAULT — priorVerdict null; black/red → delay, else go.
//   2. NO_CHANGE — currentFlag === priorFlag; verdict held.
//   3. ALTERNATE_AVAILABLE_AT_BLACK — currentFlag black + hasAlternateAvailable.
//   4. ESCALATE_TO_DELAY_ON_RED_OR_BLACK — currentFlag red or black.
//   5. DEESCALATE_TO_GO — catch-all (returned to white/green/yellow).
//
// Audit envelope records prior_flag, next_flag, promotion_rule alongside
// the usual fields. Constants are empty — the rule names are the carrier.

import type { SpecContext, SpecReturn } from './audit.js';
import { buildAudit } from './audit.js';
import type {
  EnvironmentalFlag,
  PromotionRule,
  Verdict,
  VerdictInput,
  VerdictResult,
} from './types.js';

const CITATION = 'heat-engine-spec design doc §2.5';

const SEVERITY: Record<EnvironmentalFlag, number> = {
  white: 0,
  green: 1,
  yellow: 2,
  red: 3,
  black: 4,
};

const VALID_FLAGS: readonly EnvironmentalFlag[] = ['white', 'green', 'yellow', 'red', 'black'];
const VALID_VERDICTS: readonly Verdict[] = ['go', 'delay', 'alternate'];

export function promoteVerdict(
  input: VerdictInput,
  ctx?: SpecContext,
): SpecReturn<VerdictResult> {
  const { priorVerdict, currentFlag, hasAlternateAvailable } = input;
  const priorFlag = input.priorFlag ?? null;

  if (!VALID_FLAGS.includes(currentFlag)) {
    return {
      result: null,
      audit: buildAudit({
        fn: 'promoteVerdict',
        inputs: encodeInputs(input),
        constants: {},
        citation: CITATION,
        resultSummary: 'invalid_input:currentFlag',
        ctx,
      }),
    };
  }
  if (priorVerdict !== null && !VALID_VERDICTS.includes(priorVerdict)) {
    return {
      result: null,
      audit: buildAudit({
        fn: 'promoteVerdict',
        inputs: encodeInputs(input),
        constants: {},
        citation: CITATION,
        resultSummary: 'invalid_input:priorVerdict',
        ctx,
      }),
    };
  }
  if (priorFlag !== null && !VALID_FLAGS.includes(priorFlag)) {
    return {
      result: null,
      audit: buildAudit({
        fn: 'promoteVerdict',
        inputs: encodeInputs(input),
        constants: {},
        citation: CITATION,
        resultSummary: 'invalid_input:priorFlag',
        ctx,
      }),
    };
  }

  let verdict: Verdict;
  let rule: PromotionRule;
  let changed: boolean;

  if (priorVerdict === null) {
    verdict = SEVERITY[currentFlag] >= SEVERITY.red ? 'delay' : 'go';
    rule = 'FIRST_RUN_DEFAULT';
    changed = false;
  } else if (priorFlag === currentFlag) {
    verdict = priorVerdict;
    rule = 'NO_CHANGE';
    changed = false;
  } else if (currentFlag === 'black' && hasAlternateAvailable) {
    verdict = 'alternate';
    rule = 'ALTERNATE_AVAILABLE_AT_BLACK';
    changed = priorVerdict !== verdict;
  } else if (SEVERITY[currentFlag] >= SEVERITY.red) {
    verdict = 'delay';
    rule = 'ESCALATE_TO_DELAY_ON_RED_OR_BLACK';
    changed = priorVerdict !== verdict;
  } else {
    verdict = 'go';
    rule = 'DEESCALATE_TO_GO';
    changed = priorVerdict !== verdict;
  }

  const result: VerdictResult = {
    verdict,
    changedFromPrior: changed,
    promotionRule: rule,
  };

  let summary: string;
  switch (rule) {
    case 'FIRST_RUN_DEFAULT':
      summary = `first run, ${currentFlag} → ${verdict}`;
      break;
    case 'NO_CHANGE':
      summary = `no_change, ${currentFlag} → ${verdict}${priorVerdict === 'delay' ? ' (held)' : ''}`;
      break;
    case 'ALTERNATE_AVAILABLE_AT_BLACK':
      summary = `${priorFlag} → ${currentFlag} + alternate → alternate`;
      break;
    case 'ESCALATE_TO_DELAY_ON_RED_OR_BLACK':
      summary = `${priorFlag} → ${currentFlag}, escalate to delay`;
      break;
    case 'DEESCALATE_TO_GO':
      summary = `${priorFlag} → ${currentFlag}, deescalate to go`;
      break;
  }

  return {
    result,
    audit: buildAudit({
      fn: 'promoteVerdict',
      inputs: {
        priorVerdict,
        priorFlag,
        currentFlag,
        hasAlternateAvailable,
      },
      constants: {},
      citation: CITATION,
      resultSummary: summary,
      ctx,
      extras: {
        prior_flag: priorFlag,
        next_flag: currentFlag,
        promotion_rule: rule,
      },
    }),
  };
}

function encodeInputs(input: VerdictInput): Record<string, unknown> {
  return {
    priorVerdict: input.priorVerdict,
    priorFlag: input.priorFlag ?? null,
    currentFlag: String(input.currentFlag),
    hasAlternateAvailable: input.hasAlternateAvailable,
  };
}
