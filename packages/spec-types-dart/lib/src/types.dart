/// Input to the Stull (2011) wet-bulb temperature formula.
///
/// `tempC` is dry-bulb air temperature in °C. Validated for [-20, 50].
/// `rhPercent` is relative humidity 0-100. Validated for [5, 99].
class WetBulbInput {
  const WetBulbInput({required this.tempC, required this.rhPercent});

  final double tempC;
  final double rhPercent;
}

/// Output of the Stull (2011) wet-bulb temperature formula.
class WetBulbOutput {
  const WetBulbOutput({required this.wetBulbC, this.wetBulbF});

  final double wetBulbC;
  final double? wetBulbF;
}

/// Input to USMC 6200.1E environmental-flag mapping.
class FlagMappingInput {
  const FlagMappingInput({required this.wetBulbF});

  final double wetBulbF;
}

/// USMC color-coded environmental flag (canonical TS vocabulary).
enum EnvironmentalFlag { white, green, yellow, red, black }

/// Severity-named equivalent used in HeatCompass Dart code.
enum HeatRiskLevelLabel { low, moderate, high, extreme, critical }

/// Output of USMC 6200.1E flag mapping.
class FlagMappingOutput {
  const FlagMappingOutput({required this.flag, required this.flagDartLabel});

  final EnvironmentalFlag flag;
  final HeatRiskLevelLabel flagDartLabel;
}

/// One row of `wet-bulb.fixtures.csv`.
class WetBulbFixtureRow {
  const WetBulbFixtureRow({
    required this.id,
    required this.sourceRef,
    required this.tempC,
    required this.rhPercent,
    required this.expectedWetBulbC,
    required this.expectedWetBulbF,
    required this.toleranceC,
    required this.notes,
  });

  final String id;
  final String sourceRef;
  final double tempC;
  final double rhPercent;
  final double expectedWetBulbC;
  final double expectedWetBulbF;
  final double toleranceC;
  final String notes;
}

/// One row of `flag-mapping.fixtures.csv`.
class FlagMappingFixtureRow {
  const FlagMappingFixtureRow({
    required this.id,
    required this.sourceRef,
    required this.wetBulbF,
    required this.expectedFlag,
    required this.expectedFlagDartLabel,
    required this.notes,
  });

  final String id;
  final String sourceRef;
  final double wetBulbF;
  final EnvironmentalFlag expectedFlag;
  final HeatRiskLevelLabel expectedFlagDartLabel;
  final String notes;
}

/// Input to USMC 6200.1E §3.2 work/rest matrix lookup.
class RefugeBreakInput {
  const RefugeBreakInput({
    required this.flag,
    required this.acclimatized,
    required this.workMinutesRequested,
  });

  final EnvironmentalFlag flag;
  final bool acclimatized;
  final int workMinutesRequested;
}

/// Prescribed work/rest interval per hour per USMC 6200.1E §3.2.
class WorkRestInterval {
  const WorkRestInterval({
    required this.workMinutes,
    required this.restMinutes,
    required this.cyclesUntilReassessRequired,
    required this.ceaseWork,
  });

  final int workMinutes;
  final int restMinutes;
  final int? cyclesUntilReassessRequired;
  final bool ceaseWork;
}

/// One row of `refuge-break.fixtures.csv`.
class RefugeBreakFixtureRow {
  const RefugeBreakFixtureRow({
    required this.id,
    required this.sourceRef,
    required this.flag,
    required this.acclimatized,
    required this.workMinutesRequested,
    required this.expectedWorkMinutes,
    required this.expectedRestMinutes,
    required this.expectedCyclesUntilReassessRequired,
    required this.expectedCeaseWork,
    required this.notes,
  });

  final String id;
  final String sourceRef;
  final EnvironmentalFlag flag;
  final bool acclimatized;
  final int workMinutesRequested;
  final int expectedWorkMinutes;
  final int expectedRestMinutes;
  final int? expectedCyclesUntilReassessRequired;
  final bool expectedCeaseWork;
  final String notes;
}

EnvironmentalFlag parseEnvironmentalFlag(String s) {
  switch (s) {
    case 'white':
      return EnvironmentalFlag.white;
    case 'green':
      return EnvironmentalFlag.green;
    case 'yellow':
      return EnvironmentalFlag.yellow;
    case 'red':
      return EnvironmentalFlag.red;
    case 'black':
      return EnvironmentalFlag.black;
    default:
      throw ArgumentError('Unknown EnvironmentalFlag: "$s"');
  }
}

HeatRiskLevelLabel parseHeatRiskLevelLabel(String s) {
  switch (s) {
    case 'low':
      return HeatRiskLevelLabel.low;
    case 'moderate':
      return HeatRiskLevelLabel.moderate;
    case 'high':
      return HeatRiskLevelLabel.high;
    case 'extreme':
      return HeatRiskLevelLabel.extreme;
    case 'critical':
      return HeatRiskLevelLabel.critical;
    default:
      throw ArgumentError('Unknown HeatRiskLevelLabel: "$s"');
  }
}
