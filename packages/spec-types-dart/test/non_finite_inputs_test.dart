// JSON has no NaN or Infinity. Audits write such inputs as the strings
// "NaN", "Infinity" and "-Infinity" in both implementations; the expected
// canonical audits below are the same literals as in the TypeScript test
// (test/non-finite-inputs.test.ts), so the two stay byte-equal.
import 'package:test/test.dart';
import 'package:heat_engine_spec/heat_engine_spec.dart';

void main() {
  final fixed = SpecContext(clock: () => DateTime.utc(2026, 5, 26, 17));

  group('non-finite inputs in audits', () {
    test('flagFromWetBulbF(Infinity)', () {
      final ret = flagFromWetBulbF(double.infinity, fixed);
      expect(ret.result, isNull);
      expect(
        canonicalJson(ret.audit.toJson()),
        '{"citation":"USMC 6200.1E Table 3-1","computed_at":"2026-05-26T17:00:00.000Z","constants":{},"function":"flagFromWetBulbF","inputs":{"wetBulbF":"Infinity"},"result_summary":"invalid_input:wetBulbF","spec_version":"0.1.1"}',
      );
    });

    test('calculateWetBulb with rhPercent -Infinity', () {
      final ret = calculateWetBulb(
        const WetBulbInput(tempC: 30, rhPercent: double.negativeInfinity),
        fixed,
      );
      expect(ret.result, isNull);
      expect(
        canonicalJson(ret.audit.toJson()),
        '{"citation":"Stull (2011) eq. 1","computed_at":"2026-05-26T17:00:00.000Z","constants":{},"function":"calculateWetBulb","inputs":{"rhPercent":"-Infinity","tempC":30},"result_summary":"invalid_input:rhPercent","spec_version":"0.1.1"}',
      );
    });

    test('canonicalJson writes non-finite numbers as strings', () {
      expect(
        canonicalJson({'a': double.infinity, 'b': double.negativeInfinity, 'c': double.nan}),
        '{"a":"Infinity","b":"-Infinity","c":"NaN"}',
      );
    });
  });
}
