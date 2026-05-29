import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'types.dart';

/// Locates the bundled fixture CSV inside this package, regardless of where
/// the consumer's process happens to be running.
///
/// At test time we resolve via `Platform.script` + walking up to the package
/// root. Consumers MUST call these loaders from a `test/` context (the spec
/// conformance test pattern); calling from app runtime is not supported in
/// tier 1.
String _readBundledFixture(String filename) {
  final libFile = Directory.current;
  for (var dir = libFile; dir.path != dir.parent.path; dir = dir.parent) {
    final candidate = File('${dir.path}/.dart_tool/package_config.json');
    if (candidate.existsSync()) {
      final cfgText = candidate.readAsStringSync();
      final match = RegExp(
        r'"name":\s*"heat_engine_spec"[^}]*"rootUri":\s*"([^"]+)"',
      ).firstMatch(cfgText);
      if (match != null) {
        final root = Uri.parse(match.group(1)!);
        final rawBase = root.isAbsolute
            ? root
            : Uri.directory('${dir.path}/.dart_tool/').resolveUri(root);
        // Force a trailing slash so resolve() APPENDS rather than replacing the
        // final path segment. Hosted deps record rootUri without one (e.g.
        // .pub-cache/hosted/pub.dev/heat_engine_spec-0.1.0), so resolving
        // 'lib/fixtures/x' against it would drop the version dir and miss the
        // bundled fixture. Path deps already carry the slash.
        final base = rawBase.path.endsWith('/')
            ? rawBase
            : rawBase.replace(path: '${rawBase.path}/');
        final csvFile = File.fromUri(base.resolve('lib/fixtures/$filename'));
        if (csvFile.existsSync()) {
          return csvFile.readAsStringSync();
        }
      }
    }
  }
  throw StateError(
    'heat_engine_spec: could not locate bundled fixture "$filename". '
    'Ensure heat_engine_spec is in your dev_dependencies and `dart pub get` has run.',
  );
}

List<WetBulbFixtureRow> loadWetBulbFixtures() {
  final csv = _readBundledFixture('wet-bulb.fixtures.csv')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
      .convert(csv);
  final header = rows.first.map((e) => e.toString()).toList();
  final idx = {for (var i = 0; i < header.length; i++) header[i]: i};
  return rows.skip(1).map((r) => WetBulbFixtureRow(
        id: r[idx['id']!] as String,
        sourceRef: r[idx['source_ref']!] as String,
        tempC: double.parse(r[idx['temp_c']!] as String),
        rhPercent: double.parse(r[idx['rh_percent']!] as String),
        expectedWetBulbC: double.parse(r[idx['expected_wet_bulb_c']!] as String),
        expectedWetBulbF: double.parse(r[idx['expected_wet_bulb_f']!] as String),
        toleranceC: double.parse(r[idx['tolerance_c']!] as String),
        notes: r[idx['notes']!] as String,
      )).toList(growable: false);
}

List<FlagMappingFixtureRow> loadFlagMappingFixtures() {
  final csv = _readBundledFixture('flag-mapping.fixtures.csv')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
      .convert(csv);
  final header = rows.first.map((e) => e.toString()).toList();
  final idx = {for (var i = 0; i < header.length; i++) header[i]: i};
  return rows.skip(1).map((r) => FlagMappingFixtureRow(
        id: r[idx['id']!] as String,
        sourceRef: r[idx['source_ref']!] as String,
        wetBulbF: double.parse(r[idx['wet_bulb_f']!] as String),
        expectedFlag: parseEnvironmentalFlag(r[idx['expected_flag']!] as String),
        expectedFlagDartLabel:
            parseHeatRiskLevelLabel(r[idx['expected_flag_dart_label']!] as String),
        notes: r[idx['notes']!] as String,
      )).toList(growable: false);
}

List<RefugeBreakFixtureRow> loadRefugeBreakFixtures() {
  final csv = _readBundledFixture('refuge-break.fixtures.csv')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
      .convert(csv);
  final header = rows.first.map((e) => e.toString()).toList();
  final idx = {for (var i = 0; i < header.length; i++) header[i]: i};
  return rows.skip(1).map((r) {
    final cyclesRaw = r[idx['expected_cycles_until_reassess_required']!] as String;
    return RefugeBreakFixtureRow(
      id: r[idx['id']!] as String,
      sourceRef: r[idx['source_ref']!] as String,
      flag: parseEnvironmentalFlag(r[idx['flag']!] as String),
      acclimatized: (r[idx['acclimatized']!] as String) == 'true',
      workMinutesRequested:
          int.parse(r[idx['work_minutes_requested']!] as String),
      expectedWorkMinutes:
          int.parse(r[idx['expected_work_minutes']!] as String),
      expectedRestMinutes:
          int.parse(r[idx['expected_rest_minutes']!] as String),
      expectedCyclesUntilReassessRequired:
          cyclesRaw.isEmpty ? null : int.parse(cyclesRaw),
      expectedCeaseWork: (r[idx['expected_cease_work']!] as String) == 'true',
      notes: r[idx['notes']!] as String,
    );
  }).toList(growable: false);
}

