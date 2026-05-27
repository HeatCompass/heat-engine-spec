import 'package:test/test.dart';
import 'package:heat_engine_spec/heat_engine_spec.dart';

DateTime fixedClock() => DateTime.utc(2026, 5, 26, 17, 0, 0, 0);

void main() {
  final rows = loadRefugeBreakFixtures();

  group('refugeBreak conformance against existing fixture (${rows.length} rows)', () {
    test('loads >= 10 rows', () {
      expect(rows.length, greaterThanOrEqualTo(10));
    });

    for (final row in rows) {
      test('${row.id}: ${row.flag.name}/${row.acclimatized ? 'acclim' : 'unacclim'}', () {
        final ctx = SpecContext(clock: fixedClock);
        final ret = workRestForFlag(
          RefugeBreakInput(
            flag: row.flag,
            acclimatized: row.acclimatized,
            workMinutesRequested: row.workMinutesRequested,
          ),
          ctx,
        );

        expect(ret.result, isNotNull);
        expect(ret.result!.workMinutes, row.expectedWorkMinutes);
        expect(ret.result!.restMinutes, row.expectedRestMinutes);
        expect(
          ret.result!.cyclesUntilReassessRequired,
          row.expectedCyclesUntilReassessRequired,
        );
        expect(ret.result!.ceaseWork, row.expectedCeaseWork);

        final j = ret.audit.toJson();
        expect(j['spec_version'], specVersion);
        expect(j['function'], 'workRestForFlag');
        expect(j['citation'], 'USMC 6200.1E §3.2');
        expect(j['computed_at'], '2026-05-26T17:00:00.000Z');
        expect(j['inputs'], {
          'flag': row.flag.name,
          'acclimatized': row.acclimatized,
          'workMinutesRequested': row.workMinutesRequested,
        });
        final branch = row.acclimatized ? 'acclim' : 'unacclim';
        if (row.expectedCeaseWork) {
          expect(j['constants'], <String, double>{});
          expect(j['result_summary'], '${row.flag.name}/$branch → cease_work');
        } else {
          final constants = j['constants'] as Map;
          expect(
            constants['${row.flag.name}_work_$branch'],
            row.expectedWorkMinutes.toDouble(),
          );
          expect(
            constants['${row.flag.name}_rest_$branch'],
            row.expectedRestMinutes.toDouble(),
          );
          expect(
            j['result_summary'] as String,
            matches(RegExp(r'^(white|green|yellow|red|black)/(acclim|unacclim) → \d+w/\d+r')),
          );
        }
      });
    }
  });

  group('refugeBreak summary phrasing edges', () {
    final fixed = SpecContext(clock: fixedClock);

    test('reassess=1 phrases as "reassess every cycle"', () {
      final ret = workRestForFlag(
        const RefugeBreakInput(
          flag: EnvironmentalFlag.black,
          acclimatized: true,
          workMinutesRequested: 60,
        ),
        fixed,
      );
      expect(ret.result?.cyclesUntilReassessRequired, 1);
      expect(
        ret.audit.toJson()['result_summary'],
        'black/acclim → 10w/50r, reassess every cycle',
      );
      expect(ret.audit.toJson()['constants'], <String, double>{
        'black_work_acclim': 10,
        'black_rest_acclim': 50,
        'black_reassess_cycles': 1,
      });
    });

    test('reassess>1 acclim uses _reassess_cycles key', () {
      final ret = workRestForFlag(
        const RefugeBreakInput(
          flag: EnvironmentalFlag.yellow,
          acclimatized: true,
          workMinutesRequested: 60,
        ),
        fixed,
      );
      expect(ret.audit.toJson()['constants'], <String, double>{
        'yellow_work_acclim': 45,
        'yellow_rest_acclim': 15,
        'yellow_reassess_cycles': 6,
      });
      expect(
        ret.audit.toJson()['result_summary'],
        'yellow/acclim → 45w/15r, reassess after 6 cycles',
      );
    });

    test('reassess>1 unacclim uses _reassess_cycles_unacclim key', () {
      final ret = workRestForFlag(
        const RefugeBreakInput(
          flag: EnvironmentalFlag.yellow,
          acclimatized: false,
          workMinutesRequested: 60,
        ),
        fixed,
      );
      expect(ret.audit.toJson()['constants'], <String, double>{
        'yellow_work_unacclim': 30,
        'yellow_rest_unacclim': 30,
        'yellow_reassess_cycles_unacclim': 4,
      });
    });

    test('cease branch returns 0/0 with empty constants', () {
      final ret = workRestForFlag(
        const RefugeBreakInput(
          flag: EnvironmentalFlag.red,
          acclimatized: false,
          workMinutesRequested: 60,
        ),
        fixed,
      );
      expect(ret.result!.workMinutes, 0);
      expect(ret.result!.restMinutes, 0);
      expect(ret.result!.cyclesUntilReassessRequired, isNull);
      expect(ret.result!.ceaseWork, isTrue);
      expect(ret.audit.toJson()['constants'], <String, double>{});
      expect(ret.audit.toJson()['result_summary'], 'red/unacclim → cease_work');
    });

    test('non-positive workMinutesRequested adds non_positive_work_window marker', () {
      final ret = workRestForFlag(
        const RefugeBreakInput(
          flag: EnvironmentalFlag.green,
          acclimatized: true,
          workMinutesRequested: 0,
        ),
        fixed,
      );
      expect(ret.result!.workMinutes, 50);
      expect(
        ret.audit.toJson()['result_summary'],
        'green/acclim → 50w/10r (non_positive_work_window)',
      );
    });

    test('canonical audit JSON sorts keys alphabetically', () {
      final ret = workRestForFlag(
        const RefugeBreakInput(
          flag: EnvironmentalFlag.yellow,
          acclimatized: true,
          workMinutesRequested: 60,
        ),
        fixed,
      );
      final json = canonicalJson(ret.audit.toJson());
      expect(json, contains('"citation":"USMC 6200.1E §3.2"'));
      expect(
        json.indexOf('"computed_at"'),
        lessThan(json.indexOf('"constants"')),
      );
    });
  });
}
