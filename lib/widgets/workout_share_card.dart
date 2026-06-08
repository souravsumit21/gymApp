import 'package:flutter/material.dart';
import '../models/share_models.dart';
import '../theme/app_theme.dart';
import '../utils/share_config.dart';
import '../utils/workout_share_utils.dart';

/// Visual workout card rendered for external sharing.
class WorkoutShareCard extends StatelessWidget {
  final WorkoutShareSnapshot snapshot;

  const WorkoutShareCard({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final exercises = snapshot.exercises.take(6).toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fitness_center_rounded,
                      color: AppTheme.background, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'by @${snapshot.creatorUsername}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${snapshot.exerciseCount} exercises · ~${snapshot.estimatedMinutes} min',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (snapshot.targetBodyParts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: snapshot.targetBodyParts
                    .take(5)
                    .map(
                      (p) => _TagChip(
                        label: labelTag(p),
                        color: AppTheme.surfaceElevated,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (snapshot.selectedEquipment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: snapshot.selectedEquipment
                    .take(4)
                    .map(
                      (e) => _TagChip(
                        label: labelTag(e),
                        color: AppTheme.primary.withOpacity(0.08),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 18),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 12),
            ...exercises.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    formatExerciseLine(e),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                      height: 1.35,
                    ),
                  ),
                )),
            if (snapshot.exercises.length > 6)
              Text(
                '+ ${snapshot.exercises.length - 6} more exercises',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              ShareConfig.appName,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
