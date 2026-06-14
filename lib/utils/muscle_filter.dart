/// Canonical body-part IDs used in the custom workout builder and progress UI.
const kCanonicalBodyPartIds = {
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
};

const _muscleAliases = {
  'pectorals': 'chest',
  'pecs': 'chest',
  'lats': 'back',
  'traps': 'back',
  'trapezius': 'back',
  'upper_back': 'back',
  'spine': 'back',
  'delts': 'shoulders',
  'deltoids': 'shoulders',
  'abs': 'core',
  'abdominals': 'core',
  'obliques': 'core',
  'waist': 'core',
  'quadriceps': 'quads',
  'hams': 'hamstrings',
  'gluteus': 'glutes',
  'forearm': 'forearms',
  'lower_arms': 'forearms',
  'bicep': 'biceps',
  'tricep': 'triceps',
  'adductors': 'quads',
  'abductors': 'quads',
  'upper_legs': 'quads',
};

String? normalizeBodyPart(String raw) {
  final value = raw.trim().toLowerCase().replaceAll(' ', '_');
  if (value.isEmpty || value == 'full_body') return null;
  if (kCanonicalBodyPartIds.contains(value)) return value;
  return _muscleAliases[value];
}

Set<String> normalizeBodyParts(Iterable<String> raw) {
  return raw.map(normalizeBodyPart).whereType<String>().toSet();
}

bool exerciseMatchesMuscleFilter(
  List<String> muscleGroups,
  List<String> secondaryMuscles,
  String filter,
) {
  if (filter == 'all') return true;

  final primary = normalizeBodyParts(muscleGroups);
  final secondary = normalizeBodyParts(secondaryMuscles);

  switch (filter) {
    case 'arms':
      return primary.any({'biceps', 'triceps', 'forearms'}.contains) ||
          secondary.any({'biceps', 'triceps', 'forearms'}.contains);
    case 'legs':
      return primary.any({'quads', 'hamstrings', 'glutes'}.contains) ||
          secondary.any({'quads', 'hamstrings', 'glutes'}.contains);
    case 'full_body':
      return false;
    default:
      return primary.contains(filter) || secondary.contains(filter);
  }
}

/// Matches a builder body-part id against normalized exercise muscles.
bool exerciseMatchesBodyPart(
  List<String> muscleGroups,
  List<String> secondaryMuscles,
  String bodyPartId, {
  bool primaryOnly = false,
}) {
  final primary = normalizeBodyParts(muscleGroups);
  if (primaryOnly) {
    return primary.contains(bodyPartId);
  }
  final secondary = normalizeBodyParts(secondaryMuscles);
  return primary.contains(bodyPartId) || secondary.contains(bodyPartId);
}
