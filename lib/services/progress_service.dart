import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../models/progress_models.dart';
import '../utils/progress_calculator.dart';
import 'auth_service.dart';
import 'workout_service.dart';

class ProgressService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _metaRef(String userId) =>
      _db.collection('users').doc(userId).collection('progress_meta').doc('state');

  Stream<ProgressMeta> watchProgressMeta(String userId) {
    if (userId.isEmpty) return Stream.value(const ProgressMeta());
    return _metaRef(userId).snapshots().map(
          (doc) => ProgressMeta.fromMap(doc.data()),
        );
  }

  Future<ProgressMeta> getProgressMeta(String userId) async {
    if (userId.isEmpty) return const ProgressMeta();
    final doc = await _metaRef(userId).get();
    return ProgressMeta.fromMap(doc.data());
  }

  Future<void> activateStreakFreeze(String userId) async {
    final now = DateTime.now();
    final month = monthKey(now);
    final meta = await getProgressMeta(userId);
    if (meta.freezeUsedMonth == month) {
      throw ProgressException('Freeze already used this month.');
    }

    await _metaRef(userId).set(
      {
        'freezeUsedMonth': month,
        'frozenWeekKey': weekKey(now),
      },
      SetOptions(merge: true),
    );
  }

  ProgressSnapshot buildSnapshot({
    required List<WorkoutSession> sessions,
    required UserProfile? profile,
    required ProgressMeta meta,
    DateTime? selectedMonth,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final weeklyGoalDays = profile?.weeklyWorkoutDays ?? 3;
    final completed =
        sessions.where((s) => s.isCompleted).toList(growable: false);
    final month = selectedMonth ?? DateTime(today.year, today.month, 1);

    final weekly = buildWeeklyGoalSummary(
      sessions: completed,
      weeklyGoalDays: weeklyGoalDays,
      meta: meta,
      now: today,
    );

    final monthHistory = List.generate(6, (i) {
      final m = DateTime(today.year, today.month - i, 1);
      return buildMonthlyConsistency(
        sessions: completed,
        weeklyGoalDays: weeklyGoalDays,
        meta: meta,
        month: m,
      );
    });

    final totalWeight = computeTotalWeightKg(completed);
    final streakWeeks = weekly.streakWeeks;

    return ProgressSnapshot(
      weeklyStreak: weekly,
      bodyPartStreaks: computeBodyPartStreaks(sessions: completed, now: today),
      selectedMonth: buildMonthlyConsistency(
        sessions: completed,
        weeklyGoalDays: weeklyGoalDays,
        meta: meta,
        month: month,
      ),
      monthHistory: monthHistory,
      badges: buildMilestoneBadges(
        totalWorkouts: completed.length,
        totalWeightKg: totalWeight,
        streakWeeks: streakWeeks,
      ),
      totalWorkouts: completed.length,
      totalWeightKg: totalWeight,
      lifetimeStreakWeeks: streakWeeks,
    );
  }
}

class ProgressException implements Exception {
  final String message;
  ProgressException(this.message);
  @override
  String toString() => message;
}

final progressServiceProvider =
    Provider<ProgressService>((ref) => ProgressService());

final progressMetaProvider = StreamProvider.family<ProgressMeta, String>(
  (ref, userId) => ref.watch(progressServiceProvider).watchProgressMeta(userId),
);

final progressSnapshotProvider =
    Provider.family<AsyncValue<ProgressSnapshot>, ProgressSnapshotRequest>(
  (ref, request) {
    if (request.userId.isEmpty) {
      return AsyncValue.data(
        ref.read(progressServiceProvider).buildSnapshot(
              sessions: const [],
              profile: null,
              meta: const ProgressMeta(),
              selectedMonth: request.selectedMonth,
            ),
      );
    }

    final sessions = ref.watch(sessionsStreamProvider(request.userId));
    final meta = ref.watch(progressMetaProvider(request.userId));
    final profile = ref.watch(userProfileProvider(request.userId));

    if (sessions.isLoading || meta.isLoading) {
      return const AsyncValue.loading();
    }

    final sessionList =
        sessions.hasError ? <WorkoutSession>[] : (sessions.valueOrNull ?? []);
    final metaValue =
        meta.hasError ? const ProgressMeta() : (meta.valueOrNull ?? const ProgressMeta());

    return AsyncValue.data(
      ref.read(progressServiceProvider).buildSnapshot(
            sessions: sessionList,
            profile: profile.valueOrNull,
            meta: metaValue,
            selectedMonth: request.selectedMonth,
          ),
    );
  },
);

class ProgressSnapshotRequest {
  final String userId;
  final DateTime? selectedMonth;

  const ProgressSnapshotRequest({
    required this.userId,
    this.selectedMonth,
  });

  @override
  bool operator ==(Object other) =>
      other is ProgressSnapshotRequest &&
      other.userId == userId &&
      other.selectedMonth == selectedMonth;

  @override
  int get hashCode => Object.hash(userId, selectedMonth);
}
