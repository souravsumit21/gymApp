import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/exercise_media.dart';
import '../../services/auth_service.dart';
import '../../services/community_service.dart';
import '../../services/library_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/workout_share_utils.dart';
import '../../widgets/username_setup_dialog.dart';

class PublishWorkoutScreen extends ConsumerStatefulWidget {
  final String workoutId;

  const PublishWorkoutScreen({super.key, required this.workoutId});

  @override
  ConsumerState<PublishWorkoutScreen> createState() =>
      _PublishWorkoutScreenState();
}

class _PublishWorkoutScreenState extends ConsumerState<PublishWorkoutScreen> {
  final _descriptionController = TextEditingController();
  String _workoutMode = 'standard';
  bool _loading = true;
  bool _publishing = false;
  CustomWorkout? _workout;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final workout = await ref
        .read(libraryServiceProvider)
        .getCustomWorkout(uid, widget.workoutId);
    if (!mounted) return;
    setState(() {
      _workout = workout;
      _loading = false;
      if (workout != null && !workout.canPublishToCommunity) {
        _error = 'Imported workouts cannot be published to the community.';
      }
    });
  }

  Future<void> _publish() async {
    final workout = _workout;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (workout == null || uid == null) return;

    final description = _descriptionController.text.trim();
    if (description.length < 10) {
      setState(() => _error = 'Add a short description (at least 10 characters).');
      return;
    }

    setState(() {
      _publishing = true;
      _error = null;
    });

    try {
      final profile = await ref.read(authServiceProvider).loadUserProfile(uid);
      if (profile == null) throw CommunityException('Profile not found.');

      final ready = await requireUsername(context, ref, profile);
      if (ready == null) {
        if (mounted) setState(() => _publishing = false);
        return;
      }

      final communityId = await ref.read(communityServiceProvider).publishWorkout(
            workout: workout,
            creator: ready,
            description: description,
            workoutMode: _workoutMode,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Published to Community Library')),
      );
      context.go('/community/$communityId');
    } on CommunityException catch (e) {
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final workout = _workout;
    if (workout == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppTheme.background),
        body: const Center(child: Text('Workout not found')),
      );
    }

    final bodyParts = workout.targetBodyParts.isNotEmpty
        ? workout.targetBodyParts
        : workout.targetMuscles;
    final experience = deriveExperienceLevel(workout.exercises);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Publish to Community'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(workout.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            '${workout.exerciseCount} exercises · ~${workout.estimatedMinutes} min',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          const Text(
            'Personal weights are stripped. Only exercise structure, sets, reps, and rest times are published.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            maxLength: 280,
            decoration: const InputDecoration(
              labelText: 'Short description',
              hintText: 'What makes this workout great?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          Text('Workout mode', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'standard', label: Text('Standard')),
              ButtonSegment(value: 'circuit', label: Text('Circuit')),
            ],
            selected: {_workoutMode},
            onSelectionChanged: (s) =>
                setState(() => _workoutMode = s.first),
          ),
          const SizedBox(height: 20),
          Text('Auto-filled tags', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(label: labelTag(experience)),
              ...bodyParts.map((p) => _Tag(label: labelTag(p))),
              ...workout.selectedEquipment.map((e) => _Tag(label: labelTag(e))),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppTheme.accent)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed:
                _publishing || !workout.canPublishToCommunity ? null : _publish,
            child: Text(_publishing ? 'Publishing...' : 'Publish to Community'),
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          )),
    );
  }
}
