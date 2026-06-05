// lib/data/exercise_library_data.dart
// Seed data for the exercise library.
// GIF URLs point to well-known free exercise GIF CDNs (e.g. wger.de, fitnessprogramer.com).
// Swap in your own Firebase Storage URLs once you upload your media.

import '../models/exercise_media.dart';

// Alternative free GIF host: https://fitnessprogramer.com/wp-content/uploads/
const String _fp = 'https://fitnessprogramer.com/wp-content/uploads/2021';

final List<LibraryExercise> kExerciseLibrary = [

  // ── CHEST ────────────────────────────────────────────────
  LibraryExercise(
    id: 'push_up',
    name: 'Push-Up',
    description: 'Classic upper-body pressing movement targeting chest, shoulders, and triceps.',
    instructions:
        '1. Start in high plank, hands shoulder-width apart.\n'
        '2. Lower chest to just above the floor, elbows at ~45°.\n'
        '3. Press back up to full arm extension.\n'
        '4. Keep core tight throughout.',
    tips: ['Don\'t let hips sag', 'Full range of motion counts'],
    muscleGroups: ['chest', 'triceps'],
    secondaryMuscles: ['shoulders', 'core'],
    requiredEquipment: ['none'],
    difficulty: 'beginner',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'push_up',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/02/Push-Up.gif',
      thumbnailUrl: '$_fp/02/Push-Up.gif',
    ),
    defaultSets: 3,
    defaultReps: 12,
    restSeconds: 60,
    tags: ['push', 'compound', 'chest', 'bodyweight'],
    isFeatured: true,
    metValue: 8.0,
  ),

  LibraryExercise(
    id: 'wide_push_up',
    name: 'Wide Push-Up',
    description: 'Push-up with wider hand placement to emphasize the outer chest.',
    instructions:
        '1. Set hands wider than shoulder width.\n'
        '2. Lower chest to ground with control.\n'
        '3. Press back up explosively.',
    tips: ['Wider grip = more chest activation'],
    muscleGroups: ['chest'],
    secondaryMuscles: ['triceps', 'shoulders'],
    requiredEquipment: ['none'],
    difficulty: 'beginner',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'wide_push_up',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/02/Wide-Push-Up.gif',
      thumbnailUrl: '$_fp/02/Wide-Push-Up.gif',
    ),
    defaultSets: 3,
    defaultReps: 10,
    restSeconds: 60,
    tags: ['push', 'chest', 'bodyweight'],
    metValue: 8.0,
  ),

  LibraryExercise(
    id: 'diamond_push_up',
    name: 'Diamond Push-Up',
    description: 'Narrow push-up targeting inner chest and triceps heavily.',
    instructions:
        '1. Form a diamond shape with thumbs and index fingers.\n'
        '2. Lower chest to hands.\n'
        '3. Push back up.',
    tips: ['Elbows track back, not out'],
    muscleGroups: ['triceps', 'chest'],
    secondaryMuscles: ['shoulders'],
    requiredEquipment: ['none'],
    difficulty: 'intermediate',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'diamond_push_up',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/02/Diamond-Push-Up.gif',
      thumbnailUrl: '$_fp/02/Diamond-Push-Up.gif',
    ),
    defaultSets: 3,
    defaultReps: 8,
    restSeconds: 60,
    tags: ['push', 'triceps', 'chest', 'bodyweight'],
  ),

  LibraryExercise(
    id: 'dumbbell_chest_press',
    name: 'Dumbbell Chest Press',
    description: 'Full pec stretch and press using dumbbells on the floor or a bench.',
    instructions:
        '1. Lie on back with dumbbells at chest level.\n'
        '2. Press dumbbells up to full extension.\n'
        '3. Lower slowly with control.',
    tips: ['Don\'t let elbows flare excessively'],
    muscleGroups: ['chest'],
    secondaryMuscles: ['triceps', 'shoulders'],
    requiredEquipment: ['dumbbells'],
    difficulty: 'beginner',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'dumbbell_chest_press',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/01/Dumbbell-Floor-Press.gif',
      thumbnailUrl: '$_fp/01/Dumbbell-Floor-Press.gif',
    ),
    defaultSets: 3,
    defaultReps: 10,
    restSeconds: 90,
    tags: ['push', 'compound', 'chest', 'dumbbells'],
    isFeatured: true,
    metValue: 6.0,
  ),

  // ── BACK ─────────────────────────────────────────────────
  LibraryExercise(
    id: 'pull_up',
    name: 'Pull-Up',
    description: 'Foundational back exercise using a pull-up bar.',
    instructions:
        '1. Hang from bar with overhand grip.\n'
        '2. Pull chest to bar, squeezing lats.\n'
        '3. Lower slowly back to dead hang.',
    tips: ['Initiate with scapular depression', 'Avoid swinging'],
    muscleGroups: ['back', 'lats'],
    secondaryMuscles: ['biceps', 'core'],
    requiredEquipment: ['pull_up_bar'],
    difficulty: 'intermediate',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'pull_up',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/02/Pull-Up.gif',
      thumbnailUrl: '$_fp/02/Pull-Up.gif',
    ),
    defaultSets: 3,
    defaultReps: 6,
    restSeconds: 90,
    tags: ['pull', 'compound', 'back', 'pull_up_bar'],
    isFeatured: true,
    metValue: 8.0,
  ),

  LibraryExercise(
    id: 'inverted_row',
    name: 'Inverted Row',
    description: 'Horizontal pull using a bar or table edge — beginner friendly back builder.',
    instructions:
        '1. Set bar at hip height, hang beneath it.\n'
        '2. Pull chest to bar, keeping body rigid.\n'
        '3. Lower with control.',
    tips: ['Easier = higher bar', 'Harder = lower bar or elevated feet'],
    muscleGroups: ['back', 'lats'],
    secondaryMuscles: ['biceps', 'rear delts'],
    requiredEquipment: ['pull_up_bar'],
    difficulty: 'beginner',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'inverted_row',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/2021/09/Inverted-Row.gif',
      thumbnailUrl: '$_fp/2021/09/Inverted-Row.gif',
    ),
    defaultSets: 3,
    defaultReps: 10,
    restSeconds: 60,
    tags: ['pull', 'back', 'bodyweight'],
  ),

  LibraryExercise(
    id: 'dumbbell_row',
    name: 'Dumbbell Row',
    description: 'Single-arm row to build unilateral back strength.',
    instructions:
        '1. Place one hand and knee on a bench or chair.\n'
        '2. Row dumbbell to hip, elbow tracking back.\n'
        '3. Lower fully and repeat.',
    tips: ['Don\'t rotate torso', 'Full stretch at bottom'],
    muscleGroups: ['back', 'lats'],
    secondaryMuscles: ['biceps', 'rear delts'],
    requiredEquipment: ['dumbbells'],
    difficulty: 'beginner',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'dumbbell_row',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/01/One-Arm-Dumbbell-Row.gif',
      thumbnailUrl: '$_fp/01/One-Arm-Dumbbell-Row.gif',
    ),
    defaultSets: 3,
    defaultReps: 10,
    restSeconds: 60,
    tags: ['pull', 'back', 'dumbbells', 'unilateral'],
    isFeatured: true,
    metValue: 5.0,
  ),

  // ── LEGS ─────────────────────────────────────────────────
  LibraryExercise(
    id: 'squat',
    name: 'Bodyweight Squat',
    description: 'Fundamental lower-body movement for quads, glutes, and hamstrings.',
    instructions:
        '1. Stand feet shoulder-width, toes slightly out.\n'
        '2. Push hips back and bend knees to parallel.\n'
        '3. Drive through heels to stand.',
    tips: ['Chest up', 'Knees track over toes'],
    muscleGroups: ['quads', 'glutes'],
    secondaryMuscles: ['hamstrings', 'core'],
    requiredEquipment: ['none'],
    difficulty: 'beginner',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'squat',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/01/Squat.gif',
      thumbnailUrl: '$_fp/01/Squat.gif',
    ),
    defaultSets: 3,
    defaultReps: 15,
    restSeconds: 60,
    tags: ['legs', 'compound', 'bodyweight', 'glutes'],
    isFeatured: true,
    metValue: 5.0,
  ),

  LibraryExercise(
    id: 'jump_squat',
    name: 'Jump Squat',
    description: 'Explosive squat variation to build power and burn calories.',
    instructions:
        '1. Squat to parallel.\n'
        '2. Explode upward, leaving the ground.\n'
        '3. Land softly and immediately descend.',
    tips: ['Soft landing = protect knees', 'Full arm swing helps height'],
    muscleGroups: ['quads', 'glutes'],
    secondaryMuscles: ['calves', 'core'],
    requiredEquipment: ['none'],
    difficulty: 'intermediate',
    category: 'plyometric',
    media: ExerciseMedia(
      exerciseId: 'jump_squat',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/01/Jump-Squat.gif',
      thumbnailUrl: '$_fp/01/Jump-Squat.gif',
    ),
    defaultSets: 3,
    defaultReps: 12,
    restSeconds: 90,
    tags: ['legs', 'plyometric', 'cardio', 'bodyweight'],
    metValue: 10.0,
  ),

  LibraryExercise(
    id: 'lunge',
    name: 'Forward Lunge',
    description: 'Unilateral leg exercise for quad and glute development.',
    instructions:
        '1. Step forward with one leg.\n'
        '2. Lower back knee toward ground.\n'
        '3. Push back to start and alternate.',
    tips: ['Keep torso upright', 'Front knee stays over ankle'],
    muscleGroups: ['quads', 'glutes'],
    secondaryMuscles: ['hamstrings', 'balance'],
    requiredEquipment: ['none'],
    difficulty: 'beginner',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'lunge',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/01/Lunge.gif',
      thumbnailUrl: '$_fp/01/Lunge.gif',
    ),
    defaultSets: 3,
    defaultReps: 10,
    restSeconds: 60,
    tags: ['legs', 'unilateral', 'glutes', 'bodyweight'],
    metValue: 4.0,
  ),

  LibraryExercise(
    id: 'goblet_squat',
    name: 'Goblet Squat',
    description: 'Squat holding a dumbbell or kettlebell to encourage upright torso.',
    instructions:
        '1. Hold weight at chest, elbows pointing down.\n'
        '2. Squat deep, elbows tracking inside knees.\n'
        '3. Stand and repeat.',
    tips: ['Drive elbows between knees at bottom', 'Great for mobility'],
    muscleGroups: ['quads', 'glutes'],
    secondaryMuscles: ['core', 'upper back'],
    requiredEquipment: ['dumbbells', 'kettlebell'],
    difficulty: 'beginner',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'goblet_squat',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/2021/04/Dumbbell-Goblet-Squat.gif',
      thumbnailUrl: '$_fp/2021/04/Dumbbell-Goblet-Squat.gif',
    ),
    defaultSets: 3,
    defaultReps: 12,
    restSeconds: 60,
    tags: ['legs', 'glutes', 'dumbbells', 'kettlebell'],
  ),

  // ── CORE ─────────────────────────────────────────────────
  LibraryExercise(
    id: 'plank',
    name: 'Plank',
    description: 'Isometric core stabilisation exercise.',
    instructions:
        '1. Forearms on floor, elbows under shoulders.\n'
        '2. Form a straight line from head to heels.\n'
        '3. Hold, squeezing abs and glutes.',
    tips: ['Don\'t hold breath', 'Posterior pelvic tilt slightly'],
    muscleGroups: ['core'],
    secondaryMuscles: ['shoulders', 'glutes'],
    requiredEquipment: ['none'],
    difficulty: 'beginner',
    category: 'core',
    media: ExerciseMedia(
      exerciseId: 'plank',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/01/Plank.gif',
      thumbnailUrl: '$_fp/01/Plank.gif',
    ),
    defaultSets: 3,
    defaultSeconds: 30,
    restSeconds: 45,
    tags: ['core', 'isometric', 'bodyweight'],
    isFeatured: true,
    metValue: 4.0,
  ),

  LibraryExercise(
    id: 'crunch',
    name: 'Crunch',
    description: 'Classic abdominal isolation movement.',
    instructions:
        '1. Lie on back, knees bent, hands behind head.\n'
        '2. Curl shoulders off floor using abs.\n'
        '3. Lower with control.',
    tips: ['Don\'t pull neck', 'Exhale on way up'],
    muscleGroups: ['core', 'abs'],
    secondaryMuscles: [],
    requiredEquipment: ['none'],
    difficulty: 'beginner',
    category: 'core',
    media: ExerciseMedia(
      exerciseId: 'crunch',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/01/Crunch.gif',
      thumbnailUrl: '$_fp/01/Crunch.gif',
    ),
    defaultSets: 3,
    defaultReps: 20,
    restSeconds: 45,
    tags: ['core', 'abs', 'bodyweight'],
    metValue: 3.0,
  ),

  LibraryExercise(
    id: 'mountain_climber',
    name: 'Mountain Climber',
    description: 'Dynamic core exercise that also elevates heart rate.',
    instructions:
        '1. Start in high plank.\n'
        '2. Drive one knee toward chest, then quickly switch.\n'
        '3. Maintain plank position throughout.',
    tips: ['Hips stay level', 'Faster pace = more cardio'],
    muscleGroups: ['core', 'abs'],
    secondaryMuscles: ['shoulders', 'hip flexors'],
    requiredEquipment: ['none'],
    difficulty: 'intermediate',
    category: 'cardio',
    media: ExerciseMedia(
      exerciseId: 'mountain_climber',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/01/Mountain-Climber.gif',
      thumbnailUrl: '$_fp/01/Mountain-Climber.gif',
    ),
    defaultSets: 3,
    defaultSeconds: 30,
    restSeconds: 45,
    tags: ['core', 'cardio', 'bodyweight', 'hiit'],
    isFeatured: true,
    metValue: 8.0,
  ),

  // ── SHOULDERS ────────────────────────────────────────────
  LibraryExercise(
    id: 'pike_push_up',
    name: 'Pike Push-Up',
    description: 'Bodyweight overhead pressing movement that targets the deltoids.',
    instructions:
        '1. Start in downward dog position.\n'
        '2. Lower head toward floor by bending elbows.\n'
        '3. Press back up.',
    tips: ['Hips high throughout', 'Forms an inverted V'],
    muscleGroups: ['shoulders'],
    secondaryMuscles: ['triceps', 'upper chest'],
    requiredEquipment: ['none'],
    difficulty: 'intermediate',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'pike_push_up',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/02/Pike-Push-Up.gif',
      thumbnailUrl: '$_fp/02/Pike-Push-Up.gif',
    ),
    defaultSets: 3,
    defaultReps: 8,
    restSeconds: 60,
    tags: ['push', 'shoulders', 'bodyweight'],
  ),

  LibraryExercise(
    id: 'dumbbell_shoulder_press',
    name: 'Dumbbell Shoulder Press',
    description: 'Overhead pressing with dumbbells for full deltoid development.',
    instructions:
        '1. Hold dumbbells at shoulder height, palms forward.\n'
        '2. Press overhead to full extension.\n'
        '3. Lower with control.',
    tips: ['Don\'t shrug traps', 'Core braced throughout'],
    muscleGroups: ['shoulders'],
    secondaryMuscles: ['triceps', 'upper chest'],
    requiredEquipment: ['dumbbells'],
    difficulty: 'beginner',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'dumbbell_shoulder_press',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/01/Dumbbell-Shoulder-Press.gif',
      thumbnailUrl: '$_fp/01/Dumbbell-Shoulder-Press.gif',
    ),
    defaultSets: 3,
    defaultReps: 10,
    restSeconds: 60,
    tags: ['push', 'shoulders', 'dumbbells'],
    isFeatured: true,
    metValue: 5.0,
  ),

  // ── CARDIO / HIIT ─────────────────────────────────────────
  LibraryExercise(
    id: 'burpee',
    name: 'Burpee',
    description: 'Full-body conditioning movement that spikes heart rate rapidly.',
    instructions:
        '1. From standing, drop to push-up position.\n'
        '2. Perform a push-up (optional).\n'
        '3. Jump feet to hands.\n'
        '4. Explode upward with arms overhead.',
    tips: ['Scale by removing jump or push-up', 'Land softly'],
    muscleGroups: ['full_body'],
    secondaryMuscles: ['chest', 'core', 'legs'],
    requiredEquipment: ['none'],
    difficulty: 'intermediate',
    category: 'cardio',
    media: ExerciseMedia(
      exerciseId: 'burpee',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/01/Burpee.gif',
      thumbnailUrl: '$_fp/01/Burpee.gif',
    ),
    defaultSets: 3,
    defaultReps: 10,
    restSeconds: 90,
    tags: ['cardio', 'hiit', 'full_body', 'bodyweight'],
    isFeatured: true,
    metValue: 12.0,
  ),

  LibraryExercise(
    id: 'jumping_jack',
    name: 'Jumping Jack',
    description: 'Classic warm-up and cardio exercise.',
    instructions:
        '1. Stand with feet together, arms at sides.\n'
        '2. Jump feet out while raising arms overhead.\n'
        '3. Jump back to start.',
    muscleGroups: ['full_body'],
    secondaryMuscles: ['calves', 'shoulders'],
    requiredEquipment: ['none'],
    difficulty: 'beginner',
    category: 'cardio',
    media: ExerciseMedia(
      exerciseId: 'jumping_jack',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/01/Jumping-Jacks.gif',
      thumbnailUrl: '$_fp/01/Jumping-Jacks.gif',
    ),
    defaultSets: 3,
    defaultSeconds: 30,
    restSeconds: 30,
    tags: ['cardio', 'warm_up', 'bodyweight'],
    metValue: 8.0,
  ),

  LibraryExercise(
    id: 'high_knees',
    name: 'High Knees',
    description: 'Running in place with exaggerated knee lift to build cardio and core.',
    instructions:
        '1. Run in place, lifting knees to hip height.\n'
        '2. Pump arms in opposition.\n'
        '3. Maintain pace for duration.',
    tips: ['Stay on balls of feet', 'Drive arms hard'],
    muscleGroups: ['core', 'hip_flexors'],
    secondaryMuscles: ['calves', 'quads'],
    requiredEquipment: ['none'],
    difficulty: 'beginner',
    category: 'cardio',
    media: ExerciseMedia(
      exerciseId: 'high_knees',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/01/High-Knees.gif',
      thumbnailUrl: '$_fp/01/High-Knees.gif',
    ),
    defaultSets: 3,
    defaultSeconds: 30,
    restSeconds: 30,
    tags: ['cardio', 'hiit', 'bodyweight'],
    metValue: 10.0,
  ),

  // ── ARMS ─────────────────────────────────────────────────
  LibraryExercise(
    id: 'dumbbell_curl',
    name: 'Dumbbell Bicep Curl',
    description: 'Classic isolation exercise for bicep size and strength.',
    instructions:
        '1. Hold dumbbells at sides, palms forward.\n'
        '2. Curl to shoulder height, squeezing at top.\n'
        '3. Lower slowly.',
    tips: ['No elbow swinging', 'Full extension at bottom'],
    muscleGroups: ['biceps'],
    secondaryMuscles: ['forearms'],
    requiredEquipment: ['dumbbells'],
    difficulty: 'beginner',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'dumbbell_curl',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/01/Dumbbell-Bicep-Curl.gif',
      thumbnailUrl: '$_fp/01/Dumbbell-Bicep-Curl.gif',
    ),
    defaultSets: 3,
    defaultReps: 12,
    restSeconds: 60,
    tags: ['biceps', 'arms', 'dumbbells'],
    isFeatured: true,
    metValue: 3.0,
  ),

  LibraryExercise(
    id: 'tricep_dip',
    name: 'Tricep Dip',
    description: 'Bodyweight dip using a chair or bench to target the triceps.',
    instructions:
        '1. Hands on edge of chair, legs extended.\n'
        '2. Lower body by bending elbows to ~90°.\n'
        '3. Press back up.',
    tips: ['Keep elbows narrow', 'Hips close to chair'],
    muscleGroups: ['triceps'],
    secondaryMuscles: ['chest', 'shoulders'],
    requiredEquipment: ['none'],
    difficulty: 'beginner',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'tricep_dip',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/01/Bench-Dip.gif',
      thumbnailUrl: '$_fp/01/Bench-Dip.gif',
    ),
    defaultSets: 3,
    defaultReps: 12,
    restSeconds: 60,
    tags: ['triceps', 'arms', 'bodyweight'],
    metValue: 4.0,
  ),

  // ── GLUTES / HAMSTRINGS ───────────────────────────────────
  LibraryExercise(
    id: 'glute_bridge',
    name: 'Glute Bridge',
    description: 'Hip hinge movement that isolates and activates the glutes.',
    instructions:
        '1. Lie on back, knees bent, feet flat.\n'
        '2. Drive hips up by squeezing glutes.\n'
        '3. Hold at top, then lower.',
    tips: ['Push through heels', 'Full hip extension at top'],
    muscleGroups: ['glutes'],
    secondaryMuscles: ['hamstrings', 'core'],
    requiredEquipment: ['none'],
    difficulty: 'beginner',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'glute_bridge',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/01/Glute-Bridge.gif',
      thumbnailUrl: '$_fp/01/Glute-Bridge.gif',
    ),
    defaultSets: 3,
    defaultReps: 15,
    restSeconds: 45,
    tags: ['glutes', 'bodyweight', 'posterior chain'],
    isFeatured: true,
    metValue: 3.5,
  ),

  LibraryExercise(
    id: 'hip_thrust_dumbbell',
    name: 'Dumbbell Hip Thrust',
    description: 'Loaded glute bridge with dumbbell on hips for more resistance.',
    instructions:
        '1. Upper back on bench, dumbbell on hips.\n'
        '2. Drive hips to full extension.\n'
        '3. Lower under control.',
    tips: ['Chin tucked', 'Pause at the top'],
    muscleGroups: ['glutes'],
    secondaryMuscles: ['hamstrings'],
    requiredEquipment: ['dumbbells', 'weight_bench'],
    difficulty: 'intermediate',
    category: 'strength',
    media: ExerciseMedia(
      exerciseId: 'hip_thrust_dumbbell',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/2021/04/Dumbbell-Hip-Thrust.gif',
      thumbnailUrl: '$_fp/2021/04/Dumbbell-Hip-Thrust.gif',
    ),
    defaultSets: 3,
    defaultReps: 12,
    restSeconds: 60,
    tags: ['glutes', 'dumbbells', 'posterior chain'],
  ),

  // ── FLEXIBILITY ───────────────────────────────────────────
  LibraryExercise(
    id: 'world_greatest_stretch',
    name: 'World\'s Greatest Stretch',
    description: 'Dynamic mobility drill targeting hip flexors, thoracic spine, and hamstrings.',
    instructions:
        '1. Step into lunge position.\n'
        '2. Drop same-side elbow to floor.\n'
        '3. Rotate thoracic spine, reaching arm overhead.\n'
        '4. Repeat per side.',
    tips: ['Move slowly and breathe', 'Great as warm-up'],
    muscleGroups: ['hip_flexors', 'thoracic spine'],
    secondaryMuscles: ['hamstrings', 'groin'],
    requiredEquipment: ['none'],
    difficulty: 'beginner',
    category: 'flexibility',
    media: ExerciseMedia(
      exerciseId: 'world_greatest_stretch',
      primaryType: MediaType.gif,
      gifUrl: '$_fp/2022/01/Worlds-Greatest-Stretch.gif',
      thumbnailUrl: '$_fp/2022/01/Worlds-Greatest-Stretch.gif',
    ),
    defaultSets: 2,
    defaultReps: 5,
    restSeconds: 30,
    tags: ['flexibility', 'mobility', 'warm_up', 'bodyweight'],
    metValue: 2.5,
  ),
];

