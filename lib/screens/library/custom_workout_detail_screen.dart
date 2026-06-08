import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/exercise_media.dart';
import '../../services/auth_service.dart';
import '../../services/library_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/workout_share_utils.dart';
import '../../widgets/share_workout_sheet.dart';

class CustomWorkoutDetailScreen extends ConsumerWidget {
  final String workoutId;

  const CustomWorkoutDetailScreen({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final profileAsync = ref.watch(userProfileProvider(uid));

    return FutureBuilder<CustomWorkout?>(
      future: ref.read(libraryServiceProvider).getCustomWorkout(uid, workoutId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          );
        }

        final workout = snapshot.data;
        if (workout == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: AppTheme.background),
            body: const Center(child: Text('Workout not found')),
          );
        }

        final profile = profileAsync.valueOrNull;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            title: Text(workout.name,
                style: Theme.of(context).textTheme.headlineSmall),
            actions: [
              if (profile != null)
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => ShareWorkoutSheet.show(
                    context,
                    ref,
                    workout: workout,
                    creator: profile,
                  ),
                ),
              if (workout.canPublishToCommunity)
                IconButton(
                  icon: const Icon(Icons.public_outlined),
                  tooltip: 'Publish to Community',
                  onPressed: () =>
                      context.push('/workouts/custom/$workoutId/publish'),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text(
                '${workout.exerciseCount} exercises · ~${workout.estimatedMinutes} min',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (workout.targetBodyParts.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: workout.targetBodyParts
                      .map((p) => _Chip(label: labelTag(p)))
                      .toList(),
                ),
              ],
              if (workout.selectedEquipment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: workout.selectedEquipment
                      .map((e) => _Chip(label: labelTag(e), outlined: true))
                      .toList(),
                ),
              ],
              const SizedBox(height: 24),
              Text('Exercises',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              ...workout.exercises.map((e) => _ExerciseTile(exercise: e)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    context.go('/workout/custom/$workoutId/start'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Workout'),
              ),
              if (profile != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ShareWorkoutSheet.show(
                    context,
                    ref,
                    workout: workout,
                    creator: profile,
                  ),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                ),
              ],
              if (workout.canPublishToCommunity) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/workouts/custom/$workoutId/publish'),
                  icon: const Icon(Icons.public_outlined),
                  label: const Text('Publish to Community'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool outlined;

  const _Chip({required this.label, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final CustomWorkoutExercise exercise;

  const _ExerciseTile({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final detail = exercise.seconds != null
        ? '${exercise.sets} sets × ${exercise.seconds}s'
        : '${exercise.sets} sets × ${exercise.reps ?? 0} reps';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          if (exercise.thumbnailUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: exercise.thumbnailUrl!,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder(),
              ),
            )
          else
            _placeholder(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.exerciseName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '$detail · ${exercise.restSeconds}s rest',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.fitness_center_rounded,
          color: AppTheme.textMuted, size: 22),
    );
  }
}
