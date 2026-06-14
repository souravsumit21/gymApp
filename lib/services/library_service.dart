// lib/services/library_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/exercise_media.dart';
import '../data/exercise_library_data.dart';
import '../utils/equipment_filter.dart';
import '../utils/muscle_filter.dart';

const _uuid = Uuid();

class LibraryFetchResult {
  final List<LibraryExercise> exercises;
  final bool fromRemote;
  final String? errorMessage;

  const LibraryFetchResult({
    required this.exercises,
    required this.fromRemote,
    this.errorMessage,
  });
}

class ExerciseLibraryStatus {
  final bool isLoading;
  final String? errorMessage;
  final bool fromRemote;

  const ExerciseLibraryStatus({
    this.isLoading = false,
    this.errorMessage,
    this.fromRemote = false,
  });
}

class LibraryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<LibraryExercise>? _libraryCache;
  String? _lastFetchError;
  bool _lastFetchFromRemote = false;

  /// Bundled seed data — always available offline.
  List<LibraryExercise> get bundledExerciseLibrary => kExerciseLibrary;

  bool get hasCachedLibrary => _libraryCache != null;
  String? get lastFetchError => _lastFetchError;
  bool get lastFetchFromRemote => _lastFetchFromRemote;

  /// Cache after first remote fetch, otherwise bundled seed.
  List<LibraryExercise> get immediateExerciseLibrary =>
      _libraryCache ?? kExerciseLibrary;

  // ── Exercise Library ─────────────────────────────────────
  Future<List<LibraryExercise>> getExerciseLibrary() async {
    if (_libraryCache != null) return _libraryCache!;
    final result = await refreshExerciseLibraryFromRemote();
    return result.exercises;
  }

  /// Fetches from Firestore (or bundled fallback) and updates the memory cache.
  Future<LibraryFetchResult> refreshExerciseLibraryFromRemote({
    bool force = false,
  }) async {
    if (!force && _libraryCache != null) {
      return LibraryFetchResult(
        exercises: _libraryCache!,
        fromRemote: _lastFetchFromRemote,
        errorMessage: _lastFetchError,
      );
    }

    final result = await _fetchExerciseLibraryFromRemote();
    _libraryCache = result.exercises;
    _lastFetchFromRemote = result.fromRemote;
    _lastFetchError = result.errorMessage;
    return result;
  }

  Future<LibraryFetchResult> _fetchExerciseLibraryFromRemote() async {
    try {
      final snap = await _db
          .collection('exercise_library')
          .orderBy('name')
          .limit(2500)
          .get();
      final firestoreExercises = <LibraryExercise>[];
      var skipped = 0;
      for (final doc in snap.docs) {
        try {
          final exercise = LibraryExercise.fromMap(
            doc.data(),
            docId: doc.id,
          );
          if (exercise.id.isNotEmpty && exercise.name.isNotEmpty) {
            firestoreExercises.add(exercise);
          } else {
            skipped++;
          }
        } catch (error) {
          skipped++;
          debugPrint('LibraryService: skipped exercise ${doc.id}: $error');
        }
      }
      if (skipped > 0) {
        debugPrint('LibraryService: skipped $skipped malformed exercise docs');
      }
      if (firestoreExercises.isNotEmpty) {
        debugPrint(
          'LibraryService: loaded ${firestoreExercises.length} exercises from Firestore',
        );
        return LibraryFetchResult(
          exercises: firestoreExercises,
          fromRemote: true,
        );
      }
      debugPrint(
        'LibraryService: Firestore returned 0 exercises — using bundled fallback',
      );
      return LibraryFetchResult(
        exercises: kExerciseLibrary,
        fromRemote: false,
        errorMessage:
            'Could not load the full exercise library. Showing offline exercises only.',
      );
    } catch (error, stack) {
      debugPrint(
        'LibraryService: Firestore fetch failed ($error) — using bundled fallback. '
        'Sign in if exercise_library requires auth.',
      );
      debugPrintStack(stackTrace: stack);
      return LibraryFetchResult(
        exercises: kExerciseLibrary,
        fromRemote: false,
        errorMessage:
            'Could not load exercises. Check your connection and try again.',
      );
    }
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
      results = results.where((e) => exerciseMatchesMuscleFilter(
        e.muscleGroups,
        e.secondaryMuscles,
        muscle,
      )).toList();
    }

    if (category != null && category != 'all') {
      results = results.where((e) => e.category == category).toList();
    }

    if (equipment != null && equipment.isNotEmpty) {
      results = results.where((e) =>
        exerciseMatchesSelectedEquipment(e.requiredEquipment, equipment)
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
final libraryServiceProvider = Provider<LibraryService>((ref) {
  ref.keepAlive();
  return LibraryService();
});

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

/// Loads the remote library on first open; uses cache afterward.
class ExerciseLibraryNotifier extends AsyncNotifier<List<LibraryExercise>> {
  @override
  Future<List<LibraryExercise>> build() async {
    ref.keepAlive();
    final service = ref.read(libraryServiceProvider);

    if (service.hasCachedLibrary) {
      return service.immediateExerciseLibrary;
    }

    final result = await service.refreshExerciseLibraryFromRemote();
    return result.exercises;
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(libraryServiceProvider);
      final result = await service.refreshExerciseLibraryFromRemote(force: true);
      return result.exercises;
    });
  }
}

