import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/exercise_media.dart';
import '../../models/share_models.dart';
import '../../services/auth_service.dart';
import '../../services/community_service.dart';
import '../../services/library_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/workout_share_utils.dart';
import '../../widgets/exercise_media_widget.dart';
import '../../widgets/share_workout_sheet.dart';

class CommunityWorkoutDetailScreen extends ConsumerStatefulWidget {
  final String workoutId;

  const CommunityWorkoutDetailScreen({super.key, required this.workoutId});

  @override
  ConsumerState<CommunityWorkoutDetailScreen> createState() =>
      _CommunityWorkoutDetailScreenState();
}

class _CommunityWorkoutDetailScreenState
    extends ConsumerState<CommunityWorkoutDetailScreen> {
  CommunityWorkout? _workout;
  bool _loading = true;
  bool _saving = false;
  bool _alreadySaved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final workout = await ref
        .read(communityServiceProvider)
        .getCommunityWorkout(widget.workoutId);
    final saved = uid.isNotEmpty
        ? await ref.read(communityServiceProvider).hasUserSavedCommunityWorkout(
              uid,
              widget.workoutId,
            )
        : false;
    if (!mounted) return;
    setState(() {
      _workout = workout;
      _alreadySaved = saved;
      _loading = false;
      if (workout == null) _error = 'Community workout not found.';
    });
  }

  Future<void> _saveCopy() async {
    final workout = _workout;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (workout == null || uid == null) return;

    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(communityServiceProvider)
          .saveCommunityWorkoutCopy(
            userId: uid,
            communityWorkout: workout,
          );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _alreadySaved = true;
      });
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${saved.name}" added to My Workouts')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  Future<void> _share() async {
    final workout = _workout;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (workout == null || uid == null) return;

    final profile = await ref.read(authServiceProvider).loadUserProfile(uid);
    if (profile == null || !context.mounted) return;

    // Build a temporary CustomWorkout from snapshot for sharing
    final tempWorkout = workout.snapshot.toCustomWorkout(
      id: workout.id,
      userId: workout.creatorId,
    );

    await ShareWorkoutSheet.show(
      context,
      ref,
      workout: tempWorkout,
      creator: profile,
      snapshotOverride: workout.snapshot,
    );
  }

  Future<void> _report() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _ReportDialog(),
    );
    if (reason == null || reason.isEmpty) return;

    await ref.read(communityServiceProvider).reportWorkout(
          communityWorkoutId: widget.workoutId,
          reporterId: uid,
          reason: reason,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted. Thank you.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final workout = _workout;
    final library = ref.watch(exerciseLibraryMapProvider);
    if (workout == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppTheme.background),
        body: Center(child: Text(_error ?? 'Not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Text(workout.name,
            style: Theme.of(context).textTheme.headlineSmall),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report',
            onPressed: _report,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(
            '@${workout.creatorUsername}',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            workout.description,
            style: TextStyle(color: AppTheme.textPrimary, height: 1.45),
          ),
          const SizedBox(height: 12),
          Text(
            '${workout.exerciseCount} exercises · ~${workout.estimatedMinutes} min · ${workout.saveCount} saves',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(label: labelTag(workout.experienceLevel)),
              _Tag(label: labelTag(workout.workoutMode)),
              ...workout.bodyParts.map((p) => _Tag(label: labelTag(p))),
              ...workout.equipment.map((e) => _Tag(label: labelTag(e))),
            ],
          ),
          const SizedBox(height: 24),
          Text('Exercises',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          ...workout.snapshot.exercises.map(
            (e) => _ExerciseTile(
              exercise: e,
              libraryMedia: library[e.exerciseId]?.media,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _saving ? null : _saveCopy,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.background,
                    ),
                  )
                : const Icon(Icons.add_rounded),
            label: Text(
              _saving
                  ? 'Saving...'
                  : _alreadySaved
                      ? 'Add Another Copy'
                      : 'Add to My Workouts',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: AppTheme.textLabel,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          )),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final CustomWorkoutExercise exercise;
  final ExerciseMedia? libraryMedia;

  const _ExerciseTile({
    required this.exercise,
    this.libraryMedia,
  });

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.exerciseName,
                    style: Theme.of(context).textTheme.headlineSmall),
                Text('$detail · ${exercise.restSeconds}s rest',
                    style: Theme.of(context).textTheme.bodyMedium),
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

class _ReportDialog extends StatefulWidget {
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _controller = TextEditingController();
  String _selected = 'spam';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Report Workout'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...['spam', 'inappropriate', 'misleading', 'other'].map(
            (reason) => RadioListTile<String>(
              title: Text(labelTag(reason)),
              value: reason,
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
            ),
          ),
          if (_selected == 'other')
            TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: 'Details'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final reason = _selected == 'other'
                ? _controller.text.trim()
                : _selected;
            Navigator.pop(context, reason);
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
