import 'package:test/test.dart';
import 'package:heat_engine_spec/src/audit.dart';
import 'package:heat_engine_spec/src/canonical_json.dart';
import 'package:heat_engine_spec/src/spec_version.dart';

DateTime fixedClock() => DateTime.utc(2026, 5, 26, 17, 0, 0, 0);

void main() {
  group('buildAudit', () {
    test('stamps spec_version from the specVersion constant', () {
      final a = buildAudit(
        fn: 'testFn',
        inputs: {'x': 1},
        constants: {},
        citation: 'test',
        resultSummary: 'ok',
        ctx: SpecContext(clock: fixedClock),
      );
      expect(a.specVersion, specVersion);
    });

    test('uses the injected clock when provided', () {
      final a = buildAudit(
        fn: 'testFn',
        inputs: {},
        constants: {},
        citation: 'test',
        resultSummary: 'ok',
        ctx: SpecContext(clock: fixedClock),
      );
      expect(a.toJson()['computed_at'], '2026-05-26T17:00:00.000Z');
    });

    test('defaults to DateTime.now when no clock is injected', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final a = buildAudit(
        fn: 'testFn',
        inputs: {},
        constants: {},
        citation: 'test',
        resultSummary: 'ok',
      );
      final after = DateTime.now().millisecondsSinceEpoch;
      final stamped = a.computedAt.millisecondsSinceEpoch;
      expect(stamped, greaterThanOrEqualTo(before));
      expect(stamped, lessThanOrEqualTo(after));
    });

    test('serializes to canonical JSON with sorted keys', () {
      final a = buildAudit(
        fn: 'testFn',
        inputs: {'x': 1},
        constants: {'c': 2},
        citation: 'cite',
        resultSummary: 'r',
        ctx: SpecContext(clock: fixedClock),
      );
      final json = canonicalJson(a.toJson());
      expect(
        json,
        '{"citation":"cite","computed_at":"2026-05-26T17:00:00.000Z","constants":{"c":2},'
        '"function":"testFn","inputs":{"x":1},"result_summary":"r","spec_version":"$specVersion"}',
      );
    });

    test('produces ISO 8601 with .000Z millisecond precision', () {
      final a = buildAudit(
        fn: 'testFn',
        inputs: {},
        constants: {},
        citation: 'c',
        resultSummary: 'r',
        ctx: SpecContext(clock: () => DateTime.utc(1970, 1, 1, 0, 0, 0, 0)),
      );
      expect(a.toJson()['computed_at'], '1970-01-01T00:00:00.000Z');
    });

    test('emits cascade extras into JSON', () {
      final a = buildAudit(
        fn: 'fetchWeatherCascade',
        inputs: {'lat': 0, 'lng': 0},
        constants: {'nws_timeout_ms': 5000},
        citation: 'cascade',
        resultSummary: 'ok',
        ctx: SpecContext(clock: fixedClock),
        sourceChain: [WeatherSource.nws],
        fallbackReason: 'none',
      );
      final j = a.toJson();
      expect(j['source_chain'], ['nws']);
      expect(j['fallback_reason'], 'none');
    });
  });
}
