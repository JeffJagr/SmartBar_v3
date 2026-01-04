
// seed_staff.js
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json'); // download from Firebase console

const companyId = '1234';
const authUid = 'Nikita'; // anonymous auth UID you’ll use when logging in via PIN
const staffId = 'Nikita'; // logical staff id if you track it separately
const role = 'manager'; // or 'staff'
const permissions = {
  editProducts: true,
  adjustQuantities: true,
  createOrders: true,
  confirmOrders: true,
  receiveOrders: true,
  transferStock: true,
  setRestockHint: true,
  viewHistory: true,
  addNotes: true,
  manageUsers: false,
};

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

async function seed() {
  await db.collection('companies').doc(companyId).collection('users').doc(authUid).set({
    role,
    permissions,
    active: true,
    displayName: 'Test Staff',
    updatedAt: new Date(),
  }, { merge: true });

  await db.collection('companies').doc(companyId).collection('staffSessions').doc(authUid).set({
    companyId,
    staffId,
    role,
    permissions,
    createdAt: new Date(),
  }, { merge: true });

  await db.collection('users').doc(authUid).set({
    role,
    companyId,
    displayName: 'Test Staff',
    permissions,
    createdAt: new Date(),
  }, { merge: true });

  console.log('Seeded staff user with permissions');
}

seed().catch(console.error);
