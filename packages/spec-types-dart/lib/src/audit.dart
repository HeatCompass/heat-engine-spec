// Approach B audit envelope types + builder helper.
//
// Every primary spec function returns SpecReturn<T> carrying both the
// result (possibly null on invalid input) and an AuditRecord. The audit
// conforms to spec/tier1-foundation/audit.schema.json.
//
// buildAudit is the single allocation point: it stamps specVersion (from
// spec_version.dart) and computedAt (from the SpecContext clock, defaulting
// to DateTime.now). This keeps the audit shape consistent across every
// callsite.

import 'spec_version.dart';
import 'types.dart' show EnvironmentalFlag;

enum WeatherSource { nws, openMeteo, simulated }

String weatherSourceToWire(WeatherSource s) {
  switch (s) {
    case WeatherSource.nws:
      return 'nws';
    case WeatherSource.openMeteo:
      return 'open-meteo';
    case WeatherSource.simulated:
      return 'simulated';
  }
}

WeatherSource weatherSourceFromWire(String s) {
  switch (s) {
    case 'nws':
      return WeatherSource.nws;
    case 'open-meteo':
      return WeatherSource.openMeteo;
    case 'simulated':
      return WeatherSource.simulated;
    default:
      throw ArgumentError('unknown weather source: $s');
  }
}

class SourceAttempt {
  final WeatherSource source;
  final String status; // 'ok' | 'error' | 'timeout'
  final int durationMs;
  final String? error;
  const SourceAttempt({
    required this.source,
    required this.status,
    required this.durationMs,
    this.error,
  });
}

class AuditRecord {
  final String specVersion;
  final String function;
  final Map<String, Object?> inputs;
  final Map<String, double> constants;
  final String citation;
  final String resultSummary;
  final DateTime computedAt;
  // optional tree + per-module extras
  final List<AuditRecord>? children;
  final List<WeatherSource>? sourceChain;
  final List<SourceAttempt>? sourcesTried;
  final String? fallbackReason;
  // verdict-only
  final bool priorFlagSet; // disambiguates "absent" from "explicit null"
  final EnvironmentalFlag? priorFlag;
  final EnvironmentalFlag? nextFlag;
  final String? promotionRule;

  const AuditRecord({
    required this.specVersion,
    required this.function,
    required this.inputs,
    required this.constants,
    required this.citation,
    required this.resultSummary,
    required this.computedAt,
    this.children,
    this.sourceChain,
    this.sourcesTried,
    this.fallbackReason,
    this.priorFlagSet = false,
    this.priorFlag,
    this.nextFlag,
    this.promotionRule,
  });

  /// Serialize to a JSON-ready Map. Caller passes this through
  /// canonicalJson() for byte-equality comparison against fixtures.
  Map<String, Object?> toJson() {
    final out = <String, Object?>{
      'spec_version': specVersion,
      'function': function,
      'inputs': inputs,
      'constants': constants,
      'citation': citation,
      'result_summary': resultSummary,
      'computed_at': _toIsoUtcMillis(computedAt),
    };
    if (children != null) {
      out['children'] = children!.map((c) => c.toJson()).toList();
    }
    if (sourceChain != null) {
      out['source_chain'] = sourceChain!.map(weatherSourceToWire).toList();
    }
    if (sourcesTried != null) {
      out['sources_tried'] = sourcesTried!.map((s) {
        final m = <String, Object?>{
          'source': weatherSourceToWire(s.source),
          'status': s.status,
          'duration_ms': s.durationMs,
        };
        if (s.error != null) m['error'] = s.error;
        return m;
      }).toList();
    }
    if (fallbackReason != null) out['fallback_reason'] = fallbackReason;
    if (priorFlagSet) out['prior_flag'] = priorFlag?.name;
    if (nextFlag != null) out['next_flag'] = nextFlag!.name;
    if (promotionRule != null) out['promotion_rule'] = promotionRule;
    return out;
  }
}

class HttpRequest {
  final String url;
  final String method;
  final Map<String, String>? headers;
  final String? body;
  final int timeoutMs;
  const HttpRequest({
    required this.url,
    this.method = 'GET',
    this.headers,
    this.body,
    this.timeoutMs = 5000,
  });
}

class HttpResponse {
  final int status;
  final String body;
  const HttpResponse({required this.status, required this.body});
}

typedef HttpAdapter = Future<HttpResponse> Function(HttpRequest req);

class SpecContext {
  final DateTime Function()? clock;
  final HttpAdapter? httpAdapter; // cascade only
  const SpecContext({this.clock, this.httpAdapter});
}

class SpecReturn<T> {
  final T? result;
  final AuditRecord audit;
  const SpecReturn({required this.result, required this.audit});
}

AuditRecord buildAudit({
  required String fn,
  required Map<String, Object?> inputs,
  required Map<String, double> constants,
  required String citation,
  required String resultSummary,
  SpecContext? ctx,
  List<AuditRecord>? children,
  List<WeatherSource>? sourceChain,
  List<SourceAttempt>? sourcesTried,
  String? fallbackReason,
  bool priorFlagSet = false,
  EnvironmentalFlag? priorFlag,
  EnvironmentalFlag? nextFlag,
  String? promotionRule,
}) {
  final clock = ctx?.clock ?? DateTime.now;
  return AuditRecord(
    specVersion: specVersion,
    function: fn,
    inputs: inputs,
    constants: constants,
    citation: citation,
    resultSummary: resultSummary,
    computedAt: clock(),
    children: children,
    sourceChain: sourceChain,
    sourcesTried: sourcesTried,
    fallbackReason: fallbackReason,
    priorFlagSet: priorFlagSet,
    priorFlag: priorFlag,
    nextFlag: nextFlag,
    promotionRule: promotionRule,
  );
}

// Force the '.000Z' millisecond form even when ms=0 — keeps the regex in
// audit.schema.json happy and cross-lang byte-equal with TS toISOString().
String _toIsoUtcMillis(DateTime t) {
  final u = t.toUtc();
  String d2(int n) => n.toString().padLeft(2, '0');
  final ms = u.millisecond.toString().padLeft(3, '0');
  return '${u.year.toString().padLeft(4, '0')}-'
      '${d2(u.month)}-${d2(u.day)}T'
      '${d2(u.hour)}:${d2(u.minute)}:${d2(u.second)}.'
      '${ms}Z';
}
