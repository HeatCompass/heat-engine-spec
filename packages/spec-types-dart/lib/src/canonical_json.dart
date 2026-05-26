/// Canonical JSON serializer used to byte-compare audit records across
/// TypeScript and Dart impls. Rules:
///   * object keys sorted alphabetically (recursively)
///   * `null`-valued properties are kept (matches TS behavior for null;
///     `undefined`-style absent values are not representable in Dart)
///   * arrays preserve declared order
///   * integers serialized without decimal point ('5'); floats with their
///     natural representation ('1.5')
///   * strings JSON-escaped via the standard rules
///
/// This function is the cross-language equivalence keystone for the audit
/// envelope's byte-equality CI gate. Any divergence between TS and Dart
/// outputs here will surface as a conformance failure.
String canonicalJson(Object? value) => _serialize(value);

String _serialize(Object? v) {
  if (v == null) return 'null';
  if (v is String) return _encodeString(v);
  if (v is bool) return v ? 'true' : 'false';
  if (v is int) return v.toString();
  if (v is double) {
    if (v.isNaN || v.isInfinite) return _encodeString(v.toString());
    if (v == v.truncateToDouble()) {
      // Mirror TS String(5.0) === '5' behavior.
      return v.toInt().toString();
    }
    return v.toString();
  }
  if (v is List) {
    return '[${v.map(_serialize).join(',')}]';
  }
  if (v is Map) {
    final entries = v.entries.toList()
      ..sort((a, b) => (a.key as String).compareTo(b.key as String));
    final body = entries
        .map((e) => '${_encodeString(e.key as String)}:${_serialize(e.value)}')
        .join(',');
    return '{$body}';
  }
  throw ArgumentError('canonicalJson: unsupported type ${v.runtimeType}');
}

String _encodeString(String s) {
  final out = StringBuffer('"');
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    switch (c) {
      case 0x22:
        out.write(r'\"');
        break;
      case 0x5C:
        out.write(r'\\');
        break;
      case 0x08:
        out.write(r'\b');
        break;
      case 0x0C:
        out.write(r'\f');
        break;
      case 0x0A:
        out.write(r'\n');
        break;
      case 0x0D:
        out.write(r'\r');
        break;
      case 0x09:
        out.write(r'\t');
        break;
      default:
        if (c < 0x20) {
          out.write('\\u');
          out.write(c.toRadixString(16).padLeft(4, '0'));
        } else {
          out.writeCharCode(c);
        }
    }
  }
  out.write('"');
  return out.toString();
}
