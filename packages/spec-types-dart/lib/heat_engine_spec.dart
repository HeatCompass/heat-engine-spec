/// Public API for `heat_engine_spec`.
///
/// Re-exports tier 1 types + fixture loaders + Approach B audit envelope.
/// Consumers import this single file.
library;

export 'src/types.dart';
export 'src/fixtures.dart';

// Approach B audit envelope (added in v0.1.0 for the full pure-function core).
export 'src/spec_version.dart';
export 'src/canonical_json.dart';
export 'src/audit.dart' hide auditNumber;

// Module reference impls (Phase B onward).
export 'src/wetbulb.dart';
export 'src/flag.dart';
export 'src/refuge_break.dart';
export 'src/verdict.dart';
export 'src/cascade.dart';
