import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/exercise_media.dart';
import '../models/models.dart';
import '../models/share_models.dart';
import '../utils/workout_share_utils.dart';
import 'share_service.dart';

const _uuid = Uuid();

class CommunityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> publishWorkout({
    required CustomWorkout workout,
    required UserProfile creator,
    required String description,
    String workoutMode = 'standard',
  }) async {
    if (!workout.canPublishToCommunity) {
      throw CommunityException(
        'Imported workouts cannot be published to the community.',
      );
    }

    final snapshot = buildShareSnapshot(workout: workout, creator: creator);
    final id = _uuid.v4();
    final bodyParts = workout.targetBodyParts.isNotEmpty
        ? workout.targetBodyParts
        : workout.targetMuscles;
    final equipment = workout.selectedEquipment;

    final communityWorkout = CommunityWorkout(
      id: id,
      creatorId: creator.uid,
      creatorUsername: creator.shareHandle,
      creatorDisplayName: creator.displayName,
      name: workout.name,
      description: description.trim(),
      snapshot: snapshot,
      bodyParts: bodyParts,
      equipment: equipment,
      experienceLevel: deriveExperienceLevel(workout.exercises),
      estimatedMinutes: workout.estimatedMinutes,
      exerciseCount: workout.exerciseCount,
      workoutMode: workoutMode,
      publishedAt: DateTime.now(),
      searchKeywords: buildSearchKeywords(
        name: workout.name,
        description: description,
        bodyParts: bodyParts,
        equipment: equipment,
      ),
    );

    await _db
        .collection('community_workouts')
        .doc(id)
        .set(communityWorkout.toMap());

    return id;
  }

  Future<CommunityWorkout?> getCommunityWorkout(String id) async {
    final doc = await _db.collection('community_workouts').doc(id).get();
    if (!doc.exists) return null;
    return CommunityWorkout.fromMap(doc.data()!);
  }

  Future<List<CommunityWorkout>> fetchCommunityWorkouts(
    CommunityFilterState filter,
  ) async {
    final orderField = filter.sort == CommunitySort.newest
        ? 'publishedAt'
        : 'saveCount';
    final snap = await _db
        .collection('community_workouts')
        .orderBy(orderField, descending: true)
        .limit(200)
        .get();
    var results = snap.docs
        .map((d) => CommunityWorkout.fromMap(d.data()))
        .toList();

    if (filter.experienceLevel != 'all') {
      results = results
          .where((w) => w.experienceLevel == filter.experienceLevel)
          .toList();
    }
    if (filter.workoutMode != 'all') {
      results = results
          .where((w) => w.workoutMode == filter.workoutMode)
          .toList();
    }

    if (filter.query.isNotEmpty) {
      final q = filter.query.toLowerCase();
      results = results
          .where(
            (w) =>
                w.name.toLowerCase().contains(q) ||
                w.description.toLowerCase().contains(q) ||
                w.searchKeywords.any((k) => k.contains(q)) ||
                w.creatorUsername.toLowerCase().contains(q),
          )
          .toList();
    }

    if (filter.bodyParts.isNotEmpty) {
      results = results
          .where((w) =>
              filter.bodyParts.any((bp) => w.bodyParts.contains(bp)))
          .toList();
    }

    if (filter.equipment.isNotEmpty) {
      results = results
          .where((w) =>
              filter.equipment.any((eq) => w.equipment.contains(eq)))
          .toList();
    }

    if (filter.maxDuration != null) {
      results = results
          .where((w) => w.estimatedMinutes <= filter.maxDuration!)
          .toList();
    }

    return results;
  }

  Future<bool> hasUserSavedCommunityWorkout(
    String userId,
    String communityWorkoutId,
  ) async {
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('community_saves')
        .doc(communityWorkoutId)
        .get();
    return doc.exists;
  }

  Future<CustomWorkout> saveCommunityWorkoutCopy({
    required String userId,
    required CommunityWorkout communityWorkout,
  }) async {
    final alreadySaved = await hasUserSavedCommunityWorkout(
      userId,
      communityWorkout.id,
    );

    final workout = await ShareService().saveSharedWorkoutCopy(
      userId: userId,
      snapshot: communityWorkout.snapshot,
      fromCommunity: true,
      sourceCommunityWorkoutId: communityWorkout.id,
    );

    if (!alreadySaved) {
      await _db.runTransaction((tx) async {
        final ref =
            _db.collection('community_workouts').doc(communityWorkout.id);
        final doc = await tx.get(ref);
        if (!doc.exists) return;
        final current = doc.data()?['saveCount'] as int? ?? 0;
        tx.update(ref, {'saveCount': current + 1});
      });

      await _db
          .collection('users')
          .doc(userId)
          .collection('community_saves')
          .doc(communityWorkout.id)
          .set({
        'communityWorkoutId': communityWorkout.id,
        'savedAt': DateTime.now().toIso8601String(),
        'localWorkoutId': workout.id,
      });
    }

    return workout;
  }

  Future<void> reportWorkout({
    required String communityWorkoutId,
    required String reporterId,
    required String reason,
  }) async {
    await _db
        .collection('community_workouts')
        .doc(communityWorkoutId)
        .collection('reports')
        .doc(_uuid.v4())
        .set({
      'reporterId': reporterId,
      'reason': reason,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}

class CommunityException implements Exception {
  final String message;
  CommunityException(this.message);
  @override
  String toString() => message;
}

class CommunityFilterNotifier extends StateNotifier<CommunityFilterState> {
  CommunityFilterNotifier() : super(const CommunityFilterState());

  void setQuery(String q) => state = state.copyWith(query: q);
  void setBodyParts(List<String> parts) =>
      state = state.copyWith(bodyParts: parts);
  void setEquipment(List<String> eq) => state = state.copyWith(equipment: eq);
  void setExperienceLevel(String level) =>
      state = state.copyWith(experienceLevel: level);
  void setMaxDuration(int? minutes) => state = state.copyWith(
        maxDuration: minutes,
        clearMaxDuration: minutes == null,
      );
  void setWorkoutMode(String mode) =>
      state = state.copyWith(workoutMode: mode);
  void setSort(CommunitySort sort) => state = state.copyWith(sort: sort);
  void reset() => state = const CommunityFilterState();
}

final communityServiceProvider =
    Provider<CommunityService>((ref) => CommunityService());

final communityFilterProvider =
    StateNotifierProvider<CommunityFilterNotifier, CommunityFilterState>(
  (ref) => CommunityFilterNotifier(),
);

final communityWorkoutsProvider =
    FutureProvider<List<CommunityWorkout>>((ref) async {
  final filter = ref.watch(communityFilterProvider);
  return ref.watch(communityServiceProvider).fetchCommunityWorkouts(filter);
});
