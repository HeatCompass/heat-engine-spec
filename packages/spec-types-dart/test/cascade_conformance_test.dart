import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:heat_engine_spec/heat_engine_spec.dart';

DateTime _clockFor(String iso) => DateTime.parse(iso);

HttpAdapter buildReplayAdapter(List<CascadeReplayResponse> responses) {
  return (HttpRequest req) async {
    final match = responses.firstWhere(
      (r) => RegExp(r.urlPattern).hasMatch(req.url),
      orElse: () =>
          throw StateError('no replay response for ${req.url}'),
    );
    if (match.simulate == 'timeout') {
      throw TimeoutException('timeout');
    }
    final body = match.bodyJson != null
        ? jsonEncode(match.bodyJson)
        : (match.bodyText ?? '');
    return HttpResponse(status: match.status, body: body);
  };
}

void main() {
  final rows = loadCascadeFixtures();

  group('cascade conformance against existing 6 replay fixtures', () {
    test('loads >= 6 rows', () {
      expect(rows.length, greaterThanOrEqualTo(6));
    });

    for (final row in rows) {
      test('${row.fileName}::${row.id}', () async {
        final ctx = SpecContext(
          clock: () => _clockFor(row.clockIso),
          httpAdapter: buildReplayAdapter(row.responses),
        );
        final ret = await fetchWeatherCascade(row.input, ctx);

        if (row.expectedResult == null) {
          expect(ret.result, isNull);
        } else {
          expect(ret.result, isNotNull);
          expect(ret.result!.sample.tempC, row.expectedResult!.sample.tempC);
          expect(ret.result!.sample.rhPercent, row.expectedResult!.sample.rhPercent);
          expect(ret.result!.sample.windMps, row.expectedResult!.sample.windMps);
          expect(ret.result!.sample.source, row.expectedResult!.sample.source);
        }

        final actual = canonicalJson(ret.audit.toJson());
        final expected = canonicalJson(row.expectedAudit);
        expect(actual, expected);
      });
    }
  });

  group('cascade input forwarding', () {
    test('passes isoTimestamp through to audit inputs when provided', () async {
      final responses = [
        const CascadeReplayResponse(
          urlPattern: r'api\.weather\.gov/.*/observations/latest',
          status: 200,
          bodyJson: {
            'properties': {
              'temperature': {'value': 25},
              'relativeHumidity': {'value': 50},
            },
          },
        ),
      ];
      final ctx = SpecContext(
        clock: () => DateTime.utc(2026, 5, 26, 17, 0, 0, 0),
        httpAdapter: buildReplayAdapter(responses),
      );
      final ret = await fetchWeatherCascade(
        const CascadeRequest(
          lat: 1,
          lng: 2,
          isoTimestamp: '2026-05-26T16:00:00.000Z',
        ),
        ctx,
      );
      expect(ret.result?.sample.source, WeatherSource.nws);
      final j = ret.audit.toJson();
      expect(j['inputs'], {
        'lat': 1.0,
        'lng': 2.0,
        'isoTimestamp': '2026-05-26T16:00:00.000Z',
      });
    });
  });
}
