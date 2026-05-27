import 'dart:io';

void main() {
  final pkgRoot = Directory.current.path; // run from packages/spec-types-dart
  final specRoot = '$pkgRoot/../../spec/tier1-foundation';
  for (final name in [
    'wet-bulb.fixtures.csv',
    'flag-mapping.fixtures.csv',
    'refuge-break.fixtures.csv',
    'verdict-promotion.fixtures.csv',
  ]) {
    final src = File('$specRoot/$name');
    final dst = File('$pkgRoot/lib/fixtures/$name');
    if (!src.existsSync()) {
      stderr.writeln('source missing: ${src.path}');
      exit(1);
    }
    src.copySync(dst.path);
    stdout.writeln('synced $name');
  }
}
