// Tests for the #12 rules in ../firestore.rules.
// Run with the emulator: `npm run test:emulator` (see README).
//
// Each test acts as one kind of user and checks that Firestore itself
// allows or rejects the request. That proves the backend enforces it,
// not just the app hiding a button.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';

let env;

// The people making requests. The role is the custom claim on the ID token.
const anonymous = () => env.unauthenticatedContext().firestore();
const nurse = () => env.authenticatedContext('nurse1', { role: 'nurse' }).firestore();
const doctor = () => env.authenticatedContext('doctor1', { role: 'doctor' }).firestore();
const noRole = () => env.authenticatedContext('norole1').firestore();
const wrongRole = () => env.authenticatedContext('admin1', { role: 'admin' }).firestore();
const capitalRole = () => env.authenticatedContext('nurse2', { role: 'Nurse' }).firestore();

const patient = 'patients/HPT-TEST01';
const history = 'patients/HPT-TEST01/history/event-1';
const location = 'locations/ward-a';

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-rules-test',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(() => env.cleanup());

// Fresh synthetic data before every test, written with rules switched off
// (like the trusted seed script).
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, patient), { name: 'Test Patient', status: 'Admitted', currentLocation: 'ward-a', version: 1 });
    await setDoc(doc(db, history), { fromLocation: 'er', toLocation: 'ward-a' });
    await setDoc(doc(db, location), { name: 'Ward A' });
    await setDoc(doc(db, 'users/nurse1'), { displayName: 'Nurse One', role: 'nurse' });
    await setDoc(doc(db, 'users/doctor1'), { displayName: 'Doctor One', role: 'doctor' });
  });
});

describe('criterion 1: unauthenticated requests are rejected', () => {
  for (const path of [patient, history, location, 'users/nurse1']) {
    test(`cannot read ${path}`, async () => {
      await assertFails(getDoc(doc(anonymous(), path)));
    });
  }

  test('cannot write a patient', async () => {
    await assertFails(setDoc(doc(anonymous(), patient), { currentLocation: 'er' }));
  });
});

describe('criterion 2: nurses and doctors can read', () => {
  for (const [who, db] of [['nurse', nurse], ['doctor', doctor]]) {
    for (const path of [patient, history, location]) {
      test(`${who} can read ${path}`, async () => {
        await assertSucceeds(getDoc(doc(db(), path)));
      });
    }
  }

  // Signed in is not enough: the role claim must be exactly nurse or doctor.
  for (const [who, db] of [['no role', noRole], ['role "admin"', wrongRole], ['role "Nurse"', capitalRole]]) {
    test(`${who} cannot read patients`, async () => {
      await assertFails(getDoc(doc(db(), patient)));
    });
  }
});

describe('criterion 3: no client can write the role', () => {
  test('a nurse cannot make themselves a doctor', async () => {
    await assertFails(updateDoc(doc(nurse(), 'users/nurse1'), { role: 'doctor' }));
  });

  test('a user without a role cannot create a profile with a role', async () => {
    await assertFails(setDoc(doc(noRole(), 'users/norole1'), { displayName: 'X', role: 'doctor' }));
  });

  test('a doctor cannot change another user', async () => {
    await assertFails(updateDoc(doc(doctor(), 'users/nurse1'), { role: 'doctor' }));
  });

  test('a user can read their own profile', async () => {
    await assertSucceeds(getDoc(doc(nurse(), 'users/nurse1')));
  });

  test("a user cannot read someone else's profile", async () => {
    await assertFails(getDoc(doc(nurse(), 'users/doctor1')));
  });
});

describe('no writes yet (they come in #17, #22, #23)', () => {
  for (const [who, db] of [['nurse', nurse], ['doctor', doctor]]) {
    test(`${who} cannot update a patient`, async () => {
      await assertFails(updateDoc(doc(db(), patient), { currentLocation: 'er' }));
    });

    test(`${who} cannot edit history`, async () => {
      await assertFails(updateDoc(doc(db(), history), { toLocation: 'er' }));
    });

    test(`${who} cannot delete history`, async () => {
      await assertFails(deleteDoc(doc(db(), history)));
    });

    test(`${who} cannot add a location`, async () => {
      await assertFails(setDoc(doc(db(), 'locations/new-ward'), { name: 'New Ward' }));
    });
  }
});
