import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from '@jest/globals';

describe('firestore rules anti-enumeration guardrails', () => {
  const rulesPath = path.resolve(__dirname, '../../firestore.rules');
  const rules = fs.readFileSync(rulesPath, 'utf8');

  it('disables users list queries to block enumeration attacks', () => {
    expect(rules).toContain('match /users/{userId}');
    expect(rules).toContain('allow list: if false;');
  });

  it('restricts users doc reads to self only', () => {
    expect(rules).toContain('allow get: if isAuthenticated() && userId == currentUid();');
  });

  it('defines publicProfiles collection with authenticated reads', () => {
    expect(rules).toContain('match /publicProfiles/{userId}');
    expect(rules).toContain('allow get: if isAuthenticated();');
  });

  it('enforces strict publicProfiles write ownership', () => {
    expect(rules).toContain('allow create, update: if isAuthenticated()');
    expect(rules).toContain('&& userId == currentUid()');
  });

  it('limits publicProfiles fields via allowlist validator', () => {
    expect(rules).toContain('function safePublicProfileFieldsOnly(data)');
    expect(rules).toContain("'name'");
    expect(rules).toContain("'phone_optional'");
    expect(rules).toContain("'rating'");
    expect(rules).toContain("'profileImage'");
  });
});
