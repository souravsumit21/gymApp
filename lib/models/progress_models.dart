/// Canonical body parts tracked on the progress screen.
const kTrackedBodyParts = [
  ('chest', 'Chest'),
  ('back', 'Back'),
  ('shoulders', 'Shoulders'),
  ('biceps', 'Biceps'),
  ('triceps', 'Triceps'),
  ('quads', 'Quads'),
  ('hamstrings', 'Hamstrings'),
  ('glutes', 'Glutes'),
  ('core', 'Core'),
  ('forearms', 'Forearms'),
];

enum BodyPartStatus { active, stale, neglected, never }

enum MilestoneCategory { workouts, weight, streak }

class BodyPartStreakInfo {
  final String id;
  final String label;
  final int weekStreak;
  final DateTime? lastTrained;
  final BodyPartStatus status;

  const BodyPartStreakInfo({
    required this.id,
    required this.label,
    required this.weekStreak,
    required this.lastTrained,
    required this.status,
  });
}

class WeekGoalResult {
  final String weekKey;
  final DateTime weekStart;
  final int workoutDays;
  final int goal;
  final bool hit;
  final bool frozen;

  const WeekGoalResult({
    required this.weekKey,
    required this.weekStart,
    required this.workoutDays,
    required this.goal,
    required this.hit,
    this.frozen = false,
  });
}

class WeeklyGoalStreakSummary {
  final int streakWeeks;
  final int weeklyGoalDays;
  final WeekGoalResult currentWeek;
  final bool freezeAvailableThisMonth;
  final bool freezeUsedThisMonth;
  final bool freezeActiveThisWeek;
  final bool canActivateFreeze;

  const WeeklyGoalStreakSummary({
    required this.streakWeeks,
    required this.weeklyGoalDays,
    required this.currentWeek,
    required this.freezeAvailableThisMonth,
    required this.freezeUsedThisMonth,
    required this.freezeActiveThisWeek,
    required this.canActivateFreeze,
  });
}

class MonthlyConsistency {
  final DateTime month;
  final int weeksHit;
  final int weeksTotal;
  final double percentage;
  final List<WeekGoalResult> weeks;

  const MonthlyConsistency({
    required this.month,
    required this.weeksHit,
    required this.weeksTotal,
    required this.percentage,
    required this.weeks,
  });
}

class MilestoneBadge {
  final String id;
  final MilestoneCategory category;
  final int threshold;
  final String title;
  final String subtitle;
  final String emoji;
  final bool unlocked;
  final num current;
  final num target;

  const MilestoneBadge({
    required this.id,
    required this.category,
    required this.threshold,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.unlocked,
    required this.current,
    required this.target,
  });

  double get progressFraction =>
      target == 0 ? 0 : (current / target).clamp(0, 1).toDouble();
}

class ProgressMeta {
  final String? freezeUsedMonth;
  final String? frozenWeekKey;

  const ProgressMeta({
    this.freezeUsedMonth,
    this.frozenWeekKey,
  });

  Map<String, dynamic> toMap() => {
        'freezeUsedMonth': freezeUsedMonth,
        'frozenWeekKey': frozenWeekKey,
      };

  factory ProgressMeta.fromMap(Map<String, dynamic>? m) => ProgressMeta(
        freezeUsedMonth: m?['freezeUsedMonth'],
        frozenWeekKey: m?['frozenWeekKey'],
      );

  ProgressMeta copyWith({
    String? freezeUsedMonth,
    String? frozenWeekKey,
    bool clearFrozenWeekKey = false,
  }) =>
      ProgressMeta(
        freezeUsedMonth: freezeUsedMonth ?? this.freezeUsedMonth,
        frozenWeekKey:
            clearFrozenWeekKey ? null : (frozenWeekKey ?? this.frozenWeekKey),
      );
}

class ProgressSnapshot {
  final WeeklyGoalStreakSummary weeklyStreak;
  final List<BodyPartStreakInfo> bodyPartStreaks;
  final MonthlyConsistency selectedMonth;
  final List<MonthlyConsistency> monthHistory;
  final List<MilestoneBadge> badges;
  final int totalWorkouts;
  final double totalWeightKg;
  final int lifetimeStreakWeeks;

  const ProgressSnapshot({
    required this.weeklyStreak,
    required this.bodyPartStreaks,
    required this.selectedMonth,
    required this.monthHistory,
    required this.badges,
    required this.totalWorkouts,
    required this.totalWeightKg,
    required this.lifetimeStreakWeeks,
  });
}
