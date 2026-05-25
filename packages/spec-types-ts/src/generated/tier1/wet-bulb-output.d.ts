/* DO NOT EDIT. Generated from spec/tier1-foundation/wet-bulb-output.schema.json by scripts/generate-types.sh */

/**
 * Output of the Stull (2011) wet-bulb temperature formula.
 */
export interface WetBulbOutput {
  /**
   * Wet-bulb temperature in degrees Celsius.
   */
  wetBulbC: number;
  /**
   * Same value converted to degrees Fahrenheit (convenience only; derived from wetBulbC).
   */
  wetBulbF?: number;
}
