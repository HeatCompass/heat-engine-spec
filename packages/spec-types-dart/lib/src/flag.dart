// USMC 6200.1E environmental-flag mapping.
//
// Returns Approach B SpecReturn<FlagMappingOutput> where result is the
// existing { flag, flagDartLabel } shape so callers in both the HeatCompass
// Console (uses 'flag') and the consumer app (uses 'flagDartLabel') can
// drop in without translation.
//
// Bands defined in °F per USMC primary source: white < 80, green [80, 85),
// yellow [85, 88), red [88, 90), black ≥ 90.

import 'audit.dart';
import 'types.dart';
import 'wetbulb.dart' show celsiusToFahrenheit;

const double _whiteMax = 80;
const double _greenMax = 85;
const double _yellowMax = 88;
const double _redMax = 90;
const double _observedMin = -50;
const double _observedMax = 200;
const String _citation = 'USMC 6200.1E Table 3-1';

const Map<EnvironmentalFlag, HeatRiskLevelLabel> _flagToDartLabel = {
  EnvironmentalFlag.white: HeatRiskLevelLabel.low,
  EnvironmentalFlag.green: HeatRiskLevelLabel.moderate,
  EnvironmentalFlag.yellow: HeatRiskLevelLabel.high,
  EnvironmentalFlag.red: HeatRiskLevelLabel.extreme,
  EnvironmentalFlag.black: HeatRiskLevelLabel.critical,
};

SpecReturn<FlagMappingOutput> flagFromWetBulbF(
  double wetBulbF, [
  SpecContext? ctx,
]) {
  if (wetBulbF.isNaN || wetBulbF.isInfinite) {
    return SpecReturn(
      result: null,
      audit: buildAudit(
        fn: 'flagFromWetBulbF',
        inputs: {'wetBulbF': wetBulbF.isNaN ? 'NaN' : wetBulbF},
        constants: {},
        citation: _citation,
        resultSummary: 'invalid_input:wetBulbF',
        ctx: ctx,
      ),
    );
  }

  final flag = _bandFor(wetBulbF);
  final dartLabel = _flagToDartLabel[flag]!;
  final outOfObservedRange = wetBulbF < _observedMin || wetBulbF > _observedMax;
  final markerStr = outOfObservedRange ? ' (out_of_observed_range)' : '';

  return SpecReturn(
    result: FlagMappingOutput(flag: flag, flagDartLabel: dartLabel),
    audit: buildAudit(
      fn: 'flagFromWetBulbF',
      inputs: {'wetBulbF': wetBulbF},
      constants: {
        'white_max': _whiteMax,
        'green_max': _greenMax,
        'yellow_max': _yellowMax,
        'red_max': _redMax,
      },
      citation: _citation,
      resultSummary: 'wetBulbF=${_formatNum(wetBulbF)} → ${flag.name}$markerStr',
      ctx: ctx,
    ),
  );
}

/// Convenience: degrees-Celsius wrapper. Internally converts to °F (via
/// celsiusToFahrenheit) then calls flagFromWetBulbF. Nests the inner audit
/// as a child so the conversion step is recorded.
SpecReturn<FlagMappingOutput> flagFromWetBulbC(
  double wetBulbC, [
  SpecContext? ctx,
]) {
  if (wetBulbC.isNaN || wetBulbC.isInfinite) {
    return SpecReturn(
      result: null,
      audit: buildAudit(
        fn: 'flagFromWetBulbC',
        inputs: {'wetBulbC': wetBulbC.isNaN ? 'NaN' : wetBulbC},
        constants: {},
        citation: _citation,
        resultSummary: 'invalid_input:wetBulbC',
        ctx: ctx,
      ),
    );
  }
  final wetBulbF = celsiusToFahrenheit(wetBulbC);
  final inner = flagFromWetBulbF(wetBulbF, ctx);
  final innerFlag = inner.result?.flag.name ?? 'null';
  return SpecReturn(
    result: inner.result,
    audit: buildAudit(
      fn: 'flagFromWetBulbC',
      inputs: {'wetBulbC': wetBulbC},
      constants: {
        'white_max': _whiteMax,
        'green_max': _greenMax,
        'yellow_max': _yellowMax,
        'red_max': _redMax,
      },
      citation: _citation,
      resultSummary:
          'wetBulbC=${_formatNum(wetBulbC)} → wetBulbF=${wetBulbF.toStringAsFixed(4)} → $innerFlag',
      ctx: ctx,
      children: [inner.audit],
    ),
  );
}

EnvironmentalFlag _bandFor(double w) {
  if (w < _whiteMax) return EnvironmentalFlag.white;
  if (w < _greenMax) return EnvironmentalFlag.green;
  if (w < _yellowMax) return EnvironmentalFlag.yellow;
  if (w < _redMax) return EnvironmentalFlag.red;
  return EnvironmentalFlag.black;
}

String _formatNum(double n) {
  if (n == n.truncateToDouble()) return n.toInt().toString();
  return n.toString();
}