final exerciseLibraryProvider =
    AsyncNotifierProvider<ExerciseLibraryNotifier, List<LibraryExercise>>(
  ExerciseLibraryNotifier.new,
);

final exerciseLibraryStatusProvider = Provider<ExerciseLibraryStatus>((ref) {
  final libraryAsync = ref.watch(exerciseLibraryProvider);
  final service = ref.watch(libraryServiceProvider);

  if (libraryAsync.isLoading) {
    return const ExerciseLibraryStatus(isLoading: true);
  }

  if (libraryAsync.hasError) {
    return ExerciseLibraryStatus(
      errorMessage:
          'Could not load exercises. Check your connection and try again.',
    );
  }

  return ExerciseLibraryStatus(
    errorMessage: service.lastFetchError,
    fromRemote: service.lastFetchFromRemote,
  );
});

final exerciseLibraryMapProvider = Provider<Map<String, LibraryExercise>>((ref) {
  final service = ref.watch(libraryServiceProvider);
  final exercises = ref.watch(exerciseLibraryProvider).valueOrNull ??
      service.immediateExerciseLibrary;
  return {for (final exercise in exercises) exercise.id: exercise};
});

final filteredExerciseLibraryProvider =
    Provider<List<LibraryExercise>>((ref) {
  final filter = ref.watch(libraryFilterProvider);
  final service = ref.watch(libraryServiceProvider);
  final exercises = ref.watch(exerciseLibraryProvider).valueOrNull ??
      service.immediateExerciseLibrary;
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
    if (state.any((entry) => entry.exerciseId == ex.id)) return;

    final entry = CustomWorkoutExercise(
      exerciseId: ex.id,
      exerciseName: ex.name,
      thumbnailUrl: ex.media?.thumbnailUrl ?? ex.media?.gifUrl,
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

  void toggleExercise(LibraryExercise ex) {
    final index = state.indexWhere((entry) => entry.exerciseId == ex.id);
    if (index >= 0) {
      removeAt(index);
    } else {
      addExercise(ex);
    }
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

  void loadExercises(List<CustomWorkoutExercise> exercises) {
    state = [...exercises]..sort((a, b) => a.order.compareTo(b.order));
  }
}

final workoutBuilderProvider =
    StateNotifierProvider<WorkoutBuilderNotifier, List<CustomWorkoutExercise>>(
  (ref) => WorkoutBuilderNotifier(),
);
