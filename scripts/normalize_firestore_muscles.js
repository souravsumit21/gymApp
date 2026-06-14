#!/usr/bin/env node
/**
 * Normalize muscleGroups + secondaryMuscles on existing exercise_library docs.
 * Does not touch media URLs — safe to run after metadata drift.
 *
 * Usage:
 *   node scripts/normalize_firestore_muscles.js --dry-run
 *   node scripts/normalize_firestore_muscles.js
 */

require('dotenv').config();

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { canonicalizeExerciseMuscles } = require('./lib/muscle_normalization');

const FIREBASE_SERVICE_ACCOUNT = process.env.FIREBASE_SERVICE_ACCOUNT;
const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'forge-fit-ccdde';
const EXERCISE_COLLECTION = process.env.EXERCISE_COLLECTION || 'exercise_library';
const DRY_RUN = process.argv.includes('--dry-run');

function initFirebase() {
  if (FIREBASE_SERVICE_ACCOUNT) {
    const serviceAccountPath = path.resolve(FIREBASE_SERVICE_ACCOUNT);
    if (!fs.existsSync(serviceAccountPath)) {
      throw new Error(`Service account not found: ${serviceAccountPath}`);
    }
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: FIREBASE_PROJECT_ID || serviceAccount.project_id,
    });
  } else {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: FIREBASE_PROJECT_ID,
    });
  }

  return admin.firestore();
}

function toStringList(value) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => String(item)).filter(Boolean);
}

function musclesChanged(before, after) {
  const left = [...before].sort().join('|');
  const right = [...after].sort().join('|');
  return left !== right;
}

async function main() {
  const db = initFirebase();

  if (DRY_RUN) {
    console.log('DRY RUN — scanning only, no writes');
  }

  const snapshot = await db.collection(EXERCISE_COLLECTION).get();
  console.log(`Loaded ${snapshot.size} documents from ${EXERCISE_COLLECTION}`);

  let batch = db.batch();
  let pending = 0;
  let updated = 0;
  let unchanged = 0;
  const samples = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const rawPrimary = toStringList(data.muscleGroups || data.targetMuscles || data.bodyParts);
    const rawSecondary = toStringList(data.secondaryMuscles);
    const { muscleGroups, secondaryMuscles } = canonicalizeExerciseMuscles(
      rawPrimary,
      rawSecondary,
    );

    const primaryChanged = musclesChanged(rawPrimary, muscleGroups);
    const secondaryChanged = musclesChanged(rawSecondary, secondaryMuscles);

    if (!primaryChanged && !secondaryChanged) {
      unchanged += 1;
      continue;
    }

    if (samples.length < 3) {
      samples.push({
        id: doc.id,
        before: { muscleGroups: rawPrimary, secondaryMuscles: rawSecondary },
        after: { muscleGroups, secondaryMuscles },
      });
    }

    if (DRY_RUN) {
      updated += 1;
      continue;
    }

    batch.set(
      doc.ref,
      {
        muscleGroups,
        secondaryMuscles,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    pending += 1;
    updated += 1;

    if (pending >= 400) {
      await batch.commit();
      console.log(`Updated ${updated} documents so far...`);
      batch = db.batch();
      pending = 0;
    }
  }

  if (!DRY_RUN && pending > 0) {
    await batch.commit();
  }

  if (samples.length > 0) {
    console.log('\n--- Sample changes ---');
    console.log(JSON.stringify(samples, null, 2));
  }

  console.log(
    DRY_RUN
      ? `Dry run complete. Would update ${updated}, unchanged ${unchanged}.`
      : `Done. Updated ${updated}, unchanged ${unchanged}.`,
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
