#!/usr/bin/env node
/**
 * Seed exercise_library Firestore docs from local slugified MP4 filenames.
 * Videos are hosted on Cloudflare R2; this script only writes metadata + URLs.
 *
 * Usage:
 *   node scripts/seed_video_metadata_to_firestore.js --folder Triceps --dry-run
 *   node scripts/seed_video_metadata_to_firestore.js --folder Triceps
 *   node scripts/seed_video_metadata_to_firestore.js --folder Triceps --export ./triceps.json
 *   node scripts/seed_video_metadata_to_firestore.js --all
 */

require('dotenv').config();

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { canonicalizeExerciseMuscles } = require('./lib/muscle_normalization');

const FIREBASE_SERVICE_ACCOUNT = process.env.FIREBASE_SERVICE_ACCOUNT;
const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'forge-fit-ccdde';
const EXERCISE_COLLECTION = process.env.EXERCISE_COLLECTION || 'exercise_library';
const R2_PUBLIC_BASE = (process.env.R2_PUBLIC_BASE || 'https://media.reppup.app').replace(/\/$/, '');
const LOCAL_VIDEOS_DIR = process.env.LOCAL_VIDEOS_DIR
  ? path.resolve(process.env.LOCAL_VIDEOS_DIR)
  : path.resolve(__dirname, '../exercise_videos');

const DRY_RUN = process.argv.includes('--dry-run');
const ALL_FOLDERS = process.argv.includes('--all');

function getArg(flag) {
  const index = process.argv.indexOf(flag);
  if (index === -1 || index === process.argv.length - 1) return null;
  return process.argv[index + 1];
}

const FOLDER_ARG = getArg('--folder');
const EXPORT_PATH = getArg('--export');

/** Local disk folder name → R2 path segment (lowercase). */
const FOLDER_TO_R2 = {
  Abdominals: 'abdominals',
  Back: 'back',
  Biceps: 'biceps',
  Calisthenics: 'calisthenics',
  Chest: 'chest',
  Forearms: 'forearms',
  Legs: 'legs',
  Powerlifting: 'powerlifting',
  Shoulders: 'shoulders',
  Stretching: 'stretching',
  Traps: 'traps',
  Triceps: 'triceps',
  Yoga: 'yoga',
};

/** Folder → primary muscle groups + category defaults. */
const FOLDER_METADATA = {
  Abdominals: { muscleGroups: ['core'], category: 'core' },
  Back: { muscleGroups: ['back'], category: 'strength' },
  Biceps: { muscleGroups: ['biceps'], category: 'strength' },
  Calisthenics: { muscleGroups: [], category: 'strength' },
  Chest: { muscleGroups: ['chest'], category: 'strength' },
  Forearms: { muscleGroups: ['forearms'], category: 'strength' },
  Legs: { muscleGroups: ['quads'], category: 'strength' },
  Powerlifting: { muscleGroups: [], category: 'strength' },
  Shoulders: { muscleGroups: ['shoulders'], category: 'strength' },
  Stretching: { muscleGroups: [], category: 'flexibility' },
  Traps: { muscleGroups: ['shoulders', 'back'], category: 'strength' },
  Triceps: { muscleGroups: ['triceps'], category: 'strength' },
  Yoga: { muscleGroups: [], category: 'flexibility' },
};

