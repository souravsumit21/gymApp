import 'package:flutter/material.dart';
import '../../models/progress_models.dart';
import '../../theme/app_theme.dart';

class WeeklyStreakCard extends StatelessWidget {
  final WeeklyGoalStreakSummary summary;
  final VoidCallback? onActivateFreeze;
  final bool activatingFreeze;

  const WeeklyStreakCard({
    super.key,
    required this.summary,
    this.onActivateFreeze,
    this.activatingFreeze = false,
  });

  @override
  Widget build(BuildContext context) {
    final current = summary.currentWeek;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accent.withOpacity(0.14),
            AppTheme.cardBg,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: AppTheme.accent, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${summary.streakWeeks}',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        height: 1,
                      ),
                    ),
                    const Text(
                      'week streak',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Goal: ${summary.weeklyGoalDays} workout days per week',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'This week: ${current.workoutDays}/${current.goal} days',
            style: TextStyle(
              color: current.hit ? AppTheme.primary : AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _FreezeStatus(
            summary: summary,
            onActivateFreeze: onActivateFreeze,
            activatingFreeze: activatingFreeze,
          ),
        ],
      ),
    );
  }
}

class _FreezeStatus extends StatelessWidget {
  final WeeklyGoalStreakSummary summary;
  final VoidCallback? onActivateFreeze;
  final bool activatingFreeze;

  const _FreezeStatus({
    required this.summary,
    this.onActivateFreeze,
    required this.activatingFreeze,
  });

  @override
  Widget build(BuildContext context) {
    if (summary.freezeActiveThisWeek) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.accentYellow.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accentYellow.withOpacity(0.35)),
        ),
        child: const Row(
          children: [
            Icon(Icons.ac_unit_rounded, color: AppTheme.accentYellow, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Freeze active — this week won\'t break your streak',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (summary.freezeUsedThisMonth) {
      return const Row(
        children: [
          Icon(Icons.ac_unit_rounded, color: AppTheme.textMuted, size: 18),
          SizedBox(width: 8),
          Text(
            'Freeze used this month',
            style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.ac_unit_rounded, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            '1 freeze available',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (summary.canActivateFreeze)
          TextButton(
            onPressed: activatingFreeze ? null : onActivateFreeze,
            child: Text(activatingFreeze ? 'Activating...' : 'Use Freeze'),
          ),
      ],
    );
  }
}