// ── Helper accessors ──────────────────────────────────────
List<LibraryExercise> getExercisesByMuscle(String muscle) =>
    kExerciseLibrary.where((e) => e.muscleGroups.contains(muscle)).toList();

List<LibraryExercise> getExercisesByEquipment(List<String> available) =>
    kExerciseLibrary.where((e) =>
      e.requiredEquipment.every((eq) => eq == 'none' || available.contains(eq))
    ).toList();

List<LibraryExercise> searchExercises(String query) {
  final q = query.toLowerCase();
  return kExerciseLibrary.where((e) =>
    e.name.toLowerCase().contains(q) ||
    e.muscleGroups.any((m) => m.contains(q)) ||
    e.tags.any((t) => t.contains(q)) ||
    e.category.contains(q)
  ).toList();
}

List<LibraryExercise> getFeatured() =>
    kExerciseLibrary.where((e) => e.isFeatured).toList();

const List<String> kMuscleGroups = [
  'chest', 'back', 'shoulders', 'arms', 'biceps', 'triceps',
  'core', 'abs', 'legs', 'quads', 'hamstrings', 'glutes', 'calves',
  'full_body', 'hip_flexors',
];

const Map<String, String> kMuscleEmoji = {
  'chest': '💪', 'back': '🔙', 'shoulders': '🫸', 'arms': '💪',
  'biceps': '💪', 'triceps': '💪', 'core': '🎯', 'abs': '🎯',
  'legs': '🦵', 'quads': '🦵', 'hamstrings': '🦵', 'glutes': '🍑',
  'calves': '🦵', 'full_body': '🏋️', 'hip_flexors': '🦵',
};