// First match wins — list more specific rules before general ones.
const EQUIPMENT_RULES = [
  ['smith_machine', ['smith_machine', '_smith_']],
  ['machine', [
    '_machine', 'machine_', 'lever_', 'hammer_strength', 'lat_pulldown',
    'leg_press', 'leg_extension', 'leg_curl_machine', 'seated_row_machine',
    'hack_squat', 'calf_raise_machine', 'row_machine', 'pulldown_machine',
    'pec_deck', 'adductor_machine', 'abductor_machine', 'glute_kickback_machine',
  ]],
  ['treadmill', ['treadmill']],
  ['stationary_bike', ['stationary_exercise_bike', 'stationary_bike', 'spin_bike', 'assault_bike', 'airbike']],
  ['battle_ropes', ['battle_rope']],
  ['jump_rope', ['jump_rope']],
  ['cable', ['cable']],
  ['ez_bar', ['ez_bar', 'ez_barbell']],
  ['barbell', ['barbell', 'landmine', 'plate_loaded']],
  ['dumbbells', ['dumbbell']],
  ['kettlebell', ['kettlebell']],
  ['medicine_ball', ['medicine_ball', 'weighted_ball', 'wall_ball']],
  ['exercise_ball', ['exercise_ball', 'stability_ball', 'swiss_ball', 'on_ball', '_on_ball']],
  ['bosu', ['bosu']],
  ['ab_wheel', ['ab_wheel']],
  ['resistance_bands', ['resistance_band', 'band_']],
  ['trx', ['suspension', 'trx']],
  ['gymnastic_rings', ['gymnastic_ring', 'gymnastic_rings', 'ring_push_up', 'ring_dip', 'ring_row']],
  ['dip_bars', ['on_dip_station', 'dips_between', 'parallel_bar', 'dip_bar']],
  ['pull_up_bar', ['pull_up_bar', 'pull_up', 'chin_up']],
  ['weight_bench', [
    'on_bench', 'bench_press', 'incline_bench', 'decline_bench',
    'bench_decline', 'bench_knee', 'bench_sit', 'seal_row_on_bench',
  ]],
  ['box', ['plyo_box', 'box_jump', 'step_up_on_box', '_on_box']],
];

