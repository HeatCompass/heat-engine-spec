import 'package:test/test.dart';
import 'package:heat_engine_spec/heat_engine_spec.dart';

void main() {
  group('tier 1 fixture loaders', () {
    test('loadWetBulbFixtures returns >= 30 rows with parsed numeric fields', () {
      final rows = loadWetBulbFixtures();
      expect(rows.length, greaterThanOrEqualTo(30));
      final first = rows.first;
      expect(first.id, isA<String>());
      expect(first.sourceRef, isA<String>());
      expect(first.tempC, isA<double>());
      expect(first.rhPercent, isA<double>());
      expect(first.expectedWetBulbC, isA<double>());
      expect(first.expectedWetBulbF, isA<double>());
      expect(first.toleranceC, isA<double>());
      expect(first.notes, isA<String>());
    });

    test('loadFlagMappingFixtures returns >= 20 rows with valid flag enums', () {
      final rows = loadFlagMappingFixtures();
      expect(rows.length, greaterThanOrEqualTo(20));
      for (final row in rows) {
        expect(row.wetBulbF, isA<double>());
        expect(EnvironmentalFlag.values, contains(row.expectedFlag));
        expect(HeatRiskLevelLabel.values, contains(row.expectedFlagDartLabel));
      }
    });
  });
}
