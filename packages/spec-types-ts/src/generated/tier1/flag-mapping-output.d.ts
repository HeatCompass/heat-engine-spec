/* DO NOT EDIT. Generated from spec/tier1-foundation/flag-mapping-output.schema.json by scripts/generate-types.sh */

/**
 * USMC 6200.1E environmental-flag classification. Both flag vocabularies are valid surface labels for the same canonical class.
 */
export interface FlagMappingOutput {
  /**
   * USMC color-coded flag (TS-side vocabulary).
   */
  flag: "white" | "green" | "yellow" | "red" | "black";
  /**
   * Severity-named equivalent (HeatCompass Dart-side vocabulary).
   */
  flagDartLabel: "low" | "moderate" | "high" | "extreme" | "critical";
}
