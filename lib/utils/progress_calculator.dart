import '../models/models.dart';
import '../models/progress_models.dart';
import 'muscle_filter.dart';

export 'muscle_filter.dart' show normalizeBodyPart, normalizeBodyParts;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime weekStart(DateTime date) {
  final d = dateOnly(date);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

String weekKey(DateTime date) {
  final start = weekStart(date);
  return '${start.year.toString().padLeft(4, '0')}-'
      '${start.month.toString().padLeft(2, '0')}-'
      '${start.day.toString().padLeft(2, '0')}';
}

String monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

int distinctWorkoutDaysInWeek(List<WorkoutSession> sessions, DateTime week) {
  final start = weekStart(week);
  final end = start.add(const Duration(days: 7));
  final days = <String>{};
  for (final session in sessions) {
    if (!session.isCompleted) continue;
    final day = dateOnly(session.startTime);
    if (!day.isBefore(start) && day.isBefore(end)) {
      days.add('${day.year}-${day.month}-${day.day}');
    }
  }
  return days.length;
}

List<WeekGoalResult> buildWeekResults({
  required List<WorkoutSession> sessions,
  required int weeklyGoalDays,
  required ProgressMeta meta,
  DateTime? now,
  int pastWeeks = 52,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final currentStart = weekStart(today);
  final results = <WeekGoalResult>[];

  for (var i = 0; i < pastWeeks; i++) {
    final start = currentStart.subtract(Duration(days: i * 7));
    final key = weekKey(start);
    final days = distinctWorkoutDaysInWeek(sessions, start);
    final isCurrentWeek = i == 0;
    final hit = days >= weeklyGoalDays;
    final frozen = meta.frozenWeekKey == key;

    results.add(
      WeekGoalResult(
        weekKey: key,
        weekStart: start,
        workoutDays: days,
        goal: weeklyGoalDays,
        hit: hit,
        frozen: frozen,
      ),
    );

    if (isCurrentWeek) continue;
  }

  return results;
}

int computeWeeklyGoalStreak({
  required List<WorkoutSession> sessions,
  required int weeklyGoalDays,
  required ProgressMeta meta,
  DateTime? now,
}) {
  final weeks = buildWeekResults(
    sessions: sessions,
    weeklyGoalDays: weeklyGoalDays,
    meta: meta,
    now: now,
  );

  var streak = 0;
  for (var i = 1; i < weeks.length; i++) {
    final week = weeks[i];
    if (week.hit) {
      streak++;
    } else if (week.frozen) {
      continue;
    } else {
      break;
    }
  }
  return streak;
}

WeeklyGoalStreakSummary buildWeeklyGoalSummary({
  required List<WorkoutSession> sessions,
  required int weeklyGoalDays,
  required ProgressMeta meta,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final currentMonth = monthKey(today);
  final weeks = buildWeekResults(
    sessions: sessions,
    weeklyGoalDays: weeklyGoalDays,
    meta: meta,
    now: today,
  );
  final currentWeek = weeks.first;
  final freezeUsedThisMonth = meta.freezeUsedMonth == currentMonth;
  final freezeActiveThisWeek =
      meta.frozenWeekKey == weekKey(today) && !currentWeek.hit;
  final freezeAvailableThisMonth = !freezeUsedThisMonth;
  final canActivateFreeze = freezeAvailableThisMonth &&
      !freezeActiveThisWeek &&
      !currentWeek.hit;

  return WeeklyGoalStreakSummary(
    streakWeeks: computeWeeklyGoalStreak(
      sessions: sessions,
      weeklyGoalDays: weeklyGoalDays,
      meta: meta,
      now: today,
    ),
    weeklyGoalDays: weeklyGoalDays,
    currentWeek: currentWeek,
    freezeAvailableThisMonth: freezeAvailableThisMonth,
    freezeUsedThisMonth: freezeUsedThisMonth,
    freezeActiveThisWeek: freezeActiveThisWeek,
    canActivateFreeze: canActivateFreeze,
  );
}

BodyPartStatus bodyPartStatus(DateTime? lastTrained, DateTime now) {
  if (lastTrained == null) return BodyPartStatus.never;
  final days = now.difference(dateOnly(lastTrained)).inDays;
  if (days < 7) return BodyPartStatus.active;
  if (days < 14) return BodyPartStatus.stale;
  return BodyPartStatus.neglected;
}

List<BodyPartStreakInfo> computeBodyPartStreaks({
  required List<WorkoutSession> sessions,
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final infos = <BodyPartStreakInfo>[];

  for (final (id, label) in kTrackedBodyParts) {
    final trainedWeeks = <String>{};
    DateTime? lastTrained;

    for (final session in sessions) {
      if (!session.isCompleted) continue;
      final parts = normalizeBodyParts(session.bodyPartsTrained);
      if (!parts.contains(id)) continue;

      final day = dateOnly(session.startTime);
      if (lastTrained == null || day.isAfter(lastTrained)) {
        lastTrained = day;
      }
      trainedWeeks.add(weekKey(session.startTime));
    }

    var weekStreak = 0;
    var cursor = weekStart(today);
    while (true) {
      final key = weekKey(cursor);
      if (!trainedWeeks.contains(key)) break;
      weekStreak++;
      cursor = cursor.subtract(const Duration(days: 7));
    }

    infos.add(
      BodyPartStreakInfo(
        id: id,
        label: label,
        weekStreak: weekStreak,
        lastTrained: lastTrained,
        status: bodyPartStatus(lastTrained, today),
      ),
    );
  }

  return infos;
}

MonthlyConsistency buildMonthlyConsistency({
  required List<WorkoutSession> sessions,
  required int weeklyGoalDays,
  required ProgressMeta meta,
  required DateTime month,
}) {
  final firstOfMonth = DateTime(month.year, month.month, 1);
  final lastOfMonth = DateTime(month.year, month.month + 1, 0);
  final weeks = <WeekGoalResult>[];
  var cursor = weekStart(firstOfMonth);
  final end = weekStart(lastOfMonth).add(const Duration(days: 7));

  while (cursor.isBefore(end)) {
    if (cursor.month == month.month || cursor.add(const Duration(days: 6)).month == month.month) {
      final key = weekKey(cursor);
      final days = distinctWorkoutDaysInWeek(sessions, cursor);
      weeks.add(
        WeekGoalResult(
          weekKey: key,
          weekStart: cursor,
          workoutDays: days,
          goal: weeklyGoalDays,
          hit: days >= weeklyGoalDays,
          frozen: meta.frozenWeekKey == key,
        ),
      );
    }
    cursor = cursor.add(const Duration(days: 7));
  }

  final completeWeeks = weeks.where((w) {
    final weekEnd = w.weekStart.add(const Duration(days: 6));
    return !weekEnd.isAfter(dateOnly(DateTime.now()));
  }).toList();

  final hit = completeWeeks.where((w) => w.hit).length;
  final total = completeWeeks.length;
  final pct = total == 0 ? 0.0 : hit / total;

  return MonthlyConsistency(
    month: firstOfMonth,
    weeksHit: hit,
    weeksTotal: total,
    percentage: pct,
    weeks: weeks,
  );
}

double computeTotalWeightKg(List<WorkoutSession> sessions) {
  var total = 0.0;
  for (final session in sessions) {
    total += session.totalVolumeKg ?? volumeFromWeightLog(session.weightLog);
  }
  return total;
}

double volumeFromWeightLog(Map<String, dynamic>? weightLog) {
  if (weightLog == null) return 0;
  var total = 0.0;
  for (final entries in weightLog.values) {
    if (entries is! List) continue;
    for (final entry in entries) {
      if (entry is! Map) continue;
      final weight = (entry['weight'] as num?)?.toDouble();
      if (weight == null || weight <= 0) continue;
      final unit = entry['unit']?.toString() ?? 'kg';
      total += unit == 'lbs' ? weight * 0.453592 : weight;
    }
  }
  return total;
}

List<MilestoneBadge> buildMilestoneBadges({
  required int totalWorkouts,
  required double totalWeightKg,
  required int streakWeeks,
}) {
  const workoutThresholds = [10, 25, 50, 100, 250, 500];
  const weightThresholds = [1000, 5000, 10000, 25000, 50000];
  const streakThresholds = [4, 12, 26, 52];

  final badges = <MilestoneBadge>[];

  for (final t in workoutThresholds) {
    badges.add(
      MilestoneBadge(
        id: 'workouts_$t',
        category: MilestoneCategory.workouts,
        threshold: t,
        title: '$t Workouts',
        subtitle: 'Lifetime sessions completed',
        emoji: '💪',
        unlocked: totalWorkouts >= t,
        current: totalWorkouts,
        target: t,
      ),
    );
  }

  for (final t in weightThresholds) {
    badges.add(
      MilestoneBadge(
        id: 'weight_$t',
        category: MilestoneCategory.weight,
        threshold: t,
        title: '${_formatKg(t)} Lifted',
        subtitle: 'Total weight logged',
        emoji: '🏋️',
        unlocked: totalWeightKg >= t,
        current: totalWeightKg.round(),
        target: t,
      ),
    );
  }

  for (final t in streakThresholds) {
    badges.add(
      MilestoneBadge(
        id: 'streak_$t',
        category: MilestoneCategory.streak,
        threshold: t,
        title: '$t-Week Streak',
        subtitle: 'Weekly goal consistency',
        emoji: '🔥',
        unlocked: streakWeeks >= t,
        current: streakWeeks,
        target: t,
      ),
    );
  }

  return badges;
}

String _formatKg(int kg) {
  if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(0)}k kg';
  return '$kg kg';
}

String formatLastTrained(DateTime? date, DateTime now) {
  if (date == null) return 'Never';
  final days = dateOnly(now).difference(dateOnly(date)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return '1 day ago';
  if (days < 7) return '$days days ago';
  if (days < 14) return '1 week ago';
  final weeks = (days / 7).floor();
  return '$weeks weeks ago';
}
