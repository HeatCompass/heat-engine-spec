import { describe, it, expect } from 'vitest';
import { canonicalJson } from '../src/canonicalJson.js';

describe('canonicalJson', () => {
  it('sorts object keys alphabetically', () => {
    expect(canonicalJson({ b: 1, a: 2 })).toBe('{"a":2,"b":1}');
  });

  it('sorts nested object keys', () => {
    expect(canonicalJson({ outer: { z: 1, a: 2 } })).toBe(
      '{"outer":{"a":2,"z":1}}',
    );
  });

  it('preserves array order', () => {
    expect(canonicalJson([3, 1, 2])).toBe('[3,1,2]');
  });

  it('emits null as null', () => {
    expect(canonicalJson({ x: null })).toBe('{"x":null}');
  });

  it('emits integers without decimal point', () => {
    expect(canonicalJson({ n: 5 })).toBe('{"n":5}');
  });

  it('emits floats with their natural representation', () => {
    expect(canonicalJson({ n: 1.5 })).toBe('{"n":1.5}');
  });

  it('emits booleans as true/false', () => {
    expect(canonicalJson({ t: true, f: false })).toBe('{"f":false,"t":true}');
  });

  it('handles deeply nested mixed content', () => {
    expect(canonicalJson({ z: [{ b: 1, a: 2 }], a: null })).toBe(
      '{"a":null,"z":[{"a":2,"b":1}]}',
    );
  });

  it('escapes strings via standard JSON quoting', () => {
    expect(canonicalJson({ s: 'a"b\\c' })).toBe('{"s":"a\\"b\\\\c"}');
  });

  it('drops undefined-valued properties', () => {
    expect(canonicalJson({ a: 1, b: undefined, c: 3 })).toBe('{"a":1,"c":3}');
  });
});
