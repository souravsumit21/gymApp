import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/exercise_media.dart';
import '../../services/auth_service.dart';
import '../../services/library_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/exercise_media_widget.dart';
import '../../widgets/share_workout_sheet.dart';

class CustomWorkoutDetailScreen extends ConsumerStatefulWidget {
  final String workoutId;

  const CustomWorkoutDetailScreen({super.key, required this.workoutId});

  @override
  ConsumerState<CustomWorkoutDetailScreen> createState() =>
      _CustomWorkoutDetailScreenState();
}

class _CustomWorkoutDetailScreenState
    extends ConsumerState<CustomWorkoutDetailScreen> {
  late Future<CustomWorkout?> _workoutFuture;

  @override
  void initState() {
    super.initState();
    _workoutFuture = _loadWorkout();
  }

  Future<CustomWorkout?> _loadWorkout() {
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    return ref
        .read(libraryServiceProvider)
        .getCustomWorkout(uid, widget.workoutId);
  }

  void _reloadWorkout() {
    setState(() => _workoutFuture = _loadWorkout());
  }

  Future<void> _openEdit() async {
    await context.push('/workouts/custom/${widget.workoutId}/edit');
    _reloadWorkout();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final profileAsync = ref.watch(userProfileProvider(uid));

    return FutureBuilder<CustomWorkout?>(
      future: _workoutFuture,
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
        final library = ref.watch(exerciseLibraryMapProvider);

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            title: Text(workout.name,
                style: Theme.of(context).textTheme.headlineSmall),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Workout',
                onPressed: _openEdit,
              ),
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
                  onPressed: () => context
                      .push('/workouts/custom/${widget.workoutId}/publish'),
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
              const SizedBox(height: 24),
              Text('Exercises',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              ...workout.exercises.asMap().entries.map(
                (entry) => _ExerciseTile(
                  index: entry.key,
                  exercise: entry.value,
                  libraryMedia: library[entry.value.exerciseId]?.media,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    context.go('/workout/custom/${widget.workoutId}/start'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Workout'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final int index;
  final CustomWorkoutExercise exercise;
  final ExerciseMedia? libraryMedia;

  const _ExerciseTile({
    required this.index,
    required this.exercise,
    required this.libraryMedia,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: ExerciseMediaWidget(
                media: resolveExerciseMedia(
                  exerciseId: exercise.exerciseId,
                  libraryMedia: libraryMedia,
                  savedThumbnailUrl: exercise.thumbnailUrl,
                ),
                fit: BoxFit.cover,
                autoplayVideo: false,
                loopVideo: false,
                placeholder: _placeholder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 10,
            backgroundColor: AppTheme.primary,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: AppTheme.background,
                fontWeight: FontWeight.w800,
                fontSize: AppTheme.textLabel,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              exercise.exerciseName,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: AppTheme.textBody,
              ),
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
