/* DO NOT EDIT. Generated from spec/tier1-foundation/wet-bulb-input.schema.json by scripts/generate-types.sh */

/**
 * Input to the Stull (2011) wet-bulb temperature formula.
 */
export interface WetBulbInput {
  /**
   * Dry-bulb air temperature in degrees Celsius. Stull (2011) is validated for [-20, 50].
   */
  tempC: number;
  /**
   * Relative humidity in percent. Stull (2011) is validated for [5, 99]; implementations MUST clamp inputs to [5, 100] and report a clamped value as clampedRhPct. RH in (99, 100] is computed as given, since 100 % is a real humidity.
   */
  rhPercent: number;
}
