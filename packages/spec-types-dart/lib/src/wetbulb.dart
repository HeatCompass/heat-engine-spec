// Stull (2011) wet-bulb temperature reference implementation.
//
// Returns Approach B SpecReturn<WetBulbResultPlus>. The result carries
// wetBulbC + wetBulbF (a convenience conversion) and, when RH is clamped
// to the validity range, the clamped value. The audit captures the 6
// Stull constants, the input pair (post-clamp displayed in the summary),
// and a human-readable result_summary that doubles as the OSHA-CSV cell.
//
// Validity range: RH in [5, 100], tempC in [-20, 50]. Outside the range,
// the function still returns a result, but the audit's result_summary
// includes the marker 'out_of_validity_range'. Never throws on numeric
// input; returns SpecReturn(result: null, ...) on NaN / non-finite.

import 'dart:math' as math;
import 'audit.dart';
import 'types.dart';

const double _stullA = 0.151977;
const double _stullB = 8.313659;
const double _stullC = 1.676331;
const double _stullD = 0.00391838;
const double _stullE = 0.023101;
const double _stullOffset = -4.686035;
const double _rhClampMin = 5;
const double _rhClampMax = 100;
const String _citation = 'Stull (2011) eq. 1';

/// Output of [calculateWetBulb] — widens [WetBulbOutput] with the optional
/// clampedRhPct marker that's present only when the input RH was clamped.
class WetBulbResultPlus {
  final double wetBulbC;
  final double wetBulbF;
  final double? clampedRhPct;
  const WetBulbResultPlus({
    required this.wetBulbC,
    required this.wetBulbF,
    this.clampedRhPct,
  });
}

SpecReturn<WetBulbResultPlus> calculateWetBulb(
  WetBulbInput input, [
  SpecContext? ctx,
]) {
  final tempC = input.tempC;
  final rhPercent = input.rhPercent;

  if (tempC.isNaN || tempC.isInfinite || rhPercent.isNaN || rhPercent.isInfinite) {
    final badField =
        (tempC.isNaN || tempC.isInfinite) ? 'tempC' : 'rhPercent';
    return SpecReturn(
      result: null,
      audit: buildAudit(
        fn: 'calculateWetBulb',
        inputs: _encodeInputs(tempC, rhPercent),
        constants: {},
        citation: _citation,
        resultSummary: 'invalid_input:$badField',
        ctx: ctx,
      ),
    );
  }

  final clamped = rhPercent < _rhClampMin
      ? _rhClampMin
      : (rhPercent > _rhClampMax ? _rhClampMax : rhPercent);
  final wasClamped = clamped != rhPercent;
  final outOfValidity = tempC < -20 || tempC > 50;

  final term1 = tempC * math.atan(_stullA * math.sqrt(clamped + _stullB));
  final term2 = math.atan(tempC + clamped);
  final term3 = math.atan(clamped - _stullC);
  final term4 =
      _stullD * math.pow(clamped, 1.5) * math.atan(_stullE * clamped);
  final wetBulbC = term1 + term2 - term3 + term4 + _stullOffset;
  final wetBulbF = (wetBulbC * 9.0) / 5.0 + 32.0;

  final result = WetBulbResultPlus(
    wetBulbC: wetBulbC,
    wetBulbF: wetBulbF,
    clampedRhPct: wasClamped ? clamped : null,
  );

  final constants = <String, double>{
    'stull_a': _stullA,
    'stull_b': _stullB,
    'stull_c': _stullC,
    'stull_d': _stullD,
    'stull_e': _stullE,
    'stull_offset': _stullOffset,
  };
  if (wasClamped) {
    constants['rh_clamp_min'] = _rhClampMin;
    constants['rh_clamp_max'] = _rhClampMax;
  }

  final markers = <String>[];
  if (wasClamped) markers.add('rh_clamped');
  if (outOfValidity) markers.add('out_of_validity_range');
  final markerStr = markers.isEmpty ? '' : ' (${markers.join(',')})';
  final rhDisplay =
      wasClamped ? '${_formatNum(rhPercent)}→${_formatNum(clamped)}%' : '${_formatNum(clamped)}%';
  final summary =
      'T=${tempC.toStringAsFixed(1)}°C RH=$rhDisplay$markerStr → Tw=${wetBulbC.toStringAsFixed(2)}°C';

  return SpecReturn(
    result: result,
    audit: buildAudit(
      fn: 'calculateWetBulb',
      inputs: {'tempC': tempC, 'rhPercent': rhPercent},
      constants: constants,
      citation: _citation,
      resultSummary: summary,
      ctx: ctx,
    ),
  );
}

/// Convenience: F-in / F-out wrapper using the same audit envelope.
SpecReturn<WetBulbResultPlus> calculateWetBulbF(
  double tempF,
  double rhPercent, [
  SpecContext? ctx,
]) {
  final tempC = ((tempF - 32) * 5) / 9;
  return calculateWetBulb(WetBulbInput(tempC: tempC, rhPercent: rhPercent), ctx);
}

double fahrenheitToCelsius(double tempF) => ((tempF - 32) * 5) / 9;
double celsiusToFahrenheit(double tempC) => (tempC * 9) / 5 + 32;

Map<String, Object?> _encodeInputs(double tempC, double rhPercent) {
  return {
    'tempC': tempC.isNaN ? 'NaN' : tempC,
    'rhPercent': rhPercent.isNaN ? 'NaN' : rhPercent,
  };
}

String _formatNum(double n) {
  // Display rhPercent as an int when whole; mirrors TS/Python/CSV format.
  if (n == n.truncateToDouble()) return n.toInt().toString();
  return n.toString();
}
