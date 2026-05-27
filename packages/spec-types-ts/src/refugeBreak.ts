// USMC 6200.1E §3.2 work/rest matrix.
//
// Given the current environmental flag and the worker's acclimatization
// state, returns the prescribed per-hour work/rest interval. The matrix
// values are for *moderate work intensity* per the source document.
//
// Two flag/branch cells prescribe full work cessation: red/unacclim and
// black/unacclim. Both return { ceaseWork: true, workMinutes: 0, restMinutes: 0 }.
//
// `workMinutesRequested` is captured in the audit for traceability but
// does not change matrix selection — the ratios are per-hour and the
// supervisor schedules within them. Non-positive values get the
// 'non_positive_work_window' marker in the audit's result_summary.

import type { SpecContext, SpecReturn } from './audit.js';
import { buildAudit } from './audit.js';
import type {
  EnvironmentalFlag,
  RefugeBreakInput,
  WorkRestInterval,
} from './types.js';

const CITATION = 'USMC 6200.1E §3.2';

interface Cell {
  work: number;
  rest: number;
  reassess: number | null;
  cease: boolean;
}

const RATIOS: Record<EnvironmentalFlag, { acclim: Cell; unacclim: Cell }> = {
  white: {
    acclim: { work: 60, rest: 0, reassess: null, cease: false },
    unacclim: { work: 50, rest: 10, reassess: null, cease: false },
  },
  green: {
    acclim: { work: 50, rest: 10, reassess: null, cease: false },
    unacclim: { work: 40, rest: 20, reassess: null, cease: false },
  },
  yellow: {
    acclim: { work: 45, rest: 15, reassess: 6, cease: false },
    unacclim: { work: 30, rest: 30, reassess: 4, cease: false },
  },
  red: {
    acclim: { work: 30, rest: 30, reassess: 4, cease: false },
    unacclim: { work: 0, rest: 0, reassess: null, cease: true },
  },
  black: {
    acclim: { work: 10, rest: 50, reassess: 1, cease: false },
    unacclim: { work: 0, rest: 0, reassess: null, cease: true },
  },
};

const VALID_FLAGS: readonly EnvironmentalFlag[] = ['white', 'green', 'yellow', 'red', 'black'];

export function workRestForFlag(
  input: RefugeBreakInput,
  ctx?: SpecContext,
): SpecReturn<WorkRestInterval> {
  const { flag, acclimatized, workMinutesRequested } = input;

  if (!VALID_FLAGS.includes(flag)) {
    return {
      result: null,
      audit: buildAudit({
        fn: 'workRestForFlag',
        inputs: { flag: String(flag), acclimatized, workMinutesRequested },
        constants: {},
        citation: CITATION,
        resultSummary: 'invalid_input:flag',
        ctx,
      }),
    };
  }

  if (!Number.isFinite(workMinutesRequested)) {
    return {
      result: null,
      audit: buildAudit({
        fn: 'workRestForFlag',
        inputs: {
          flag,
          acclimatized,
          workMinutesRequested: Number.isNaN(workMinutesRequested) ? 'NaN' : workMinutesRequested,
        },
        constants: {},
        citation: CITATION,
        resultSummary: 'invalid_input:workMinutesRequested',
        ctx,
      }),
    };
  }

  const cell = acclimatized ? RATIOS[flag].acclim : RATIOS[flag].unacclim;
  const branch = acclimatized ? 'acclim' : 'unacclim';

  const result: WorkRestInterval = {
    workMinutes: cell.work,
    restMinutes: cell.rest,
    cyclesUntilReassessRequired: cell.reassess,
    ceaseWork: cell.cease,
  };

  const constants: Record<string, number> = {};
  if (!cell.cease) {
    constants[`${flag}_work_${branch}`] = cell.work;
    constants[`${flag}_rest_${branch}`] = cell.rest;
    if (cell.reassess !== null) {
      const reassessKey = acclimatized
        ? `${flag}_reassess_cycles`
        : `${flag}_reassess_cycles_unacclim`;
      constants[reassessKey] = cell.reassess;
    }
  }

  let summary: string;
  if (cell.cease) {
    summary = `${flag}/${branch} → cease_work`;
  } else if (cell.reassess === 1) {
    summary = `${flag}/${branch} → ${cell.work}w/${cell.rest}r, reassess every cycle`;
  } else if (cell.reassess !== null) {
    summary = `${flag}/${branch} → ${cell.work}w/${cell.rest}r, reassess after ${cell.reassess} cycles`;
  } else {
    summary = `${flag}/${branch} → ${cell.work}w/${cell.rest}r`;
  }
  if (workMinutesRequested <= 0) summary += ' (non_positive_work_window)';

  return {
    result,
    audit: buildAudit({
      fn: 'workRestForFlag',
      inputs: { flag, acclimatized, workMinutesRequested },
      constants,
      citation: CITATION,
      resultSummary: summary,
      ctx,
    }),
  };
}
