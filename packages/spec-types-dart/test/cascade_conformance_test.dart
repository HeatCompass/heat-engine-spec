import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:heat_engine_spec/heat_engine_spec.dart';

DateTime _clockFor(String iso) => DateTime.parse(iso);

// The first two NWS requests (point metadata, then its observation stations),
// as the replay fixtures give them.
const _nwsPointAndStations = [
  CascadeReplayResponse(
    urlPattern: r'api\.weather\.gov/points/',
    status: 200,
    bodyJson: {
      'properties': {
        'observationStations': 'https://api.weather.gov/gridpoints/MTR/85,105/stations',
      },
    },
  ),
  CascadeReplayResponse(
    urlPattern: r'api\.weather\.gov/gridpoints/.*/stations$',
    status: 200,
    bodyJson: {
      'features': [
        {
          'properties': {'stationIdentifier': 'SFOC1'},
        },
      ],
    },
  ),
];

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
        ..._nwsPointAndStations,
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

  group('NWS request flow (points → stations → latest observation)', () {
    const observation = CascadeReplayResponse(
      urlPattern: r'api\.weather\.gov/stations/[^/]+/observations/latest$',
      status: 200,
      bodyJson: {
        'properties': {
          'temperature': {'value': 25},
          'relativeHumidity': {'value': 50},
        },
      },
    );
    SpecContext ctxWith(List<CascadeReplayResponse> responses, [List<HttpRequest>? seen]) {
      final replay = buildReplayAdapter(responses);
      return SpecContext(
        clock: () => DateTime.utc(2026, 5, 26, 17),
        httpAdapter: (HttpRequest req) {
          seen?.add(req);
          return replay(req);
        },
      );
    }

    test('asks for the point, then its stations, then the first station\'s latest observation', () async {
      final seen = <HttpRequest>[];
      final ret = await fetchWeatherCascade(
        const CascadeRequest(lat: 37.7749, lng: -122.4194),
        ctxWith([..._nwsPointAndStations, observation], seen),
      );
      expect(ret.result?.sample.source, WeatherSource.nws);
      expect(seen.map((r) => r.url).toList(), [
        'https://api.weather.gov/points/37.7749,-122.4194',
        'https://api.weather.gov/gridpoints/MTR/85,105/stations',
        'https://api.weather.gov/stations/SFOC1/observations/latest',
      ]);
      // NWS answers 403 to requests without a User-Agent.
      for (final r in seen) {
        expect(r.headers?['User-Agent'], contains('heat-engine-spec'));
      }
    });

    test('a point without observationStations fails the NWS tier', () async {
      final ret = await fetchWeatherCascade(
        const CascadeRequest(lat: 1, lng: 2),
        ctxWith(const [
          CascadeReplayResponse(
            urlPattern: r'api\.weather\.gov/points/',
            status: 200,
            bodyJson: {'properties': <String, Object?>{}},
          ),
        ]),
      );
      expect(ret.audit.sourcesTried!.first.error, 'missing_field:observationStations');
    });

    test('an empty station list fails the NWS tier', () async {
      final ret = await fetchWeatherCascade(
        const CascadeRequest(lat: 1, lng: 2),
        ctxWith([
          _nwsPointAndStations.first,
          const CascadeReplayResponse(
            urlPattern: r'api\.weather\.gov/gridpoints/',
            status: 200,
            bodyJson: {'features': <Object?>[]},
          ),
        ]),
      );
      expect(ret.audit.sourcesTried!.first.error, 'missing_field:stationIdentifier');
    });

    test("an HTTP error on the point request is that tier's error", () async {
      final ret = await fetchWeatherCascade(
        const CascadeRequest(lat: 1, lng: 2),
        ctxWith(const [
          CascadeReplayResponse(
            urlPattern: r'api\.weather\.gov/points/',
            status: 404,
            bodyText: 'not found',
          ),
        ]),
      );
      expect(ret.audit.sourcesTried!.first.error, 'http_404');
    });
  });

  group('windMps is metres per second', () {
    Future<SpecReturn<CascadeResult>> run(List<CascadeReplayResponse> responses, [List<String>? seen]) {
      final replay = buildReplayAdapter(responses);
      return fetchWeatherCascade(
        const CascadeRequest(lat: 1, lng: 2),
        SpecContext(
          clock: () => DateTime.utc(2026, 5, 26, 17),
          httpAdapter: (HttpRequest req) {
            seen?.add(req.url);
            return replay(req);
          },
        ),
      );
    }

    List<CascadeReplayResponse> nwsWith(Map<String, Object?> windSpeed) => [
          ..._nwsPointAndStations,
          CascadeReplayResponse(
            urlPattern: 'observations/latest',
            status: 200,
            bodyJson: {
              'properties': {
                'temperature': {'value': 25},
                'relativeHumidity': {'value': 50},
                'windSpeed': windSpeed,
              },
            },
          ),
        ];

    List<CascadeReplayResponse> openMeteoWith(Map<String, Object?> body) => [
          const CascadeReplayResponse(urlPattern: r'api\.weather\.gov', status: 503, bodyText: 'unavailable'),
          CascadeReplayResponse(urlPattern: r'api\.open-meteo\.com', status: 200, bodyJson: body),
        ];

    test('NWS km/h (wmoUnit:km_h-1, also assumed when the unit code is missing) is divided by 3.6', () async {
      expect((await run(nwsWith({'value': 36, 'unitCode': 'wmoUnit:km_h-1'}))).result!.sample.windMps, 10);
      expect((await run(nwsWith({'value': 3.1}))).result!.sample.windMps, 3.1 / 3.6);
    });

    test('NWS m/s is kept, and an unknown unit leaves windMps out', () async {
      expect((await run(nwsWith({'value': 4, 'unitCode': 'wmoUnit:m_s-1'}))).result!.sample.windMps, 4);
      expect((await run(nwsWith({'value': 4, 'unitCode': 'wmoUnit:kn'}))).result!.sample.windMps, isNull);
    });

    test('Open-Meteo is asked for m/s, and a km/h answer is still converted', () async {
      const current = {'temperature_2m': 20, 'relative_humidity_2m': 50, 'wind_speed_10m': 18};
      final seen = <String>[];
      expect((await run(openMeteoWith({'current': current}), seen)).result!.sample.windMps, 18);
      expect(seen.firstWhere((u) => u.contains('open-meteo')), contains('&wind_speed_unit=ms'));
      final kmh = await run(openMeteoWith({
        'current_units': {'wind_speed_10m': 'km/h'},
        'current': current,
      }));
      expect(kmh.result!.sample.windMps, 5);
    });
  });
}
