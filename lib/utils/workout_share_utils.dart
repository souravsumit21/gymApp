import '../models/exercise_media.dart';
import '../models/models.dart';
import '../models/share_models.dart';

/// Strips personal weights and builds a shareable snapshot.
WorkoutShareSnapshot buildShareSnapshot({
  required CustomWorkout workout,
  required UserProfile creator,
}) {
  final strippedExercises = workout.exercises
      .map(
        (e) => CustomWorkoutExercise(
          exerciseId: e.exerciseId,
          exerciseName: e.exerciseName,
          thumbnailUrl: e.thumbnailUrl,
          sets: e.sets,
          reps: e.reps,
          seconds: e.seconds,
          restSeconds: e.restSeconds,
          notes: e.notes,
          order: e.order,
          bodyParts: e.bodyParts,
          equipment: e.equipment,
        ),
      )
      .toList();

  return WorkoutShareSnapshot(
    name: workout.name,
    description: workout.description,
    exercises: strippedExercises,
    targetMuscles: workout.targetMuscles,
    selectedEquipment: workout.selectedEquipment,
    targetBodyParts: workout.targetBodyParts,
    estimatedMinutes: workout.estimatedMinutes,
    exerciseCount: workout.exerciseCount,
    creatorId: creator.uid,
    creatorUsername: creator.shareHandle,
    creatorDisplayName: creator.displayName,
  );
}

String deriveExperienceLevel(List<CustomWorkoutExercise> exercises) {
  // Without per-exercise difficulty on custom exercises, use exercise count
  // and structure as a simple heuristic.
  if (exercises.length >= 8) return 'advanced';
  if (exercises.length >= 5) return 'intermediate';
  return 'beginner';
}

List<String> buildSearchKeywords({
  required String name,
  required String description,
  required List<String> bodyParts,
  required List<String> equipment,
}) {
  final words = <String>{
    ...name.toLowerCase().split(RegExp(r'\s+')),
    ...description.toLowerCase().split(RegExp(r'\s+')),
    ...bodyParts.map((p) => p.toLowerCase()),
    ...equipment.map((e) => e.toLowerCase()),
  };
  words.removeWhere((w) => w.length < 2);
  return words.toList();
}

String formatExerciseLine(CustomWorkoutExercise exercise) {
  final detail = exercise.seconds != null
      ? '${exercise.sets} × ${exercise.seconds}s'
      : '${exercise.sets} × ${exercise.reps ?? 0} reps';
  return '${exercise.order + 1}. ${exercise.exerciseName} — $detail · ${exercise.restSeconds}s rest';
}

String formatShareText(WorkoutShareSnapshot snapshot) {
  final buffer = StringBuffer()
    ..writeln('${snapshot.name} — by @${snapshot.creatorUsername}')
    ..writeln('${snapshot.exerciseCount} exercises · ~${snapshot.estimatedMinutes} min');

  if (snapshot.targetBodyParts.isNotEmpty) {
    buffer.writeln('Body: ${snapshot.targetBodyParts.join(', ')}');
  }
  if (snapshot.selectedEquipment.isNotEmpty) {
    buffer.writeln('Equipment: ${snapshot.selectedEquipment.join(', ')}');
  }

  buffer.writeln();
  for (final exercise in snapshot.exercises) {
    buffer.writeln(formatExerciseLine(exercise));
  }

  return buffer.toString();
}

String labelTag(String value) => value
    .split('_')
    .map((part) =>
        part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
