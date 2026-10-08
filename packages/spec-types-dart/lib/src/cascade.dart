// Weather-source cascade: NWS → Open-Meteo → simulated.
//
// Mirror of cascade.ts. Result summaries + child-audit shape match
// byte-for-byte across languages via canonicalJson.
//
// NWS serves observations per station, not per point, so its tier is three
// requests (https://www.weather.gov/documentation/services-web-api):
// /points/{lat},{lng} names the point's observation stations, that list
// starts with the nearest station, and /stations/{id}/observations/latest is
// its latest observation. A failure at any of the three fails the tier.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'audit.dart';
import 'types.dart';

const String _citation = 'Cascade order: NWS → Open-Meteo → simulated';
const String _nwsBase = 'https://api.weather.gov';
// NWS requires every client to send a User-Agent (it answers 403 without one).
const Map<String, String> _nwsHeaders = {
  'User-Agent': 'heat-engine-spec (https://github.com/HeatCompass/heat-engine-spec)',
  'Accept': 'application/geo+json',
};
const String _nwsCitation = 'api.weather.gov';
const String _openMeteoCitation = 'api.open-meteo.com';
const int _nwsTimeoutMs = 5000;
const int _openMeteoTimeoutMs = 5000;
const double _simulatedTempC = 20;
const double _simulatedRhPercent = 50;

const WeatherSample _simulatedSample = WeatherSample(
  tempC: _simulatedTempC,
  rhPercent: _simulatedRhPercent,
  source: WeatherSource.simulated,
);

Future<HttpResponse> _nativeFetch(HttpRequest req) async {
  final uri = Uri.parse(req.url);
  final timeout = Duration(milliseconds: req.timeoutMs);
  final res = await http
      .get(uri, headers: req.headers)
      .timeout(timeout, onTimeout: () => throw TimeoutException('timeout'));
  return HttpResponse(status: res.statusCode, body: res.body);
}

Future<SpecReturn<CascadeResult>> fetchWeatherCascade(
  CascadeRequest req, [
  SpecContext? ctx,
]) async {
  final adapter = ctx?.httpAdapter ?? _nativeFetch;
  final sourceChain = <WeatherSource>[];
  final sourcesTried = <SourceAttempt>[];
  final children = <AuditRecord>[];

  // Tier 1: NWS
  sourceChain.add(WeatherSource.nws);
  final nws = await _tryNws(req, adapter, ctx);
  sourcesTried.add(nws.attempt);
  children.add(nws.audit);
  if (nws.sample != null) {
    return _finalize(
      req,
      nws.sample!,
      sourceChain,
      sourcesTried,
      children,
      null,
      ctx,
    );
  }

  // Tier 2: Open-Meteo
  sourceChain.add(WeatherSource.openMeteo);
  final om = await _tryOpenMeteo(req, adapter, ctx);
  sourcesTried.add(om.attempt);
  children.add(om.audit);
  if (om.sample != null) {
    return _finalize(
      req,
      om.sample!,
      sourceChain,
      sourcesTried,
      children,
      _describeFallback(nws.attempt),
      ctx,
    );
  }

  // Tier 3: simulated
  sourceChain.add(WeatherSource.simulated);
  return _finalize(
    req,
    _simulatedSample,
    sourceChain,
    sourcesTried,
    children,
    'all_live_sources_failed',
    ctx,
  );
}

SpecReturn<CascadeResult> _finalize(
  CascadeRequest req,
  WeatherSample sample,
  List<WeatherSource> sourceChain,
  List<SourceAttempt> sourcesTried,
  List<AuditRecord> children,
  String? fallbackReason,
  SpecContext? ctx,
) {
  final isSimulated = sample.source == WeatherSource.simulated;
  final constants = <String, double>{
    'nws_timeout_ms': _nwsTimeoutMs.toDouble(),
    'open_meteo_timeout_ms': _openMeteoTimeoutMs.toDouble(),
  };
  if (isSimulated) {
    constants['simulated_temp_c'] = _simulatedTempC;
    constants['simulated_rh_percent'] = _simulatedRhPercent;
  }

  String summary;
  if (sample.source == WeatherSource.nws) {
    summary =
        'cascade → nws OK (tempC=${_formatNum(sample.tempC)}, rhPercent=${_formatNum(sample.rhPercent)})';
  } else if (sample.source == WeatherSource.openMeteo) {
    summary =
        'cascade → open-meteo OK (tempC=${_formatNum(sample.tempC)}, rhPercent=${_formatNum(sample.rhPercent)}) after ${_describeFallback(sourcesTried.first)}';
  } else {
    summary = 'cascade → simulated (all_live_sources_failed)';
  }

  return SpecReturn(
    result: CascadeResult(sample: sample),
    audit: buildAudit(
      fn: 'fetchWeatherCascade',
      inputs: _encodeInputs(req),
      constants: constants,
      citation: _citation,
      resultSummary: summary,
      ctx: ctx,
      children: children,
      sourceChain: sourceChain,
      sourcesTried: sourcesTried,
      fallbackReason: fallbackReason,
    ),
  );
}

