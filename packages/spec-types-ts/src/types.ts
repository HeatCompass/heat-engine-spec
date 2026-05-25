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
