#!/usr/bin/env node

require('dotenv').config();

const admin = require('firebase-admin');

const RAPIDAPI_KEY = process.env.RAPIDAPI_KEY;
const EXERCISEDB_HOST = process.env.EXERCISEDB_HOST || 'exercisedb.p.rapidapi.com';
const EXERCISEDB_ENDPOINT = process.env.EXERCISEDB_ENDPOINT || '/exercises?limit=0';
const FIREBASE_SERVICE_ACCOUNT = process.env.FIREBASE_SERVICE_ACCOUNT;
const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID;
const EXERCISE_COLLECTION = process.env.EXERCISE_COLLECTION || 'exercise_library';
const WRITE_MEDIA_SUBCOLLECTION = process.env.WRITE_MEDIA_SUBCOLLECTION === 'true';
const DRY_RUN = process.argv.includes('--dry-run');

if (!RAPIDAPI_KEY) {
  throw new Error('Missing RAPIDAPI_KEY. Copy .env.example to .env and fill it in.');
}

function initFirebase() {
  if (DRY_RUN) return null;

  if (FIREBASE_SERVICE_ACCOUNT) {
    const serviceAccount = require(require('path').resolve(FIREBASE_SERVICE_ACCOUNT));
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

function slugify(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function uniqueList(values) {
  return [...new Set((values || []).filter(Boolean).map((v) => normalizeToken(v)))];
}

function normalizeToken(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/&/g, 'and')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function toArray(value) {
  if (Array.isArray(value)) return value;
  if (value == null || value === '') return [];
  return [value];
}

function inferDifficulty(exercise) {
  const equipment = uniqueList([
    exercise.equipment,
    ...(exercise.equipments || []),
  ]);
  if (equipment.includes('body_weight') || equipment.includes('bodyweight')) return 'beginner';
  if (equipment.some((eq) => ['barbell', 'cable', 'smith_machine'].includes(eq))) return 'advanced';
  return 'intermediate';
}

function inferCategory(exercise) {
  const type = normalizeToken(exercise.exerciseType || exercise.category);
  if (type) return type;
  const bodyParts = uniqueList([exercise.bodyPart, ...(exercise.bodyParts || [])]);
  if (bodyParts.includes('cardio')) return 'cardio';
  return 'strength';
}

function mapToAppBodyParts(tokens) {
  const mapped = new Set();
  for (const token of tokens) {
    if (['chest', 'pectorals'].includes(token)) mapped.add('chest');
    if (['back', 'lats', 'traps', 'upper_back', 'spine'].includes(token)) mapped.add('back');
    if (['shoulders', 'delts'].includes(token)) mapped.add('shoulders');
    if (['biceps', 'upper_arms'].includes(token)) mapped.add('biceps');
    if (['triceps', 'upper_arms'].includes(token)) mapped.add('triceps');
    if (['quads', 'quadriceps', 'adductors', 'abductors', 'upper_legs'].includes(token)) mapped.add('quads');
    if (['hamstrings', 'upper_legs'].includes(token)) mapped.add('hamstrings');
    if (['glutes'].includes(token)) mapped.add('glutes');
    if (['abs', 'core', 'waist'].includes(token)) mapped.add('core');
    if (['forearms', 'lower_arms'].includes(token)) mapped.add('forearms');
  }
  return [...mapped];
}

function mediaTypeFor(url, fallback = 'image') {
  const lower = String(url || '').toLowerCase();
  if (lower.endsWith('.gif')) return 'gif';
  if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.webm')) return 'video';
  return fallback;
}

function buildMediaItems(exercise, exerciseId) {
  const media = [];
  const imageUrl = exercise.imageUrl || exercise.thumbnailUrl || exercise.image || null;
  const gifUrl = exercise.gifUrl || exercise.gif || null;
  const videoUrl = exercise.videoUrl || exercise.video || null;

  if (gifUrl) {
    media.push({
      id: `${exerciseId}_gif_primary`,
      exerciseId,
      primaryType: 'gif',
      gifUrl,
      thumbnailUrl: imageUrl || gifUrl,
      provider: 'exercisedb',
      gender: exercise.gender || 'neutral',
      status: 'active',
      isPrimary: true,
    });
  }

  if (videoUrl) {
    media.push({
      id: `${exerciseId}_video_primary`,
      exerciseId,
      primaryType: 'video',
      videoUrl,
      thumbnailUrl: imageUrl,
      provider: 'exercisedb',
      gender: exercise.gender || 'neutral',
      status: 'active',
      isPrimary: media.length === 0,
    });
  }

  if (imageUrl) {
    media.push({
      id: `${exerciseId}_image_primary`,
      exerciseId,
      primaryType: 'image',
      thumbnailUrl: imageUrl,
      provider: 'exercisedb',
      gender: exercise.gender || 'neutral',
      status: 'active',
      isPrimary: media.length === 0,
    });
  }

  return media;
}

function normalizeExercise(exercise) {
  const sourceExerciseId = String(exercise.exerciseId || exercise.id || slugify(exercise.name));
  const name = String(exercise.name || '').trim();
  const id = slugify(name || sourceExerciseId);
  const rawBodyParts = uniqueList([
    exercise.bodyPart,
    ...(exercise.bodyParts || []),
  ]);
  const targetMuscles = uniqueList([
    exercise.target,
    ...(exercise.targetMuscles || []),
  ]);
  const secondaryMuscles = uniqueList(exercise.secondaryMuscles);
  const appBodyParts = mapToAppBodyParts([
    ...rawBodyParts,
    ...targetMuscles,
    ...secondaryMuscles,
  ]);
  const bodyParts = uniqueList([...rawBodyParts, ...appBodyParts]);
  const muscleGroups = uniqueList([...targetMuscles, ...bodyParts, ...secondaryMuscles]);
  const requiredEquipment = uniqueList([
    exercise.equipment,
    ...(exercise.equipments || []),
  ]);
  const instructions = toArray(exercise.instructions).map((item) => String(item));
  const tips = toArray(exercise.exerciseTips || exercise.tips).map((item) => String(item));
  const tags = uniqueList([
    ...(exercise.keywords || []),
    ...bodyParts,
    ...targetMuscles,
    ...requiredEquipment,
    inferCategory(exercise),
  ]);
  const mediaItems = buildMediaItems(exercise, id);

  return {
    id,
    name,
    slug: id,
    description: exercise.overview || exercise.description || '',
    overview: exercise.overview || '',
    instructions: instructions.join('\n'),
    instructionSteps: instructions,
    tips,
    variations: toArray(exercise.variations).map((item) => String(item)),
    relatedExerciseIds: toArray(exercise.relatedExerciseIds).map((item) => String(item)),
    bodyParts,
    targetMuscles,
    secondaryMuscles,
    muscleGroups,
    requiredEquipment,
    difficulty: inferDifficulty(exercise),
    category: inferCategory(exercise),
    exerciseType: inferCategory(exercise),
    media: mediaItems[0] || null,
    mediaItems,
    defaultSets: 3,
    defaultReps: 10,
    restSeconds: 60,
    tags,
    source: 'exercisedb',
    sourceExerciseId,
    sourcePayloadVersion: exercise.exerciseId ? 'v2' : 'v1',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function fetchExercises() {
  const url = `https://${EXERCISEDB_HOST}${EXERCISEDB_ENDPOINT}`;
  const response = await fetch(url, {
    headers: {
      'x-rapidapi-host': EXERCISEDB_HOST,
      'x-rapidapi-key': RAPIDAPI_KEY,
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`ExerciseDB request failed (${response.status}): ${body}`);
  }

  return response.json();
}

async function writeInBatches(db, exercises) {
  let batch = db.batch();
  let pending = 0;
  let written = 0;

  for (const exercise of exercises) {
    const ref = db.collection(EXERCISE_COLLECTION).doc(exercise.id);
    batch.set(ref, exercise, { merge: true });
    pending += 1;

    if (WRITE_MEDIA_SUBCOLLECTION) {
      for (const media of exercise.mediaItems || []) {
        batch.set(ref.collection('media').doc(media.id), {
          ...media,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        pending += 1;
      }
    }

    if (pending >= 430) {
      await batch.commit();
      written += pending;
      batch = db.batch();
      pending = 0;
      console.log(`Wrote ${written} exercises...`);
    }
  }

  if (pending > 0) {
    await batch.commit();
    written += pending;
  }

  return written;
}

async function main() {
  const rawExercises = await fetchExercises();
  const exercises = rawExercises.map(normalizeExercise).filter((exercise) => exercise.id && exercise.name);

  console.log(`Fetched ${rawExercises.length} ExerciseDB records.`);
  console.log(`Normalized ${exercises.length} Firestore exercise documents.`);

  if (DRY_RUN) {
    console.log(JSON.stringify(exercises.slice(0, 3), null, 2));
    return;
  }

  const db = initFirebase();
  const written = await writeInBatches(db, exercises);
  console.log(`Seeded ${written} exercises to ${EXERCISE_COLLECTION}.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
