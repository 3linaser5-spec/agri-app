const test = require('node:test');
const assert = require('node:assert/strict');
const {
  assertSucceeds,
  assertFails,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, serverTimestamp } = require('firebase/firestore');
const fs = require('node:fs');

const PROJECT_ID = 'agri-rules-test';
let env;

const project = (owner_id) => ({
  owner_id,
  id: 'project-1',
  name_ar: 'مشروع اختبار',
  name_en: 'Test project',
});

async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

async function user(uid, extra = {}) {
  return env.authenticatedContext(uid, extra).firestore();
}

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: fs.readFileSync('../firebase/firestore.rules', 'utf8') },
  });
  await seed('users/u1/map_alerts/a1', {
    status: 'open', resolved: false, updated_at: new Date(),
  });
  await seed('users/u1/map_alerts/a1/inspection_notes/n1', {
    text: 'فحص سابق', created_at: new Date(),
  });
  await seed('irrigationDesignProjects/p1', project('u1'));
  await seed('irrigationDesignProjects/p1/versions/v1', { owner_id: 'u1', label: 'v1' });
});

test.after(async () => env.cleanup());

test('active landscape entitlement can read and update its map alert', async () => {
  await seed('service_entitlements/u1/services/irrigation_landscape_satellite', { status: 'active' });
  const db = await user('u1');
  await assertSucceeds(getDoc(doc(db, 'users/u1/map_alerts/a1')));
  await assertSucceeds(updateDoc(doc(db, 'users/u1/map_alerts/a1'), {
    status: 'inspected', resolved: false, updated_at: serverTimestamp(),
  }));
});

test('user without entitlement cannot read notes or alerts', async () => {
  const db = await user('u2');
  await assertFails(getDoc(doc(db, 'users/u1/map_alerts/a1')));
  await assertFails(getDoc(doc(db, 'users/u1/map_alerts/a1/inspection_notes/n1')));
});

test('a user cannot read another user project or add a child document to it', async () => {
  const db = await user('u2');
  await assertFails(getDoc(doc(db, 'irrigationDesignProjects/p1')));
  await assertFails(setDoc(doc(db, 'irrigationDesignProjects/p1/versions/evil'), {
    owner_id: 'u2', label: 'forbidden',
  }));
});

test('project owner can read and add only own child documents', async () => {
  const db = await user('u1');
  await assertSucceeds(getDoc(doc(db, 'irrigationDesignProjects/p1')));
  await assertSucceeds(setDoc(doc(db, 'irrigationDesignProjects/p1/versions/v2'), {
    owner_id: 'u1', label: 'v2',
  }));
});

test('admin can manage a project child document', async () => {
  await seed('admins/admin1', { role: 'admin' });
  const db = await user('admin1');
  await assertSucceeds(setDoc(doc(db, 'irrigationDesignProjects/p1/satelliteLinks/zone-1'), {
    owner_id: 'u1', zone_id: 'zone-1', field_id: 'field-1',
  }));
});