String _describeFallback(SourceAttempt attempt) {
  if (attempt.status == 'timeout') return 'nws timeout';
  if (attempt.status == 'error') {
    final err = attempt.error;
    if (err != null && err.startsWith('missing_field:')) return 'nws missing fields';
    if (err != null && err.startsWith('http_')) return 'nws $err';
    return 'nws ${err ?? 'error'}';
  }
  return 'nws ok';
}

class _SourceTry {
  final WeatherSample? sample;
  final SourceAttempt attempt;
  final AuditRecord audit;
  _SourceTry({required this.sample, required this.attempt, required this.audit});
}

Future<_SourceTry> _tryNws(
  CascadeRequest req,
  HttpAdapter adapter,
  SpecContext? ctx,
) {
  return _trySource(
    source: WeatherSource.nws,
    timeoutMs: _nwsTimeoutMs,
    citation: _nwsCitation,
    adapter: adapter,
    headers: _nwsHeaders,
    req: req,
    ctx: ctx,
    run: (get) async {
      final point = await get(
          '$_nwsBase/points/${_formatLatLng(req.lat)},${_formatLatLng(req.lng)}');
      final pointProps = point is Map<String, Object?> ? point['properties'] : null;
      final stationsUrl =
          pointProps is Map<String, Object?> ? pointProps['observationStations'] : null;
      if (stationsUrl is! String) {
        return const _ParseError('missing_field:observationStations');
      }
      final stations = await get(stationsUrl);
      final features = stations is Map<String, Object?> ? stations['features'] : null;
      final first = features is List && features.isNotEmpty ? features.first : null;
      final firstProps = first is Map<String, Object?> ? first['properties'] : null;
      final stationId =
          firstProps is Map<String, Object?> ? firstProps['stationIdentifier'] : null;
      if (stationId is! String) {
        return const _ParseError('missing_field:stationIdentifier');
      }
      return _parseNws(await get(
          '$_nwsBase/stations/${Uri.encodeComponent(stationId)}/observations/latest'));
    },
  );
}

Future<_SourceTry> _tryOpenMeteo(
  CascadeRequest req,
  HttpAdapter adapter,
  SpecContext? ctx,
) {
  final url =
      'https://api.open-meteo.com/v1/forecast?latitude=${_formatLatLng(req.lat)}&longitude=${_formatLatLng(req.lng)}&current=temperature_2m,relative_humidity_2m,wind_speed_10m';
  return _trySource(
    source: WeatherSource.openMeteo,
    timeoutMs: _openMeteoTimeoutMs,
    citation: _openMeteoCitation,
    adapter: adapter,
    headers: null,
    req: req,
    ctx: ctx,
    run: (get) async => _parseOpenMeteo(await get(url)),
  );
}

/// A request in a source's chain failed in a way the attempt records by code.
class _SourceFailure implements Exception {
  final String code;
  const _SourceFailure(this.code);
}

typedef _Get = Future<Object?> Function(String url);

