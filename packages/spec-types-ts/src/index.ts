export * from './types.js';
export { loadWetBulbFixtures, loadFlagMappingFixtures } from './fixtures.js';

// Approach B audit envelope (added in v0.1.0 for the full pure-function core).
export { SPEC_VERSION } from './specVersion.js';
export { canonicalJson } from './canonicalJson.js';
export {
  buildAudit,
  type AuditRecord,
  type SourceAttempt,
  type WeatherSource,
  type SpecContext,
  type SpecReturn,
  type HttpAdapter,
} from './audit.js';
