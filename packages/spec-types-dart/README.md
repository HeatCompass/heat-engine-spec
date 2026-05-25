# heat_engine_spec

Dart types + fixture loaders for the [heat-engine-spec](https://github.com/HeatCompass/heat-engine-spec) contract.

Tier 1 (v0.1.0) covers:
- Wet-bulb temperature (Stull 2011)
- USMC 6200.1E environmental-flag mapping

## Usage

```dart
import 'package:heat_engine_spec/heat_engine_spec.dart';

void main() {
  final fixtures = loadWetBulbFixtures();
  for (final fx in fixtures) {
    // Compare your implementation's output against fx.expectedWetBulbC
    // within fx.toleranceC.
  }
}
```
