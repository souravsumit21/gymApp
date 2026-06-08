import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/progress_models.dart';
import '../../theme/app_theme.dart';

class ConsistencyScoreSection extends StatelessWidget {
  final MonthlyConsistency month;
  final List<MonthlyConsistency> history;
  final ValueChanged<DateTime> onMonthChanged;

  const ConsistencyScoreSection({
    super.key,
    required this.month,
    required this.history,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (month.percentage * 100).round();
    final monthLabel = DateFormat.yMMMM().format(month.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Consistency Score',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            IconButton(
              onPressed: history.length < 2
                  ? null
                  : () {
                      final idx = history.indexWhere(
                        (m) =>
                            m.month.year == month.month.year &&
                            m.month.month == month.month.month,
                      );
                      if (idx < history.length - 1) {
                        onMonthChanged(history[idx + 1].month);
                      }
                    },
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(monthLabel,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
              onPressed: () {
                final idx = history.indexWhere(
                  (m) =>
                      m.month.year == month.month.year &&
                      m.month.month == month.month.month,
                );
                if (idx > 0) {
                  onMonthChanged(history[idx - 1].month);
                }
              },
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          month.weeksTotal == 0
              ? 'No complete weeks yet this month'
              : '$pct% — you hit ${month.weeksHit} of ${month.weeksTotal} weeks',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: month.weeksTotal == 0 ? 0 : month.percentage,
                  minHeight: 10,
                  backgroundColor: AppTheme.surfaceElevated,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              _WeekHeatmap(weeks: month.weeks),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekHeatmap extends StatelessWidget {
  final List<WeekGoalResult> weeks;

  const _WeekHeatmap({required this.weeks});

  @override
  Widget build(BuildContext context) {
    if (weeks.isEmpty) {
      return const Text('No weeks in this month yet',
          style: TextStyle(color: AppTheme.textMuted));
    }

    return Row(
      children: weeks.map((week) {
        final label = 'W${((week.weekStart.day - 1) ~/ 7) + 1}';
        Color color;
        if (week.hit) {
          color = AppTheme.primary;
        } else if (week.frozen) {
          color = AppTheme.accentYellow;
        } else {
          color = AppTheme.surfaceElevated;
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              children: [
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: week.hit || week.frozen
                          ? Colors.transparent
                          : AppTheme.border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      week.hit
                          ? '✓'
                          : week.frozen
                              ? '❄'
                              : '·',
                      style: TextStyle(
                        color: week.hit
                            ? AppTheme.background
                            : AppTheme.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
