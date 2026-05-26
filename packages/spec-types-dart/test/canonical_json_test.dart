import 'package:test/test.dart';
import 'package:heat_engine_spec/src/canonical_json.dart';

void main() {
  group('canonicalJson', () {
    test('sorts object keys alphabetically', () {
      expect(canonicalJson({'b': 1, 'a': 2}), '{"a":2,"b":1}');
    });

    test('sorts nested object keys', () {
      expect(
        canonicalJson({
          'outer': {'z': 1, 'a': 2},
        }),
        '{"outer":{"a":2,"z":1}}',
      );
    });

    test('preserves array order', () {
      expect(canonicalJson([3, 1, 2]), '[3,1,2]');
    });

    test('emits null as null', () {
      expect(canonicalJson({'x': null}), '{"x":null}');
    });

    test('emits integers without decimal point', () {
      expect(canonicalJson({'n': 5}), '{"n":5}');
    });

    test('emits floats with their natural representation', () {
      expect(canonicalJson({'n': 1.5}), '{"n":1.5}');
    });

    test('emits whole-valued doubles like ints (mirrors TS)', () {
      expect(canonicalJson({'n': 5.0}), '{"n":5}');
    });

    test('emits booleans as true/false', () {
      expect(canonicalJson({'t': true, 'f': false}), '{"f":false,"t":true}');
    });

    test('handles deeply nested mixed content', () {
      expect(
        canonicalJson({
          'z': [
            {'b': 1, 'a': 2},
          ],
          'a': null,
        }),
        '{"a":null,"z":[{"a":2,"b":1}]}',
      );
    });

    test('escapes strings via standard JSON quoting', () {
      expect(canonicalJson({'s': 'a"b\\c'}), '{"s":"a\\"b\\\\c"}');
    });
  });
}
