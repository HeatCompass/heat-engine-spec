import 'package:test/test.dart';
import 'package:heat_engine_spec/heat_engine_spec.dart';

DateTime fixedClock() => DateTime.utc(2026, 5, 26, 17, 0, 0, 0);

const stullConstants = <String, double>{
  'stull_a': 0.151977,
  'stull_b': 8.313659,
  'stull_c': 1.676331,
  'stull_d': 0.00391838,
  'stull_e': 0.023101,
  'stull_offset': -4.686035,
};

void main() {
  final rows = loadWetBulbFixtures();

  group('wetbulb conformance against existing fixture (${rows.length} rows)', () {
    test('loads >= 38 rows', () {
      expect(rows.length, greaterThanOrEqualTo(38));
    });

    for (final row in rows) {
      test('${row.id}: T=${row.tempC}°C RH=${row.rhPercent}%', () {
        final ctx = SpecContext(clock: fixedClock);
        final ret = calculateWetBulb(
          WetBulbInput(tempC: row.tempC, rhPercent: row.rhPercent),
          ctx,
        );

        // Result: numeric closeness within fixture-declared tolerance.
        expect(ret.result, isNotNull);
        expect(
          (ret.result!.wetBulbC - row.expectedWetBulbC).abs(),
          lessThanOrEqualTo(row.toleranceC),
        );
        expect(
          (ret.result!.wetBulbF - row.expectedWetBulbF).abs(),
          lessThanOrEqualTo(row.toleranceC * 9 / 5 + 1e-9),
        );

        // Audit: structural sanity (cross-lang byte-equal kicked over to
        // the CI cross-lang-equiv gate).
        final j = ret.audit.toJson();
        expect(j['spec_version'], specVersion);
        expect(j['function'], 'calculateWetBulb');
        expect(j['citation'], 'Stull (2011) eq. 1');
        expect(j['computed_at'], '2026-05-26T17:00:00.000Z');
        expect(j['inputs'], {'tempC': row.tempC, 'rhPercent': row.rhPercent});
        expect(j['constants'], stullConstants);
        expect(
          j['result_summary'] as String,
          matches(RegExp(r'^T=.*°C RH=.*% → Tw=.*°C$')),
        );
      });
    }
  });

  group('wetbulb invalid input branches', () {
    test('NaN tempC returns null result with invalid_input:tempC audit', () {
      final ret = calculateWetBulb(
        const WetBulbInput(tempC: double.nan, rhPercent: 50),
        SpecContext(clock: fixedClock),
      );
      expect(ret.result, isNull);
      final j = ret.audit.toJson();
      expect(j['result_summary'], 'invalid_input:tempC');
      expect(j['constants'], {});
      expect(j['inputs'], {'tempC': 'NaN', 'rhPercent': 50});
    });

    test('RH=120 is clamped to 100 and marked in audit', () {
      final ret = calculateWetBulb(
        const WetBulbInput(tempC: 25, rhPercent: 120),
        SpecContext(clock: fixedClock),
      );
      expect(ret.result, isNotNull);
      expect(ret.result!.clampedRhPct, 100.0);
      final j = ret.audit.toJson();
      expect(j['result_summary'], contains('rh_clamped'));
      expect((j['constants'] as Map)['rh_clamp_min'], 5.0);
      expect((j['constants'] as Map)['rh_clamp_max'], 100.0);
    });

    test('tempC=60 (out of validity) computes a result but marks the audit', () {
      final ret = calculateWetBulb(
        const WetBulbInput(tempC: 60, rhPercent: 50),
        SpecContext(clock: fixedClock),
      );
      expect(ret.result, isNotNull);
      final j = ret.audit.toJson();
      expect(j['result_summary'], contains('out_of_validity_range'));
    });

    test('canonical audit JSON sorts keys alphabetically', () {
      final ret = calculateWetBulb(
        const WetBulbInput(tempC: 20, rhPercent: 50),
        SpecContext(clock: fixedClock),
      );
      final json = canonicalJson(ret.audit.toJson());
      expect(json, contains('"citation":"Stull (2011) eq. 1"'));
      expect(
        json.indexOf('"citation"'),
        lessThan(json.indexOf('"computed_at"')),
      );
    });
  });
}
