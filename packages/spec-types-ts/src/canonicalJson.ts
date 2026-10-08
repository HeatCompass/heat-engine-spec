// Canonical JSON serializer used to byte-compare audit records across
// TypeScript and Dart impls. Rules:
//   * object keys sorted alphabetically (recursively)
//   * `undefined`-valued properties are dropped (matches JSON.stringify)
//   * arrays preserve declared order
//   * numbers serialized with JavaScript's native `String(n)` (integers as
//     '5', floats as '1.5'); Dart impl mirrors this convention. NaN and
//     ±Infinity are written as the strings "NaN", "Infinity", "-Infinity"
//   * strings JSON-escaped via the standard JSON.stringify
//
// This function is the cross-lang equivalence keystone for the audit
// envelope's byte-equality CI gate. Any divergence between TS and Dart
// outputs here will surface as a conformance failure.
export function canonicalJson(value: unknown): string {
  return serialize(value);
}

function serialize(v: unknown): string {
  if (v === null) return 'null';
  if (typeof v === 'string') return JSON.stringify(v);
  if (typeof v === 'number') {
    // JSON has no NaN or Infinity; write them as strings, as the Dart
    // serializer does, instead of JSON.stringify's null.
    if (!Number.isFinite(v)) return JSON.stringify(String(v));
    return String(v);
  }
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  if (Array.isArray(v)) return '[' + v.map(serialize).join(',') + ']';
  if (typeof v === 'object') {
    const obj = v as Record<string, unknown>;
    const keys = Object.keys(obj).filter((k) => obj[k] !== undefined).sort();
    return (
      '{' +
      keys.map((k) => JSON.stringify(k) + ':' + serialize(obj[k])).join(',') +
      '}'
    );
  }
  return JSON.stringify(v);
}
