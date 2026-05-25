import { describe, it, expect } from 'vitest';
import {
  loadWetBulbFixtures,
  loadFlagMappingFixtures,
  type WetBulbFixtureRow,
  type FlagMappingFixtureRow,
} from '../src/index.js';

describe('tier 1 fixture loaders', () => {
  it('loadWetBulbFixtures returns >= 30 rows with correctly typed numeric fields', () => {
    const rows: WetBulbFixtureRow[] = loadWetBulbFixtures();
    expect(rows.length).toBeGreaterThanOrEqual(30);
    const first = rows[0];
    expect(typeof first.id).toBe('string');
    expect(typeof first.sourceRef).toBe('string');
    expect(typeof first.tempC).toBe('number');
    expect(typeof first.rhPercent).toBe('number');
    expect(typeof first.expectedWetBulbC).toBe('number');
    expect(typeof first.expectedWetBulbF).toBe('number');
    expect(typeof first.toleranceC).toBe('number');
    expect(typeof first.notes).toBe('string');
  });

  it('loadFlagMappingFixtures returns >= 20 rows with valid flag enums', () => {
    const rows: FlagMappingFixtureRow[] = loadFlagMappingFixtures();
    expect(rows.length).toBeGreaterThanOrEqual(20);
    const validFlags = ['white', 'green', 'yellow', 'red', 'black'];
    const validDartLabels = ['low', 'moderate', 'high', 'extreme', 'critical'];
    for (const row of rows) {
      expect(typeof row.wetBulbF).toBe('number');
      expect(validFlags).toContain(row.expectedFlag);
      expect(validDartLabels).toContain(row.expectedFlagDartLabel);
    }
  });
});
