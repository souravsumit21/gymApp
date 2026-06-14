import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class WorkoutPauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onEnd;

  const WorkoutPauseOverlay({
    super.key,
    required this.onResume,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onResume,
      child: Container(
        color: AppTheme.background.withOpacity(0.92),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(28),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Paused',
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 8),
                Text(
                  'Tap anywhere to resume',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Press back again to leave',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: AppTheme.textLabel),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: onEnd,
                  child: const Text('End Workout',
                      style: TextStyle(color: AppTheme.accent)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
