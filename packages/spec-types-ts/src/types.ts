// Public types for the heat-engine-spec tier 1.
// Re-exports generated schema types AND defines fixture row types.

export type { WetBulbInput } from './generated/tier1/wet-bulb-input.js';
export type { WetBulbOutput } from './generated/tier1/wet-bulb-output.js';
export type { FlagMappingInput } from './generated/tier1/flag-mapping-input.js';
export type { FlagMappingOutput } from './generated/tier1/flag-mapping-output.js';

export interface WetBulbFixtureRow {
  id: string;
  sourceRef: string;
  tempC: number;
  rhPercent: number;
  expectedWetBulbC: number;
  expectedWetBulbF: number;
  toleranceC: number;
  notes: string;
}

export type EnvironmentalFlag = 'white' | 'green' | 'yellow' | 'red' | 'black';
export type HeatRiskLevelLabel = 'low' | 'moderate' | 'high' | 'extreme' | 'critical';

export interface FlagMappingFixtureRow {
  id: string;
  sourceRef: string;
  wetBulbF: number;
  expectedFlag: EnvironmentalFlag;
  expectedFlagDartLabel: HeatRiskLevelLabel;
  notes: string;
}

export interface RefugeBreakInput {
  flag: EnvironmentalFlag;
  acclimatized: boolean;
  workMinutesRequested: number;
}

export interface WorkRestInterval {
  workMinutes: number;
  restMinutes: number;
  cyclesUntilReassessRequired: number | null;
  ceaseWork: boolean;
}

export interface RefugeBreakFixtureRow {
  id: string;
  sourceRef: string;
  flag: EnvironmentalFlag;
  acclimatized: boolean;
  workMinutesRequested: number;
  expectedWorkMinutes: number;
  expectedRestMinutes: number;
  expectedCyclesUntilReassessRequired: number | null;
  expectedCeaseWork: boolean;
  notes: string;
}

export type Verdict = 'go' | 'delay' | 'alternate';

export type PromotionRule =
  | 'FIRST_RUN_DEFAULT'
  | 'NO_CHANGE'
  | 'ESCALATE_TO_DELAY_ON_RED_OR_BLACK'
  | 'ALTERNATE_AVAILABLE_AT_BLACK'
  | 'DEESCALATE_TO_GO';

export interface VerdictInput {
  priorVerdict: Verdict | null;
  priorFlag?: EnvironmentalFlag | null;
  currentFlag: EnvironmentalFlag;
  hasAlternateAvailable: boolean;
}

export interface VerdictResult {
  verdict: Verdict;
  changedFromPrior: boolean;
  promotionRule: PromotionRule;
}

export interface VerdictFixtureRow {
  id: string;
  sourceRef: string;
  priorVerdict: Verdict | null;
  priorFlag: EnvironmentalFlag | null;
  currentFlag: EnvironmentalFlag;
  hasAlternateAvailable: boolean;
  expectedVerdict: Verdict;
  expectedChangedFromPrior: boolean;
  expectedPromotionRule: PromotionRule;
  notes: string;
}

export interface CascadeRequest {
  lat: number;
  lng: number;
  isoTimestamp?: string;
}

export interface WeatherSample {
  tempC: number;
  rhPercent: number;
  windMps?: number;
  source: 'nws' | 'open-meteo' | 'simulated';
}

export interface CascadeResult {
  sample: WeatherSample;
}

export interface CascadeReplayResponse {
  url_pattern: string;
  status: number;
  body_json?: unknown;
  body_text?: string;
  simulate?: 'timeout';
}

export interface CascadeFixtureRow {
  id: string;
  description: string;
  input: CascadeRequest;
  ctx: {
    clock_iso: string;
    responses: CascadeReplayResponse[];
  };
  expectedResult: CascadeResult | null;
  expectedAudit: Record<string, unknown>;
  fileName: string;
}
