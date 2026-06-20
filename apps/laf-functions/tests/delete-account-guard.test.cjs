const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const sourcePath = path.resolve(__dirname, '../paperbanana-api.ts');
const source = fs.readFileSync(sourcePath, 'utf8');

// Account deletion (App Store guideline 5.1.1(v)) must be an identity-scoped
// action so it only runs through the auth-gateway (or admin tooling) and never
// from a forged direct call.
const setMatch = source.match(/const identityScopedActions = new Set\(\[([\s\S]*?)\]\)/);
assert.ok(setMatch, 'identityScopedActions set must exist.');
assert.ok(
  setMatch[1].includes("'deleteAccount'"),
  'identityScopedActions must include deleteAccount.',
);

// Dispatch must route the deleteAccount action.
assert.ok(
  /if \(action === 'deleteAccount'\) \{\s*return await deleteAccount\(body as DeleteAccountBody\)/.test(source),
  'Dispatch must route deleteAccount to the deleteAccount handler.',
);

// The handler must hard-delete jobs and feedback for the user.
assert.ok(
  source.includes('async function deleteAccount('),
  'deleteAccount handler must be defined.',
);
assert.ok(
  /jobs\.deleteMany\(/.test(source),
  'deleteAccount must deleteMany on the jobs collection.',
);
assert.ok(
  /feedback\.deleteMany\(/.test(source),
  'deleteAccount must deleteMany on the feedback collection.',
);

// Reference-image purge must be best-effort: it must not throw out of the
// handler (errors are logged and swallowed).
assert.ok(
  source.includes('deleteReferenceObjectsForOwner'),
  'deleteAccount must best-effort purge reference objects via deleteReferenceObjectsForOwner.',
);
assert.ok(
  /deleteReferenceObjectsForOwner[\s\S]*?console\.warn/.test(source),
  'Reference-object deletion failures must be logged, not thrown.',
);

// Result is reported with the documented counts.
assert.ok(
  source.includes('deletedJobCount') && source.includes('deletedFeedbackCount'),
  'deleteAccount must return deletedJobCount and deletedFeedbackCount.',
);

console.log('delete-account-guard policy ok');
