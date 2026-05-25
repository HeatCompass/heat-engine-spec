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
        final base = root.isAbsolute
            ? root
            : Uri.directory('${dir.path}/.dart_tool/').resolveUri(root);
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