List<CascadeFixtureRow> loadCascadeFixtures() {
  // Locate cascade-replay dir same way as _readBundledFixture but for a dir.
  final libFile = Directory.current;
  Directory? cascadeDir;
  for (var dir = libFile; dir.path != dir.parent.path; dir = dir.parent) {
    final candidate = File('${dir.path}/.dart_tool/package_config.json');
    if (candidate.existsSync()) {
      final cfgText = candidate.readAsStringSync();
      final match = RegExp(
        r'"name":\s*"heat_engine_spec"[^}]*"rootUri":\s*"([^"]+)"',
      ).firstMatch(cfgText);
      if (match != null) {
        final root = Uri.parse(match.group(1)!);
        final base = root.isAbsolute
            ? root
            : Uri.directory('${dir.path}/.dart_tool/').resolveUri(root);
        final tryDir = Directory.fromUri(base.resolve('lib/fixtures/cascade-replay/'));
        if (tryDir.existsSync()) {
          cascadeDir = tryDir;
          break;
        }
      }
    }
  }
  if (cascadeDir == null) {
    throw StateError(
      'heat_engine_spec: could not locate bundled lib/fixtures/cascade-replay/ — '
      'ensure heat_engine_spec is in dev_dependencies and `dart pub get` has run.',
    );
  }

  final files = cascadeDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final out = <CascadeFixtureRow>[];
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final raw = file.readAsStringSync();
    final parsed = jsonDecode(raw) as Map<String, Object?>;
    final rows = parsed['rows'] as List<Object?>;
    for (final row in rows) {
      final r = row as Map<String, Object?>;
      final input = r['input'] as Map<String, Object?>;
      final ctx = r['ctx'] as Map<String, Object?>;
      final responses = (ctx['responses'] as List<Object?>)
          .cast<Map<String, Object?>>()
          .map((rr) => CascadeReplayResponse(
                urlPattern: rr['url_pattern'] as String,
                status: rr['status'] as int,
                bodyJson: rr['body_json'],
                bodyText: rr['body_text'] as String?,
                simulate: rr['simulate'] as String?,
              ))
          .toList(growable: false);
      final expectedResultRaw = r['expectedResult'];
      CascadeResult? expectedResult;
      if (expectedResultRaw != null) {
        final sm = (expectedResultRaw as Map<String, Object?>)['sample'] as Map<String, Object?>;
        expectedResult = CascadeResult(
          sample: WeatherSample(
            tempC: (sm['tempC'] as num).toDouble(),
            rhPercent: (sm['rhPercent'] as num).toDouble(),
            windMps: sm['windMps'] == null ? null : (sm['windMps'] as num).toDouble(),
            source: weatherSourceFromWire(sm['source'] as String),
          ),
        );
      }
      out.add(CascadeFixtureRow(
        id: r['id'] as String,
        description: r['description'] as String,
        input: CascadeRequest(
          lat: (input['lat'] as num).toDouble(),
          lng: (input['lng'] as num).toDouble(),
          isoTimestamp: input['isoTimestamp'] as String?,
        ),
        clockIso: ctx['clock_iso'] as String,
        responses: responses,
        expectedResult: expectedResult,
        expectedAudit: r['expectedAudit'] as Map<String, Object?>,
        fileName: name,
      ));
    }
  }
  return out;
}

List<VerdictFixtureRow> loadVerdictFixtures() {
  final csv = _readBundledFixture('verdict-promotion.fixtures.csv')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
      .convert(csv);
  final header = rows.first.map((e) => e.toString()).toList();
  final idx = {for (var i = 0; i < header.length; i++) header[i]: i};
  return rows.skip(1).map((r) {
    final priorVerdictRaw = r[idx['prior_verdict']!] as String;
    final priorFlagRaw = r[idx['prior_flag']!] as String;
    return VerdictFixtureRow(
      id: r[idx['id']!] as String,
      sourceRef: r[idx['source_ref']!] as String,
      priorVerdict: priorVerdictRaw.isEmpty ? null : parseVerdict(priorVerdictRaw),
      priorFlag: priorFlagRaw.isEmpty ? null : parseEnvironmentalFlag(priorFlagRaw),
      currentFlag: parseEnvironmentalFlag(r[idx['current_flag']!] as String),
      hasAlternateAvailable:
          (r[idx['has_alternate_available']!] as String) == 'true',
      expectedVerdict: parseVerdict(r[idx['expected_verdict']!] as String),
      expectedChangedFromPrior:
          (r[idx['expected_changed_from_prior']!] as String) == 'true',
      expectedPromotionRule:
          parsePromotionRule(r[idx['expected_promotion_rule']!] as String),
      notes: r[idx['notes']!] as String,
    );
  }).toList(growable: false);
}