function initFirebase() {
  if (DRY_RUN) return null;

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

function parseSlug(filename) {
  const slug = filename.replace(/\.mp4$/i, '');
  let gender = 'neutral';
  let baseSlug = slug;

  if (slug.endsWith('_female')) {
    gender = 'female';
    baseSlug = slug.slice(0, -'_female'.length);
  } else if (slug.endsWith('_male')) {
    gender = 'male';
    baseSlug = slug.slice(0, -'_male'.length);
  }

  return { slug, gender, baseSlug };
}

function slugToName(slug) {
  const base = slug.replace(/_female$/, '').replace(/_male$/, '');
  return base
    .split('_')
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

function inferEquipment(slug, localFolder) {
  const text = slug.toLowerCase();
  for (const [equipmentId, keywords] of EQUIPMENT_RULES) {
    if (keywords.some((keyword) => text.includes(keyword))) {
      return [equipmentId];
    }
  }
  if (localFolder === 'Yoga') {
    return ['yoga_mat'];
  }
  return ['none'];
}

const FOLDER_PRIMARY_MUSCLES = new Set([
  'Abdominals',
  'Back',
  'Biceps',
  'Triceps',
  'Forearms',
  'Chest',
  'Shoulders',
]);

function uniqueMuscles(values) {
  return [...new Set(values.filter(Boolean))];
}

function inferMuscleGroupsFromSlug(slug) {
  const text = slug.toLowerCase();
  const groups = new Set();

  if (/hamstring|rdl|good_morning/.test(text)) groups.add('hamstrings');
  if (/glute|hip_thrust|hip_bridge/.test(text)) groups.add('glutes');
  if (/calf|calve/.test(text)) groups.add('quads');
  if (/quad|squat|lunge|leg_press|leg_extension|step_up|split_squat|wall_sit|pistol/.test(text)) {
    groups.add('quads');
  }

  if (
    /biceps|bicep_curl|preacher_curl|hammer_curl|concentration_curl/.test(text) &&
    !/leg_curl|hamstring_curl|triceps/.test(text)
  ) {
    groups.add('biceps');
  }
  if (/triceps|tricep|skullcrusher|kickback|pushdown|close_grip_press/.test(text)) {
    groups.add('triceps');
  }
  if (/chest|push_up|pushup|pec_|_fly|bench_press|incline_press|decline_press/.test(text)) {
    groups.add('chest');
  }
  if (
    /lat|pulldown|pull_up|chin_up|_row|row_|deadlift|back_extension|hyperextension|shrug/.test(text) &&
    !/upright_row/.test(text)
  ) {
    groups.add('back');
  }
  if (/shoulder|delt|lateral_raise|overhead_press|military_press|arnold|face_pull|upright_row/.test(text)) {
    groups.add('shoulders');
  }
  if (/forearm|wrist/.test(text)) groups.add('forearms');
  if (/crunch|plank|sit_up|ab_|_abs|oblique|leg_raise|v_up|russian_twist|bicycle_crunch|dead_bug/.test(text)) {
    groups.add('core');
  }

  if (/burpee|jumping_jack|mountain_climber|battle_rope|boxing|shadow_boxing/.test(text)) {
    groups.add('quads');
    groups.add('core');
    groups.add('shoulders');
  }
  if (/snatch|clean_and_jerk|clean_and_press|power_clean|power_jerk/.test(text)) {
    groups.add('quads');
    groups.add('back');
    groups.add('shoulders');
  }

  return [...groups];
}

function inferMuscleGroups(slug, localFolder) {
  const folderMeta = FOLDER_METADATA[localFolder];
  const fromSlug = inferMuscleGroupsFromSlug(slug);
  const folderDefault =
    localFolder === 'Legs' ? inferLegMuscleGroups(slug) : [...folderMeta.muscleGroups];

  if (FOLDER_PRIMARY_MUSCLES.has(localFolder)) {
    return folderDefault;
  }

  if (localFolder === 'Traps') {
    if (/shrug|trap/.test(slug.toLowerCase())) {
      return uniqueMuscles(['shoulders', 'back', ...fromSlug]);
    }
    if (fromSlug.length > 0) {
      return uniqueMuscles(fromSlug);
    }
    return folderDefault;
  }

  if (localFolder === 'Legs') {
    return inferLegMuscleGroups(slug);
  }

  if (fromSlug.length > 0) {
    return uniqueMuscles(fromSlug);
  }

  return folderDefault;
}

function inferSecondaryMuscles(slug, muscleGroups) {
  const text = slug.toLowerCase();
  const secondary = new Set();
  const primary = new Set(muscleGroups);

  if (text.includes('push_up') || text.includes('pushup')) {
    if (!primary.has('chest')) secondary.add('chest');
    if (!primary.has('shoulders')) secondary.add('shoulders');
  }
  if (
    (text.includes('chest_dip') || text.includes('forward_lean_dip')) &&
    !primary.has('chest')
  ) {
    secondary.add('chest');
  }
  if (text.includes('curl') && primary.has('biceps')) {
    secondary.add('forearms');
  }
  if ((text.includes('squat') || text.includes('lunge')) && primary.has('quads')) {
    if (!primary.has('glutes')) secondary.add('glutes');
    if (!primary.has('hamstrings')) secondary.add('hamstrings');
  }
  if (
    text.includes('_row') ||
    text.includes('row_') ||
    text.includes('pull_up') ||
    text.includes('chin_up') ||
    text.includes('lat_pull')
  ) {
    secondary.add('biceps');
  }
  if (text.includes('press') && primary.has('chest')) {
    secondary.add('triceps');
    secondary.add('shoulders');
  }
  if (text.includes('deadlift') && primary.has('back')) {
    secondary.add('hamstrings');
    secondary.add('glutes');
  }

  return [...secondary].filter((muscle) => !primary.has(muscle));
}

function inferLegMuscleGroups(slug) {
  const text = slug.toLowerCase();
  const groups = new Set();

  if (/hamstring|rdl|good_morning/.test(text)) groups.add('hamstrings');
  if (/glute|hip_thrust|hip_bridge/.test(text)) groups.add('glutes');
  if (/calf|calve/.test(text)) groups.add('quads');
  if (/adductor|abductor|inner_thigh|outer_thigh/.test(text)) groups.add('quads');
  if (
    /squat|lunge|leg_press|leg_extension|step_up|split_squat|wall_sit|pistol|quad/.test(text)
  ) {
    groups.add('quads');
  }

  if (groups.size === 0) {
    groups.add('quads');
  }

  return [...groups];
}

function inferDifficulty(slug, equipment) {
  const text = slug.toLowerCase();

  if (
    text.includes('planche') ||
    text.includes('muscle_up') ||
    text.includes('one_arm') ||
    text.includes('pistol') ||
    text.includes('full_planche')
  ) {
    return 'advanced';
  }

  if (
    equipment.some((item) => ['barbell', 'smith_machine'].includes(item)) ||
    text.includes('snatch') ||
    text.includes('clean') ||
    text.includes('jerk')
  ) {
    return 'advanced';
  }

  if (
    equipment.includes('none') &&
    (text.includes('push_up') ||
      text.includes('squat') ||
      text.includes('stretch') ||
      text.includes('beginner'))
  ) {
    return 'beginner';
  }

  return 'intermediate';
}

function inferCategory(slug, folderMeta) {
  const text = slug.toLowerCase();
  if (folderMeta.category === 'flexibility' || folderMeta.category === 'core') {
    return folderMeta.category;
  }
  if (text.includes('jump') || text.includes('burpee') || text.includes('cardio')) {
    return 'cardio';
  }
  if (text.includes('clap') || text.includes('explosive') || text.includes('plyo')) {
    return 'plyometric';
  }
  return folderMeta.category;
}

function buildTags(slug, folderMeta, equipment, category) {
  const tags = new Set([
    ...folderMeta.muscleGroups,
    category,
    ...equipment.filter((item) => item !== 'none'),
  ]);

  const text = slug.toLowerCase();
  if (text.includes('push')) tags.add('push');
  if (text.includes('pull')) tags.add('pull');
  if (text.includes('dip')) tags.add('dip');
  if (equipment.includes('none')) tags.add('bodyweight');

  return [...tags];
}

function buildVideoUrl(r2Folder, slug) {
  return `${R2_PUBLIC_BASE}/exercises/videos/${r2Folder}/${slug}.mp4`;
}

function buildStorageRef(r2Folder, slug) {
  return `exercises/videos/${r2Folder}/${slug}.mp4`;
}

function buildExerciseDoc(localFolder, filename) {
  const folderMeta = FOLDER_METADATA[localFolder];
  const r2Folder = FOLDER_TO_R2[localFolder];
  if (!folderMeta || !r2Folder) {
    throw new Error(`Unknown folder mapping for: ${localFolder}`);
  }

  const { slug, gender, baseSlug } = parseSlug(filename);
  const requiredEquipment = inferEquipment(slug, localFolder);
  const rawMuscleGroups = inferMuscleGroups(slug, localFolder);
  const rawSecondaryMuscles = inferSecondaryMuscles(slug, rawMuscleGroups);
  const { muscleGroups, secondaryMuscles } = canonicalizeExerciseMuscles(
    rawMuscleGroups,
    rawSecondaryMuscles,
  );
  const category = inferCategory(slug, folderMeta);
  const difficulty = inferDifficulty(slug, requiredEquipment);
  const name = slugToName(slug);
  const videoUrl = buildVideoUrl(r2Folder, slug);
  const storageRef = buildStorageRef(r2Folder, slug);

  const doc = {
    id: slug,
    name,
    slug,
    description: `${name} — ${muscleGroups.join(', ')} exercise.`,
    instructions: `Perform ${name} with controlled form and full range of motion.`,
    tips: [],
    muscleGroups,
    secondaryMuscles,
    requiredEquipment,
    difficulty,
    category,
    defaultSets: 3,
    defaultReps: category === 'flexibility' ? null : 10,
    defaultSeconds: category === 'flexibility' ? 30 : null,
    restSeconds: 60,
    tags: buildTags(slug, { muscleGroups, category: folderMeta.category }, requiredEquipment, category),
    source: 'internal',
    sourceFolder: localFolder,
    media: {
      exerciseId: slug,
      primaryType: 'video',
      videoUrl,
      storageRef,
      provider: 'cloudflare_r2',
      gender,
      status: 'active',
    },
  };

  if (gender !== 'neutral') {
    doc.baseExerciseId = baseSlug;
  }

  return doc;
}

function listMp4Files(localFolder) {
  const dir = path.join(LOCAL_VIDEOS_DIR, localFolder);
  if (!fs.existsSync(dir)) {
    throw new Error(`Folder not found: ${dir}`);
  }

  return fs
    .readdirSync(dir)
    .filter((file) => file.toLowerCase().endsWith('.mp4'))
    .sort();
}

function resolveFolders() {
  if (ALL_FOLDERS) {
    return Object.keys(FOLDER_METADATA);
  }
  if (FOLDER_ARG) {
    const match = Object.keys(FOLDER_METADATA).find(
      (folder) => folder.toLowerCase() === FOLDER_ARG.toLowerCase(),
    );
    if (!match) {
      throw new Error(
        `Unknown --folder "${FOLDER_ARG}". Valid folders: ${Object.keys(FOLDER_METADATA).join(', ')}`,
      );
    }
    return [match];
  }
  throw new Error('Pass --folder Triceps (or another folder name) or --all');
}

async function writeInBatches(db, exercises) {
  let batch = db.batch();
  let pending = 0;
  let written = 0;

  for (const exercise of exercises) {
    const ref = db.collection(EXERCISE_COLLECTION).doc(exercise.id);
    const payload = { ...exercise };
    delete payload.id;

    batch.set(
      ref,
      {
        ...payload,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    pending += 1;

    if (pending >= 400) {
      await batch.commit();
      written += pending;
      batch = db.batch();
      pending = 0;
      console.log(`Wrote ${written} documents...`);
    }
  }

  if (pending > 0) {
    await batch.commit();
    written += pending;
  }

  return written;
}

async function main() {
  const folders = resolveFolders();
  const exercises = [];

  for (const folder of folders) {
    const files = listMp4Files(folder);
    console.log(`[${folder}] Found ${files.length} MP4 files`);
    for (const file of files) {
      exercises.push(buildExerciseDoc(folder, file));
    }
  }

  console.log(`Built ${exercises.length} Firestore documents`);
  console.log(`R2 base: ${R2_PUBLIC_BASE}`);

  if (DRY_RUN || EXPORT_PATH) {
    console.log('\n--- Sample documents ---');
    console.log(JSON.stringify(exercises.slice(0, 2), null, 2));
    console.log('\n--- Summary ---');
    for (const folder of folders) {
      const count = exercises.filter((doc) => doc.sourceFolder === folder).length;
      const femaleCount = exercises.filter(
        (doc) => doc.sourceFolder === folder && doc.media.gender === 'female',
      ).length;
      console.log(`  ${folder}: ${count} total, ${femaleCount} female`);
    }
  }

  if (EXPORT_PATH) {
    const exportFile = path.resolve(EXPORT_PATH);
    fs.mkdirSync(path.dirname(exportFile), { recursive: true });
    fs.writeFileSync(exportFile, JSON.stringify(exercises, null, 2));
    console.log(`\nExported ${exercises.length} documents to ${exportFile}`);
  }

  if (DRY_RUN || EXPORT_PATH) {
    return;
  }

  const db = initFirebase();
  const written = await writeInBatches(db, exercises);
  console.log(`Seeded ${written} documents to ${EXERCISE_COLLECTION}.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
