import 'package:test/test.dart';
import 'package:heat_engine_spec/heat_engine_spec.dart';

DateTime fixedClock() => DateTime.utc(2026, 5, 26, 17, 0, 0, 0);

void main() {
  final rows = loadVerdictFixtures();

  group('verdict conformance against existing fixture (${rows.length} rows)', () {
    test('loads >= 8 rows', () {
      expect(rows.length, greaterThanOrEqualTo(8));
    });

    for (final row in rows) {
      test('${row.id}: ${row.priorFlag?.name ?? 'null'} → ${row.currentFlag.name}', () {
        final ctx = SpecContext(clock: fixedClock);
        final ret = promoteVerdict(
          VerdictInput(
            priorVerdict: row.priorVerdict,
            priorFlag: row.priorFlag,
            currentFlag: row.currentFlag,
            hasAlternateAvailable: row.hasAlternateAvailable,
          ),
          ctx,
        );

        expect(ret.result, isNotNull);
        expect(ret.result!.verdict, row.expectedVerdict);
        expect(ret.result!.changedFromPrior, row.expectedChangedFromPrior);
        expect(ret.result!.promotionRule, row.expectedPromotionRule);

        final j = ret.audit.toJson();
        expect(j['spec_version'], specVersion);
        expect(j['function'], 'promoteVerdict');
        expect(j['citation'], 'heat-engine-spec design doc §2.5');
        expect(j['computed_at'], '2026-05-26T17:00:00.000Z');
        expect(j['constants'], const <String, double>{});
        expect(j['inputs'], {
          'priorVerdict': row.priorVerdict?.name,
          'priorFlag': row.priorFlag?.name,
          'currentFlag': row.currentFlag.name,
          'hasAlternateAvailable': row.hasAlternateAvailable,
        });
        expect(j['prior_flag'], row.priorFlag?.name);
        expect(j['next_flag'], row.currentFlag.name);
        expect(
          j['promotion_rule'],
          promotionRuleToWire(row.expectedPromotionRule),
        );
      });
    }
  });

  group('verdict promotion rule branches', () {
    final fixed = SpecContext(clock: fixedClock);

    test('FIRST_RUN_DEFAULT renders summary "first run, …"', () {
      final ret = promoteVerdict(
        const VerdictInput(
          priorVerdict: null,
          priorFlag: null,
          currentFlag: EnvironmentalFlag.yellow,
          hasAlternateAvailable: false,
        ),
        fixed,
      );
      expect(ret.audit.toJson()['result_summary'], 'first run, yellow → go');
      expect(ret.audit.toJson()['prior_flag'], isNull);
    });

    test('NO_CHANGE with held delay adds "(held)"', () {
      final ret = promoteVerdict(
        const VerdictInput(
          priorVerdict: Verdict.delay,
          priorFlag: EnvironmentalFlag.red,
          currentFlag: EnvironmentalFlag.red,
          hasAlternateAvailable: false,
        ),
        fixed,
      );
      expect(ret.result?.verdict, Verdict.delay);
      expect(ret.audit.toJson()['result_summary'], 'no_change, red → delay (held)');
    });

    test('NO_CHANGE without held delay omits "(held)"', () {
      final ret = promoteVerdict(
        const VerdictInput(
          priorVerdict: Verdict.go,
          priorFlag: EnvironmentalFlag.green,
          currentFlag: EnvironmentalFlag.green,
          hasAlternateAvailable: false,
        ),
        fixed,
      );
      expect(ret.audit.toJson()['result_summary'], 'no_change, green → go');
    });

    test('ALTERNATE_AVAILABLE_AT_BLACK fires at black with alternate=true', () {
      final ret = promoteVerdict(
        const VerdictInput(
          priorVerdict: Verdict.go,
          priorFlag: EnvironmentalFlag.yellow,
          currentFlag: EnvironmentalFlag.black,
          hasAlternateAvailable: true,
        ),
        fixed,
      );
      expect(ret.result?.verdict, Verdict.alternate);
      expect(ret.result?.promotionRule, PromotionRule.alternateAvailableAtBlack);
      expect(
        ret.audit.toJson()['result_summary'],
        'yellow → black + alternate → alternate',
      );
    });

    test('ESCALATE rule fires at red without alternate', () {
      final ret = promoteVerdict(
        const VerdictInput(
          priorVerdict: Verdict.go,
          priorFlag: EnvironmentalFlag.green,
          currentFlag: EnvironmentalFlag.red,
          hasAlternateAvailable: false,
        ),
        fixed,
      );
      expect(ret.result?.verdict, Verdict.delay);
      expect(
        ret.audit.toJson()['result_summary'],
        'green → red, escalate to delay',
      );
    });

    test('ESCALATE rule fires at black when no alternate', () {
      final ret = promoteVerdict(
        const VerdictInput(
          priorVerdict: Verdict.go,
          priorFlag: EnvironmentalFlag.yellow,
          currentFlag: EnvironmentalFlag.black,
          hasAlternateAvailable: false,
        ),
        fixed,
      );
      expect(ret.result?.verdict, Verdict.delay);
      expect(
        ret.result?.promotionRule,
        PromotionRule.escalateToDelayOnRedOrBlack,
      );
      expect(
        ret.audit.toJson()['result_summary'],
        'yellow → black, escalate to delay',
      );
    });

    test('DEESCALATE rule fires when leaving red/black', () {
      final ret = promoteVerdict(
        const VerdictInput(
          priorVerdict: Verdict.delay,
          priorFlag: EnvironmentalFlag.red,
          currentFlag: EnvironmentalFlag.green,
          hasAlternateAvailable: false,
        ),
        fixed,
      );
      expect(ret.result?.verdict, Verdict.go);
      expect(
        ret.audit.toJson()['result_summary'],
        'red → green, deescalate to go',
      );
    });

    test('canonical audit JSON sorts keys alphabetically and includes verdict fields', () {
      final ret = promoteVerdict(
        const VerdictInput(
          priorVerdict: Verdict.go,
          priorFlag: EnvironmentalFlag.yellow,
          currentFlag: EnvironmentalFlag.black,
          hasAlternateAvailable: true,
        ),
        fixed,
      );
      final json = canonicalJson(ret.audit.toJson());
      expect(json, contains('"promotion_rule":"ALTERNATE_AVAILABLE_AT_BLACK"'));
      expect(json, contains('"prior_flag":"yellow"'));
      expect(json, contains('"next_flag":"black"'));
      expect(
        json.indexOf('"next_flag"'),
        lessThan(json.indexOf('"prior_flag"')),
      );
    });
  });
}
