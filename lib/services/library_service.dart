// lib/services/library_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/exercise_media.dart';
import '../data/exercise_library_data.dart';

const _uuid = Uuid();

class LibraryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Exercise Library ─────────────────────────────────────
  Future<List<LibraryExercise>> getExerciseLibrary() async {
    try {
      final snap = await _db
          .collection('exercise_library')
          .orderBy('name')
          .limit(1000)
          .get();
      final firestoreExercises = snap.docs
          .map((doc) => LibraryExercise.fromMap(doc.data()))
          .where((exercise) => exercise.id.isNotEmpty && exercise.name.isNotEmpty)
          .toList();
      if (firestoreExercises.isNotEmpty) return firestoreExercises;
    } catch (_) {
      // Local starter data keeps custom workout creation usable offline or
      // before Firestore is seeded.
    }
    return kExerciseLibrary;
  }

  /// Returns filtered exercises based on search, muscle, category, equipment
  List<LibraryExercise> filterExercises({
    String? query,
    String? muscle,
    String? category,
    List<String>? equipment,
    String? difficulty,
  }) {
    return filterExerciseList(
      kExerciseLibrary,
      query: query,
      muscle: muscle,
      category: category,
      equipment: equipment,
      difficulty: difficulty,
    );
  }

  List<LibraryExercise> filterExerciseList(
    List<LibraryExercise> exercises, {
    String? query,
    String? muscle,
    String? category,
    List<String>? equipment,
    String? difficulty,
  }) {
    var results = List<LibraryExercise>.from(exercises);

    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      results = results.where((e) =>
        e.name.toLowerCase().contains(q) ||
        e.muscleGroups.any((m) => m.contains(q)) ||
        e.tags.any((t) => t.contains(q))
      ).toList();
    }

    if (muscle != null && muscle != 'all') {
      results = results.where((e) =>
        e.muscleGroups.contains(muscle) || e.secondaryMuscles.contains(muscle)
      ).toList();
    }

    if (category != null && category != 'all') {
      results = results.where((e) => e.category == category).toList();
    }

    if (equipment != null && equipment.isNotEmpty) {
      results = results.where((e) =>
        e.requiredEquipment.every((eq) => eq == 'none' || equipment.contains(eq))
      ).toList();
    }

    if (difficulty != null && difficulty != 'all') {
      results = results.where((e) => e.difficulty == difficulty).toList();
    }

    return results;
  }

  LibraryExercise? getExerciseById(String id) {
    try {
      return kExerciseLibrary.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Custom Workouts ──────────────────────────────────────
  Stream<List<CustomWorkout>> watchCustomWorkouts(String userId) {
    if (userId.isEmpty) return Stream.value(const []);
    return _db
        .collection('users')
        .doc(userId)
        .collection('custom_workouts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => CustomWorkout.fromMap(d.data())).toList());
  }

  Future<void> saveCustomWorkout(CustomWorkout workout) async {
    if (workout.userId.isEmpty) {
      throw StateError('Cannot save workout without a signed-in user.');
    }
    await _db
        .collection('users')
        .doc(workout.userId)
        .collection('custom_workouts')
        .doc(workout.id)
        .set(workout.toMap());
  }

  Future<CustomWorkout?> getCustomWorkout(String userId, String workoutId) async {
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('custom_workouts')
        .doc(workoutId)
        .get();
    if (!doc.exists) return null;
    return CustomWorkout.fromMap(doc.data()!);
  }

  Future<void> deleteCustomWorkout(String userId, String workoutId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('custom_workouts')
        .doc(workoutId)
        .delete();
  }

  Future<void> updateLastPerformed(String userId, String workoutId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('custom_workouts')
        .doc(workoutId)
        .update({'lastPerformed': DateTime.now().toIso8601String()});
  }

  // ── Custom Workout Presets ───────────────────────────────
  Stream<List<CustomWorkoutPreset>> watchPresets(
    String userId,
    String workoutId,
  ) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('custom_workouts')
        .doc(workoutId)
        .collection('presets')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => CustomWorkoutPreset.fromMap(d.data())).toList());
  }

  Future<List<CustomWorkoutPreset>> getPresets(
    String userId,
    String workoutId,
  ) async {
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('custom_workouts')
        .doc(workoutId)
        .collection('presets')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => CustomWorkoutPreset.fromMap(d.data())).toList();
  }

  Future<void> savePreset(CustomWorkoutPreset preset) async {
    await _db
        .collection('users')
        .doc(preset.userId)
        .collection('custom_workouts')
        .doc(preset.workoutId)
        .collection('presets')
        .doc(preset.id)
        .set(preset.toMap());
  }

  Future<void> deletePreset(
    String userId,
    String workoutId,
    String presetId,
  ) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('custom_workouts')
        .doc(workoutId)
        .collection('presets')
        .doc(presetId)
        .delete();
  }

  Future<void> updatePresetLastUsed(
    String userId,
    String workoutId,
    String presetId,
  ) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('custom_workouts')
        .doc(workoutId)
        .collection('presets')
        .doc(presetId)
        .update({'lastUsedAt': DateTime.now().toIso8601String()});
  }

  String generateId() => _uuid.v4();
}