Future<_SourceTry> _trySource({
  required WeatherSource source,
  required int timeoutMs,
  required String citation,
  required HttpAdapter adapter,
  required Map<String, String>? headers,
  required CascadeRequest req,
  required SpecContext? ctx,
  required Future<Object?> Function(_Get get) run,
}) async {
  // One GET of the chain: HTTP >= 400 is http_<status>, an unparsable body is
  // parse_error, and a timeout or transport error propagates.
  Future<Object?> get(String url) async {
    final res = await adapter(
        HttpRequest(url: url, timeoutMs: timeoutMs, headers: headers));
    if (res.status >= 400) throw _SourceFailure('http_${res.status}');
    try {
      return jsonDecode(res.body);
    } catch (_) {
      throw const _SourceFailure('parse_error');
    }
  }

  SourceAttempt attempt = SourceAttempt(source: source, status: 'ok', durationMs: 0);
  WeatherSample? sample;
  final sourceWire = weatherSourceToWire(source);
  String summary = '$sourceWire OK in 0ms';

  try {
    final out = await run(get);
    if (out is WeatherSample) {
      sample = out;
      attempt = SourceAttempt(source: source, status: 'ok', durationMs: 0);
      summary = '$sourceWire OK in 0ms';
    } else if (out is _ParseError) {
      attempt = SourceAttempt(
        source: source,
        status: 'error',
        durationMs: 0,
        error: out.code,
      );
      summary = '$sourceWire ${out.code}';
    }
  } on _SourceFailure catch (f) {
    attempt = SourceAttempt(
      source: source,
      status: 'error',
      durationMs: 0,
      error: f.code,
    );
    summary = '$sourceWire ${f.code}';
  } catch (e) {
    final msg = e is TimeoutException
        ? (e.message ?? 'timeout')
        : e.toString();
    if (msg == 'timeout' ||
        e is TimeoutException ||
        msg.toLowerCase().contains('abort')) {
      attempt = SourceAttempt(
        source: source,
        status: 'timeout',
        durationMs: timeoutMs,
        error: 'timeout',
      );
      summary = '$sourceWire timeout';
    } else {
      attempt = SourceAttempt(
        source: source,
        status: 'error',
        durationMs: 0,
        error: msg,
      );
      summary = '$sourceWire $msg';
    }
  }

  final childConstants = source == WeatherSource.nws
      ? <String, double>{'nws_timeout_ms': _nwsTimeoutMs.toDouble()}
      : <String, double>{'open_meteo_timeout_ms': _openMeteoTimeoutMs.toDouble()};

  final audit = buildAudit(
    fn: 'fetchWeatherCascade.$sourceWire',
    inputs: _encodeInputs(req),
    constants: childConstants,
    citation: citation,
    resultSummary: summary,
    ctx: ctx,
  );

  return _SourceTry(sample: sample, attempt: attempt, audit: audit);
}

class _ParseError {
  final String code;
  const _ParseError(this.code);
}

Object? _parseNws(Object? body) {
  final b = body is Map<String, Object?> ? body : null;
  final props = b?['properties'];
  if (props is! Map<String, Object?>) return const _ParseError('missing_field:temperature');
  final tempObj = props['temperature'];
  final tempVal =
      tempObj is Map<String, Object?> ? tempObj['value'] : null;
  if (tempVal == null) return const _ParseError('missing_field:temperature');
  final rhObj = props['relativeHumidity'];
  final rhVal = rhObj is Map<String, Object?> ? rhObj['value'] : null;
  if (rhVal == null) return const _ParseError('missing_field:relativeHumidity');
  final wsObj = props['windSpeed'];
  final wsVal = wsObj is Map<String, Object?> ? wsObj['value'] : null;
  return WeatherSample(
    tempC: (tempVal as num).toDouble(),
    rhPercent: (rhVal as num).toDouble(),
    source: WeatherSource.nws,
    windMps: wsVal == null ? null : (wsVal as num).toDouble(),
  );
}

Object? _parseOpenMeteo(Object? body) {
  final b = body is Map<String, Object?> ? body : null;
  final current = b?['current'];
  if (current is! Map<String, Object?>) return const _ParseError('missing_field:temperature_2m');
  final t = current['temperature_2m'];
  if (t == null) return const _ParseError('missing_field:temperature_2m');
  final rh = current['relative_humidity_2m'];
  if (rh == null) return const _ParseError('missing_field:relative_humidity_2m');
  final ws = current['wind_speed_10m'];
  return WeatherSample(
    tempC: (t as num).toDouble(),
    rhPercent: (rh as num).toDouble(),
    source: WeatherSource.openMeteo,
    windMps: ws == null ? null : (ws as num).toDouble(),
  );
}

Map<String, Object?> _encodeInputs(CascadeRequest req) {
  final out = <String, Object?>{'lat': req.lat, 'lng': req.lng};
  if (req.isoTimestamp != null) out['isoTimestamp'] = req.isoTimestamp;
  return out;
}

String _formatNum(double n) {
  if (n == n.truncateToDouble()) return n.toInt().toString();
  return n.toString();
}

String _formatLatLng(double n) {
  // Preserve the float representation the way it appears in JS (e.g. '37.7749'
  // not '37.7749000'). Same logic as _formatNum.
  return _formatNum(n);
}
