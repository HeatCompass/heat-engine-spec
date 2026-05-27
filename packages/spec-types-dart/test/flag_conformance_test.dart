import 'package:test/test.dart';
import 'package:heat_engine_spec/heat_engine_spec.dart';

DateTime fixedClock() => DateTime.utc(2026, 5, 26, 17, 0, 0, 0);

const boundaryConstants = <String, double>{
  'white_max': 80,
  'green_max': 85,
  'yellow_max': 88,
  'red_max': 90,
};

void main() {
  final rows = loadFlagMappingFixtures();

  group('flag conformance against existing 20-row fixture', () {
    test('loads >= 20 rows', () {
      expect(rows.length, greaterThanOrEqualTo(20));
    });

    for (final row in rows) {
      test('${row.id}: wetBulbF=${row.wetBulbF} → ${row.expectedFlag.name}', () {
        final ctx = SpecContext(clock: fixedClock);
        final ret = flagFromWetBulbF(row.wetBulbF, ctx);
        expect(ret.result, isNotNull);
        expect(ret.result!.flag, row.expectedFlag);
        expect(ret.result!.flagDartLabel, row.expectedFlagDartLabel);

        final j = ret.audit.toJson();
        expect(j['spec_version'], specVersion);
        expect(j['function'], 'flagFromWetBulbF');
        expect(j['citation'], 'USMC 6200.1E Table 3-1');
        expect(j['computed_at'], '2026-05-26T17:00:00.000Z');
        expect(j['inputs'], {'wetBulbF': row.wetBulbF});
        expect(j['constants'], boundaryConstants);
      });
    }
  });

  group('flag edge cases + invalid input', () {
    final fixed = SpecContext(clock: fixedClock);

    test('NaN returns null result with invalid_input audit', () {
      final ret = flagFromWetBulbF(double.nan, fixed);
      expect(ret.result, isNull);
      final j = ret.audit.toJson();
      expect(j['result_summary'], 'invalid_input:wetBulbF');
      expect(j['inputs'], {'wetBulbF': 'NaN'});
      expect(j['constants'], {});
    });

    test('out_of_observed_range marker fires at extreme values', () {
      final ret = flagFromWetBulbF(250.0, fixed);
      expect(ret.result?.flag, EnvironmentalFlag.black);
      expect(ret.audit.toJson()['result_summary'], contains('out_of_observed_range'));
    });

    test('flagFromWetBulbC converts then nests the F-form audit as a child', () {
      final ret = flagFromWetBulbC(30.0, fixed); // 30°C ≈ 86°F → yellow
      expect(ret.result?.flag, EnvironmentalFlag.yellow);
      final j = ret.audit.toJson();
      expect(j['function'], 'flagFromWetBulbC');
      final children = j['children'] as List;
      expect(children, hasLength(1));
      expect((children.first as Map)['function'], 'flagFromWetBulbF');
    });

    test('flagFromWetBulbC with NaN returns null + invalid_input audit', () {
      final ret = flagFromWetBulbC(double.nan, fixed);
      expect(ret.result, isNull);
      expect(ret.audit.toJson()['result_summary'], 'invalid_input:wetBulbC');
    });

    test('canonical audit JSON sorts keys alphabetically', () {
      final ret = flagFromWetBulbF(85.0, fixed);
      final json = canonicalJson(ret.audit.toJson());
      expect(json, contains('"citation":"USMC 6200.1E Table 3-1"'));
      expect(json.indexOf('"computed_at"'), lessThan(json.indexOf('"constants"')));
    });
  });
}
