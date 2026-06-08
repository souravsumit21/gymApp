import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/exercise_media.dart';
import '../../models/share_models.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/share_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/workout_share_utils.dart';
class SharedWorkoutPreviewScreen extends ConsumerStatefulWidget {
  final String shareId;
  final bool isExternal;

  const SharedWorkoutPreviewScreen({
    super.key,
    required this.shareId,
    this.isExternal = false,
  });

  @override
  ConsumerState<SharedWorkoutPreviewScreen> createState() =>
      _SharedWorkoutPreviewScreenState();
}

class _SharedWorkoutPreviewScreenState
    extends ConsumerState<SharedWorkoutPreviewScreen> {
  WorkoutShareSnapshot? _snapshot;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final shareService = ref.read(shareServiceProvider);

    try {
      if (widget.isExternal) {
        final external = await shareService.getExternalShare(widget.shareId);
        if (external == null) {
          setState(() {
            _loading = false;
            _error = 'This shared workout link is no longer available.';
          });
          return;
        }
        setState(() {
          _snapshot = external.snapshot;
          _loading = false;
        });
        return;
      }

      if (uid == null) {
        setState(() {
          _loading = false;
          _error = 'Sign in to view this shared workout.';
        });
        return;
      }

      final share = await shareService.getInAppShare(uid, widget.shareId);
      if (share == null) {
        setState(() {
          _loading = false;
          _error = 'Shared workout not found.';
        });
        return;
      }

      await shareService.markInAppShareRead(uid, widget.shareId);
      setState(() {
        _snapshot = share.snapshot;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveCopy() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final snapshot = _snapshot;
    if (uid == null || snapshot == null) return;

    setState(() => _saving = true);
    try {
      final workout = await ref.read(shareServiceProvider).saveSharedWorkoutCopy(
            userId: uid,
            snapshot: snapshot,
            sourceShareId: widget.shareId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${workout.name}" added to My Workouts')),
      );
      context.go('/workouts/custom/${workout.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_error != null || _snapshot == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppTheme.background),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              _error ?? 'Workout not found',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ),
      );
    }

    final snapshot = _snapshot!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Shared Workout'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(snapshot.name,
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 6),
          Text(
            'Shared by @${snapshot.creatorUsername}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${snapshot.exerciseCount} exercises · ~${snapshot.estimatedMinutes} min',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (snapshot.targetBodyParts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: snapshot.targetBodyParts
                  .map((p) => _Tag(label: labelTag(p)))
                  .toList(),
            ),
          ],
          if (snapshot.selectedEquipment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: snapshot.selectedEquipment
                  .map((e) => _Tag(label: labelTag(e)))
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          Text('Exercises',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          ...snapshot.exercises.map((e) => _ExerciseRow(exercise: e)),
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
            label: Text(_saving ? 'Saving...' : 'Add to My Workouts'),
          ),
        ],
      ),
    );
  }
}

class SharedWorkoutPreviewFromNotification extends ConsumerWidget {
  final String shareId;
  final String? notificationId;

  const SharedWorkoutPreviewFromNotification({
    super.key,
    required this.shareId,
    this.notificationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (notificationId != null) {
      final uid = ref.watch(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        ref
            .read(notificationServiceProvider)
            .markAsRead(uid, notificationId!);
      }
    }
    return SharedWorkoutPreviewScreen(shareId: shareId);
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          )),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final CustomWorkoutExercise exercise;
  const _ExerciseRow({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final detail = exercise.seconds != null
        ? '${exercise.sets} × ${exercise.seconds}s'
        : '${exercise.sets} × ${exercise.reps ?? 0} reps';

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
                width: 48,
                height: 48,
                fit: BoxFit.cover,
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
}
