/**
 * Deduplicate legacy staff records created before stable staffId logins.
 *
 * Dry-run by default. Use `--apply` to commit changes.
 * Examples:
 *   node tools/dedupe_staff.js --companyCode=VUE123
 *   node tools/dedupe_staff.js --companyId=abcd123 --apply
 */
/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function loadServiceAccount() {
  const candidate = path.resolve(__dirname, '../serviceAccountKey.json');
  if (!fs.existsSync(candidate)) {
    throw new Error('serviceAccountKey.json not found; place it in repo root.');
  }
  return require(candidate);
}

function parseArgs() {
  const args = process.argv.slice(2);
  const out = { apply: false };
  for (const arg of args) {
    if (arg === '--apply') out.apply = true;
    else if (arg.startsWith('--companyId=')) out.companyId = arg.split('=')[1];
    else if (arg.startsWith('--companyCode=')) out.companyCode = arg.split('=')[1];
  }
  if (!out.companyId && !out.companyCode) {
    throw new Error('Provide --companyId or --companyCode');
  }
  return out;
}

async function resolveCompanyId(db, companyId, companyCode) {
  if (companyId) return companyId;
  const snap = await db
    .collection('companies')
    .where('companyCode', '==', companyCode.trim().toUpperCase())
    .limit(1)
    .get();
  if (snap.empty) {
    throw new Error(`Company not found for code ${companyCode}`);
  }
  return snap.docs[0].id;
}

function mergePermissions(a = {}, b = {}) {
  const out = { ...a };
  for (const [k, v] of Object.entries(b)) {
    if (v === true) out[k] = true;
  }
  return out;
}

async function main() {
  const { apply, companyId: argCompanyId, companyCode } = parseArgs();
  admin.initializeApp({
    credential: admin.credential.cert(loadServiceAccount()),
  });
  const db = admin.firestore();

  const companyId = await resolveCompanyId(db, argCompanyId, companyCode);
  console.log(`Target company: ${companyId} (${companyCode || 'id provided'})`);

  const staffPinsSnap = await db
    .collection('staffPins')
    .where('companyId', '==', companyId)
    .get();
  const keepIds = new Set(staffPinsSnap.docs.map((d) => d.id));
  const pinData = Object.fromEntries(staffPinsSnap.docs.map((d) => [d.id, d.data()]));
  console.log(`Found ${keepIds.size} staffPins to keep`);

  const usersSnap = await db.collection('companies').doc(companyId).collection('users').get();
  const duplicates = [];
  const updates = [];
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const id = doc.id;
    if (keepIds.has(id)) {
      // Merge canonical data from staffPins if missing.
      const pin = pinData[id] || {};
      const mergedPerms = mergePermissions(data.permissions, pin.permissions);
      const role = data.role || pin.role || 'staff';
      const displayName = data.displayName || pin.displayName || 'Staff';
      const needsUpdate =
        role !== data.role ||
        displayName !== data.displayName ||
        JSON.stringify(mergedPerms) !== JSON.stringify(data.permissions || {});
      if (needsUpdate) {
        updates.push({ id, data: { role, displayName, permissions: mergedPerms } });
      }
      continue;
    }
    // If this doc was created with an authUid that maps to a canonical staffId, mark as duplicate.
    const authTarget = data.lastAuthUid && keepIds.has(data.lastAuthUid) ? data.lastAuthUid : null;
    if (authTarget) {
      duplicates.push({
        id,
        canonical: authTarget,
        displayName: data.displayName,
        role: data.role,
      });
      // Merge any missing permissions into canonical update set.
      const pin = pinData[authTarget] || {};
      const mergedPerms = mergePermissions(pin.permissions, data.permissions);
      updates.push({
        id: authTarget,
        data: {
          permissions: mergedPerms,
          role: pin.role || data.role || 'staff',
          displayName: pin.displayName || data.displayName || 'Staff',
        },
      });
    }
  }

  // De-dupe updates by id.
  const updateById = new Map();
  for (const u of updates) {
    const existing = updateById.get(u.id);
    if (!existing) updateById.set(u.id, u.data);
    else updateById.set(u.id, { ...existing, ...u.data });
  }

  console.log(`Planned updates for canonical users: ${updateById.size}`);
  console.log(`Planned deletes for duplicates: ${duplicates.length}`);
  if (!apply) {
    console.log('Dry run only. Re-run with --apply to commit.');
    return;
  }

  const batch = db.batch();
  const usersCol = db.collection('companies').doc(companyId).collection('users');
  for (const [id, data] of updateById.entries()) {
    batch.set(usersCol.doc(id), { ...data, id, active: true }, { merge: true });
    batch.set(db.collection('users').doc(id), { ...data, companyId }, { merge: true });
    batch.set(db.collection('staffPins').doc(id), data, { merge: true });
  }
  for (const dup of duplicates) {
    batch.delete(usersCol.doc(dup.id));
    batch.delete(db.collection('users').doc(dup.id));
  }
  await batch.commit();
  console.log('Cleanup complete.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
