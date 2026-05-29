/// Single source of truth for the spec version. Bumped per CHANGELOG.md
/// entry. The release workflow asserts this matches the git tag at publish
/// time; the TypeScript side's specVersion.ts must also match.
const String specVersion = '0.1.1';
