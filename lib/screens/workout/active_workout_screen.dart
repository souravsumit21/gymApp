// lib/screens/workout/active_workout_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../models/exercise_media.dart';
import '../../services/auth_service.dart';
import '../../services/voice_cue_service.dart';
import '../../services/workout_service.dart';
import '../../data/exercise_library_data.dart';
import '../../theme/app_theme.dart';

const _uuid = Uuid();

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  final String planId;
  final String dayId;

  const ActiveWorkoutScreen({
    super.key,
    required this.planId,
    required this.dayId,
  });

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  WorkoutDay? _day;
  int _currentIndex = 0;
  int _currentSet = 1;
  bool _resting = false;
  int _restSecondsLeft = 0;
  Timer? _restTimer;
  final List<String> _completedExerciseIds = [];
  int _totalSets = 0;
  late DateTime _startTime;
  bool _announcedWorkoutStart = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_day == null) _loadDay();
  }

  Future<void> _loadDay() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final plans = await ref.read(workoutServiceProvider).getPlans(uid);
    final plan = plans.where((p) => p.id == widget.planId).firstOrNull;
    if (plan != null) {
      final day = plan.days.where((d) => d.id == widget.dayId).firstOrNull;
      if (mounted) {
        setState(() => _day = day);
        _announceCurrentExercise();
      }
    }
  }

  WorkoutSet? get _currentExercise {
    if (_day == null || _currentIndex >= _day!.exercises.length) return null;
    return _day!.exercises[_currentIndex];
  }

  LibraryExercise? get _currentLibraryEx {
    final ex = _currentExercise;
    if (ex == null) return null;
    return getExerciseById(ex.exerciseId) ?? _fallbackExercise(ex.exerciseId);
  }

  LibraryExercise _fallbackExercise(String id) => LibraryExercise(
        id: id,
        name: id.replaceAll('_', ' ').toUpperCase(),
        description: '',
        instructions: '',
        muscleGroups: [],
        requiredEquipment: ['none'],
        difficulty: 'beginner',
        category: 'strength',
      );

  LibraryExercise? getExerciseById(String id) {
    try {
      return kExerciseLibrary.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  void _completeSet() {
    final ex = _currentExercise!;
    _totalSets++;

    if (_currentSet < ex.sets) {
      // More sets — start rest
      setState(() {
        _currentSet++;
        _resting = true;
        _restSecondsLeft = _restSeconds(ex.restSeconds);
      });
      ref.read(voiceCueServiceProvider).announceRest();
      _startRestTimer();
    } else {
      // All sets done — move to next exercise
      _completedExerciseIds.add(ex.exerciseId);
      setState(() {
        _currentSet = 1;
        _resting = false;
      });
      _restTimer?.cancel();

      if (_currentIndex < (_day?.exercises.length ?? 1) - 1) {
        setState(() => _currentIndex++);
        _announceCurrentExercise();
      } else {
        _finishWorkout();
      }
    }
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _restSecondsLeft--;
        if (_restSecondsLeft <= 0) {
          _resting = false;
          timer.cancel();
        }
      });
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _resting = false;
      _restSecondsLeft = 0;
    });
  }

  void _announceCurrentExercise() {
    final name = _currentLibraryEx?.name ?? _currentExercise?.exerciseId ?? '';
    final voice = ref.read(voiceCueServiceProvider);
    if (_announcedWorkoutStart) {
      voice.announceBegin();
      return;
    }
    _announcedWorkoutStart = true;
    voice.announceWorkoutStart(name);
  }

  int _restSeconds(int seconds) => seconds < 5 ? 5 : seconds;

  Future<void> _finishWorkout() async {
    _restTimer?.cancel();
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final endTime = DateTime.now();
    final duration = endTime.difference(_startTime).inMinutes;

    final session = WorkoutSession(
      id: _uuid.v4(),
      userId: uid,
      planId: widget.planId,
      dayId: widget.dayId,
      dayName: _day?.name ?? 'Workout',
      startTime: _startTime,
      endTime: endTime,
      durationMinutes: duration.clamp(1, 999),
      completedExerciseIds: _completedExerciseIds,
      totalSets: _totalSets,
      caloriesBurned: _estimateCalories(),
    );

    await ref.read(workoutServiceProvider).saveSession(session);

    if (mounted) _showCompletionSheet(session);
  }

  int _estimateCalories() {
    // Simple MET-based estimate using 70kg default
    final minutes = DateTime.now().difference(_startTime).inMinutes;
    return (minutes * 5).clamp(0, 9999);
  }

  void _showCompletionSheet(WorkoutSession session) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _WorkoutCompleteSheet(
        session: session,
        onDone: () {
          Navigator.of(ctx).pop();
          context.go('/workouts');
        },
      ),
    );
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    ref.read(voiceCueServiceProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_day == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Text('Loading workout...'),
        ),
      );
    }

    final exercises = _day!.exercises;
    final libEx = _currentLibraryEx;
    final ex = _currentExercise;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _confirmQuit(),
                    icon: const Icon(Icons.close,
                        color: AppTheme.textSecondary, size: 22),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _day!.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Exercise ${_currentIndex + 1} of ${exercises.length}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  // Timer
                  _ElapsedTimer(startTime: _startTime),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentIndex + (_currentSet - 1) / (ex?.sets ?? 1)) /
                      exercises.length,
                  backgroundColor: AppTheme.border,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  minHeight: 4,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Main content
            Expanded(
              child: _resting
                  ? _RestView(
                      secondsLeft: _restSecondsLeft,
                      totalRest: ex?.restSeconds ?? 60,
                      onSkip: _skipRest,
                      nextExercise: _currentIndex < exercises.length - 1
                          ? getExerciseById(exercises[_currentIndex].exerciseId)
                              ?.name
                          : null,
                    )
                  : _ExerciseView(
                      exercise: libEx,
                      workoutSet: ex,
                      currentSet: _currentSet,
                      totalSets: ex?.sets ?? 0,
                    ),
            ),

            // Bottom action
            if (!_resting)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: ElevatedButton(
                  onPressed: ex != null ? _completeSet : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _currentSet < (ex?.sets ?? 0)
                        ? 'Complete Set $_currentSet ✓'
                        : _currentIndex < exercises.length - 1
                            ? 'Next Exercise →'
                            : 'Finish Workout 🎉',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmQuit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Quit workout?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Your progress will not be saved.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep going',
                style: TextStyle(color: AppTheme.primary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/workouts');
            },
            child: const Text('Quit', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Exercise view with GIF
// ─────────────────────────────────────────────
class _ExerciseView extends StatelessWidget {
  final LibraryExercise? exercise;
  final WorkoutSet? workoutSet;
  final int currentSet;
  final int totalSets;

  const _ExerciseView({
    required this.exercise,
    required this.workoutSet,
    required this.currentSet,
    required this.totalSets,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // GIF / media
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 240,
              width: double.infinity,
              child: exercise?.media?.displayUrl != null
                  ? CachedNetworkImage(
                      imageUrl: exercise!.media!.displayUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppTheme.surfaceElevated,
                        child: const Center(
                          child: Icon(Icons.fitness_center_rounded,
                              color: AppTheme.textMuted, size: 56),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.surfaceElevated,
                        child: const Center(
                          child: Icon(Icons.fitness_center_rounded,
                              color: AppTheme.textMuted, size: 56),
                        ),
                      ),
                    )
                  : Container(
                      color: AppTheme.surfaceElevated,
                      child: const Center(
                        child: Icon(Icons.fitness_center_rounded,
                            color: AppTheme.textMuted, size: 56),
                      ),
                    ),
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // Exercise name
          Text(
            exercise?.name ?? 'Exercise',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  textBaseline: TextBaseline.alphabetic,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 16),

          // Set indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              totalSets,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: i < currentSet - 1
                      ? AppTheme.primary
                      : i == currentSet - 1
                          ? AppTheme.primary.withOpacity(0.2)
                          : AppTheme.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i == currentSet - 1
                        ? AppTheme.primary
                        : AppTheme.border,
                  ),
                ),
                child: Center(
                  child: i < currentSet - 1
                      ? const Icon(Icons.check,
                          color: AppTheme.background, size: 16)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: i == currentSet - 1
                                ? AppTheme.primary
                                : AppTheme.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 150.ms),

          const SizedBox(height: 16),

          // Reps/time display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  children: [
                    Text(
                      workoutSet?.seconds != null
                          ? '${workoutSet!.seconds}s'
                          : '${workoutSet?.reps ?? '?'}',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      workoutSet?.seconds != null ? 'seconds' : 'reps',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).scale(delay: 200.ms),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Rest timer view
// ─────────────────────────────────────────────
class _RestView extends StatelessWidget {
  final int secondsLeft;
  final int totalRest;
  final VoidCallback onSkip;
  final String? nextExercise;

  const _RestView({
    required this.secondsLeft,
    required this.totalRest,
    required this.onSkip,
    this.nextExercise,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😮‍💨', style: TextStyle(fontSize: 56))
                .animate()
                .scale(),
            const SizedBox(height: 16),
            Text('Rest', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 32),
            Text(
              '$secondsLeft',
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 72,
                fontWeight: FontWeight.w900,
              ),
            ).animate().fadeIn(),
            const SizedBox(height: 32),
            if (nextExercise != null)
              Text(
                'Next: $nextExercise',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: IconButton.filledTonal(
            tooltip: 'Skip',
            onPressed: onSkip,
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Elapsed timer
// ─────────────────────────────────────────────
class _ElapsedTimer extends StatefulWidget {
  final DateTime startTime;
  const _ElapsedTimer({required this.startTime});

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  late Timer _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.startTime);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.startTime);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      '$m:$s',
      style: const TextStyle(
        color: AppTheme.primary,
        fontWeight: FontWeight.w700,
        fontSize: 16,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Completion sheet
// ─────────────────────────────────────────────
class _WorkoutCompleteSheet extends StatelessWidget {
  final WorkoutSession session;
  final VoidCallback onDone;

  const _WorkoutCompleteSheet({required this.session, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 56))
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 16),
          Text('Workout Complete!',
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(session.dayName,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  )),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatPill('⏱️', '${session.durationMinutes} min'),
              _StatPill('📦', '${session.totalSets} sets'),
              _StatPill('🔥', '~${session.caloriesBurned} kcal'),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onDone,
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String icon;
  final String label;
  const _StatPill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            )),
      ],
    );
  }
}
