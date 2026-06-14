/**
 * Canonical muscle IDs — keep in sync with lib/utils/muscle_filter.dart
 */
const CANONICAL_BODY_PARTS = new Set([
  'chest',
  'back',
  'shoulders',
  'biceps',
  'triceps',
  'quads',
  'hamstrings',
  'glutes',
  'core',
  'forearms',
]);

const MUSCLE_ALIASES = {
  pectorals: 'chest',
  pecs: 'chest',
  lats: 'back',
  traps: 'back',
  trapezius: 'back',
  upper_back: 'back',
  spine: 'back',
  delts: 'shoulders',
  deltoids: 'shoulders',
  abs: 'core',
  abdominals: 'core',
  obliques: 'core',
  waist: 'core',
  quadriceps: 'quads',
  hams: 'hamstrings',
  gluteus: 'glutes',
  forearm: 'forearms',
  lower_arms: 'forearms',
  bicep: 'biceps',
  tricep: 'triceps',
  adductors: 'quads',
  abductors: 'quads',
  upper_legs: 'quads',
  upper_arms: 'biceps',
};

function normalizeToken(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/&/g, 'and')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function normalizeMuscleToken(token) {
  const t = normalizeToken(token);
  if (!t || t === 'full_body') return null;
  if (CANONICAL_BODY_PARTS.has(t)) return t;
  return MUSCLE_ALIASES[t] || null;
}

function normalizeMuscleList(tokens) {
  const out = [];
  for (const token of tokens || []) {
    const normalized = normalizeMuscleToken(token);
    if (normalized && !out.includes(normalized)) {
      out.push(normalized);
    }
  }
  return out;
}

function canonicalizeExerciseMuscles(muscleGroups, secondaryMuscles) {
  const primary = normalizeMuscleList(muscleGroups);
  const secondary = normalizeMuscleList(secondaryMuscles).filter(
    (muscle) => !primary.includes(muscle),
  );
  return { muscleGroups: primary, secondaryMuscles: secondary };
}

module.exports = {
  CANONICAL_BODY_PARTS,
  normalizeMuscleToken,
  normalizeMuscleList,
  canonicalizeExerciseMuscles,
};
