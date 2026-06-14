import 'package:flutter/material.dart';

import '../models/exercise_media.dart';
import '../theme/app_theme.dart';
import 'exercise_media_widget.dart';

/// Thin orange workout progress strip shown at the top of active sessions.
class WorkoutProgressBar extends StatelessWidget {
  final double progress;

  const WorkoutProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          minHeight: 4,
          backgroundColor: AppTheme.border,
          color: AppTheme.accent,
        ),
      ),
    );
  }
}

/// Blur strength for next-exercise video previews shown during rest.
const double kRestPreviewBlurSigma = 5;

/// Minimal full-screen exercise session layout — video on top, counter below.
class MinimalExerciseSessionLayout extends StatelessWidget {
  final ExerciseMedia? media;
  final String progressLabel;
  final String exerciseName;
  final String? counterText;
  final double mediaBlurSigma;
  final VoidCallback? onTap;
  final VoidCallback onAction;
  final IconData actionIcon;
  final String actionTooltip;
  final Widget? footer;
  final bool showPauseHint;
  final bool isRestScreen;

  const MinimalExerciseSessionLayout({
    super.key,
    this.media,
    required this.progressLabel,
    required this.exerciseName,
    this.counterText,
    this.mediaBlurSigma = 0,
    this.onTap,
    required this.onAction,
    this.actionIcon = Icons.skip_next_rounded,
    this.actionTooltip = 'Next',
    this.footer,
    this.showPauseHint = false,
    this.isRestScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 11,
              child: AnimatedMediaBlur(
                sigma: mediaBlurSigma,
                child: ColoredBox(
                  color: AppTheme.surfaceElevated,
                  child: media != null
                      ? ExerciseMediaWidget(
                          media: media,
                          fit: BoxFit.cover,
                          videoZoom: 1.05,
                          placeholder: const _VideoPlaceholder(),
                        )
                      : const _VideoPlaceholder(),
                ),
              ),
            ),
            Expanded(
              flex: 9,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isRestScreen) ...[
                      Text(
                        'Rest',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Upcoming · $exerciseName',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      Text(
                        progressLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        exerciseName,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (counterText != null && counterText!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        counterText!,
                        style: AppTypography.statHero(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (showPauseHint) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Tap screen to pause',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: AppTheme.textCaption,
                        ),
                      ),
                    ],
                    if (footer != null) ...[
                      const SizedBox(height: 16),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        if (onTap != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onTap,
            ),
          ),
        Positioned(
          right: 20,
          bottom: 28,
          child: FloatingActionButton(
            onPressed: onAction,
            tooltip: actionTooltip,
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            highlightElevation: 0,
            shape: const CircleBorder(),
            child: Icon(actionIcon),
          ),
        ),
      ],
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.fitness_center_rounded,
        color: AppTheme.textMuted,
        size: 48,
      ),
    );
  }
}
