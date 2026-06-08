import 'package:flutter/material.dart';
import '../../models/progress_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/progress_calculator.dart';

class BodyPartStreaksGrid extends StatelessWidget {
  final List<BodyPartStreakInfo> streaks;

  const BodyPartStreaksGrid({super.key, required this.streaks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Body Part Streaks',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text(
          'Balanced training at a glance',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
          ),
          itemCount: streaks.length,
          itemBuilder: (context, i) => _BodyPartCard(info: streaks[i]),
        ),
      ],
    );
  }
}

class _BodyPartCard extends StatelessWidget {
  final BodyPartStreakInfo info;

  const _BodyPartCard({required this.info});

  Color get _accent {
    switch (info.status) {
      case BodyPartStatus.active:
        return const Color(0xFF16A34A);
      case BodyPartStatus.stale:
        return AppTheme.accentYellow;
      case BodyPartStatus.neglected:
        return AppTheme.accent;
      case BodyPartStatus.never:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  info.label,
                  style: Theme.of(context).textTheme.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            info.weekStreak > 0 ? '${info.weekStreak} weeks' : '—',
            style: TextStyle(
              color: _accent,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatLastTrained(info.lastTrained, now),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