// ── Filter state ─────────────────────────────────────────
class LibraryFilterState {
  final String query;
  final String muscle;     // 'all' or specific
  final String category;   // 'all' | strength | cardio | core | flexibility | plyometric
  final String difficulty; // 'all' | beginner | intermediate | advanced
  final List<String> equipment;

  const LibraryFilterState({
    this.query = '',
    this.muscle = 'all',
    this.category = 'all',
    this.difficulty = 'all',
    this.equipment = const [],
  });

  LibraryFilterState copyWith({
    String? query,
    String? muscle,
    String? category,
    String? difficulty,
    List<String>? equipment,
  }) =>
      LibraryFilterState(
        query: query ?? this.query,
        muscle: muscle ?? this.muscle,
        category: category ?? this.category,
        difficulty: difficulty ?? this.difficulty,
        equipment: equipment ?? this.equipment,
      );

  bool get hasActiveFilters =>
      query.isNotEmpty ||
      muscle != 'all' ||
      category != 'all' ||
      difficulty != 'all';
}

class LibraryFilterNotifier extends StateNotifier<LibraryFilterState> {
  LibraryFilterNotifier() : super(const LibraryFilterState());

  void setQuery(String q) => state = state.copyWith(query: q);
  void setMuscle(String m) => state = state.copyWith(muscle: m);
  void setCategory(String c) => state = state.copyWith(category: c);
  void setDifficulty(String d) => state = state.copyWith(difficulty: d);
  void setEquipment(List<String> e) => state = state.copyWith(equipment: e);
  void reset() => state = const LibraryFilterState();
}

// ── Providers ─────────────────────────────────────────────
final libraryServiceProvider = Provider<LibraryService>((ref) => LibraryService());

final libraryFilterProvider =
    StateNotifierProvider<LibraryFilterNotifier, LibraryFilterState>(
  (ref) => LibraryFilterNotifier(),
);

final filteredExercisesProvider = Provider<List<LibraryExercise>>((ref) {
  final filter = ref.watch(libraryFilterProvider);
  final service = ref.watch(libraryServiceProvider);
  return service.filterExercises(
    query: filter.query,
    muscle: filter.muscle,
    category: filter.category,
    difficulty: filter.difficulty,
    equipment: filter.equipment.isEmpty ? null : filter.equipment,
  );
});

final exerciseLibraryProvider = FutureProvider<List<LibraryExercise>>((ref) {
  return ref.watch(libraryServiceProvider).getExerciseLibrary();
});

final filteredExerciseLibraryProvider =
    FutureProvider<List<LibraryExercise>>((ref) async {
  final filter = ref.watch(libraryFilterProvider);
  final service = ref.watch(libraryServiceProvider);
  final exercises = await ref.watch(exerciseLibraryProvider.future);
  return service.filterExerciseList(
    exercises,
    query: filter.query,
    muscle: filter.muscle,
    category: filter.category,
    difficulty: filter.difficulty,
    equipment: filter.equipment.isEmpty ? null : filter.equipment,
  );
});

final customWorkoutsProvider =
    StreamProvider.family<List<CustomWorkout>, String>(
  (ref, userId) =>
      ref.watch(libraryServiceProvider).watchCustomWorkouts(userId),
);

final customWorkoutPresetsProvider = StreamProvider.family<
    List<CustomWorkoutPreset>, ({String userId, String workoutId})>(
  (ref, args) => ref
      .watch(libraryServiceProvider)
      .watchPresets(args.userId, args.workoutId),
);

// Builder state for creating a custom workout
class WorkoutBuilderNotifier extends StateNotifier<List<CustomWorkoutExercise>> {
  WorkoutBuilderNotifier() : super([]);

  void addExercise(LibraryExercise ex) {
    final entry = CustomWorkoutExercise(
      exerciseId: ex.id,
      exerciseName: ex.name,
      thumbnailUrl: ex.media?.displayUrl,
      sets: 3,
      reps: ex.isTimeBased ? null : 10,
      seconds: ex.isTimeBased ? (ex.defaultSeconds ?? 30) : null,
      restSeconds: 60,
      order: state.length,
      bodyParts: ex.muscleGroups,
      equipment: ex.requiredEquipment,
    );
    state = [...state, entry];
  }

  void removeAt(int index) {
    final updated = [...state];
    updated.removeAt(index);
    // Re-index
    state = updated.asMap().entries.map((e) => e.value.copyWith(order: e.key)).toList();
  }

  void reorder(int oldIndex, int newIndex) {
    final updated = [...state];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = updated.asMap().entries.map((e) => e.value.copyWith(order: e.key)).toList();
  }

  void updateExercise(int index, CustomWorkoutExercise updated) {
    final list = [...state];
    list[index] = updated;
    state = list;
  }

  void clear() => state = [];
}

final workoutBuilderProvider =
    StateNotifierProvider<WorkoutBuilderNotifier, List<CustomWorkoutExercise>>(
  (ref) => WorkoutBuilderNotifier(),
);
