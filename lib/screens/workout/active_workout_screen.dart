// lib/screens/workout/active_workout_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../models/exercise_media.dart';
import '../../services/auth_service.dart';
import '../../services/library_service.dart';
import '../../services/voice_cue_service.dart';
import '../../services/workout_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/back_navigation.dart';
import '../../utils/progress_calculator.dart';
import '../../widgets/minimal_exercise_session_layout.dart';
import '../../widgets/workout_pause_overlay.dart';

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
  bool _paused = false;
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
    final library = ref.read(exerciseLibraryMapProvider);
    return library[ex.exerciseId] ?? _fallbackExercise(ex.exerciseId);
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
      if (_paused) return;
      setState(() {
        _restSecondsLeft--;
        if (_restSecondsLeft <= 0) {
          _resting = false;
          timer.cancel();
        }
      });
    });
  }

  void _pauseWorkout() {
    if (_paused) return;
    ref.read(voiceCueServiceProvider).pause();
    setState(() => _paused = true);
  }

  void _resumeWorkout() {
    if (!_paused) return;
    setState(() => _paused = false);
  }

  void _leaveWorkout() {
    _restTimer?.cancel();
    ref.read(voiceCueServiceProvider).stop();
    AppBackNavigation.navigateBack(
      context,
      fallback: '/workouts/${widget.planId}',
    );
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

    final bodyParts = <String>{};
    final target = _day?.targetBodyPart;
    if (target != null) {
      bodyParts.addAll(normalizeBodyParts([target]));
    }

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
      bodyPartsTrained: bodyParts.toList(),
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

    final progress = (_currentIndex + (_currentSet - 1) / (ex?.sets ?? 1)) /
        exercises.length;

    return AppBackNavigation.workoutScope(
      isActiveSession: true,
      isPaused: _paused,
      pauseBeforeLeave: true,
      onPause: _pauseWorkout,
      onBack: _leaveWorkout,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceElevated,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  WorkoutProgressBar(progress: progress),
                  Expanded(
                    child: _resting
                        ? _RestView(
                            secondsLeft: _restSecondsLeft,
                            onSkip: _skipRest,
                            exerciseName: libEx?.name ?? 'Rest',
                            media: libEx?.media,
                            mediaBlurSigma: kRestPreviewBlurSigma,
                          )
                        : _ExerciseView(
                            exercise: libEx,
                            workoutSet: ex,
                            currentSet: _currentSet,
                            totalSets: ex?.sets ?? 0,
                            onCompleteSet: ex != null ? _completeSet : () {},
                          ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                child: IconButton(
                  onPressed: _confirmQuit,
                  icon: const Icon(Icons.close,
                      color: AppTheme.textSecondary, size: 22),
                  tooltip: 'End workout',
                ),
              ),
              Positioned(
                top: 4,
                right: 8,
                child: _ElapsedTimer(startTime: _startTime),
              ),
              if (_paused)
                WorkoutPauseOverlay(
                  onResume: _resumeWorkout,
                  onEnd: _confirmQuit,
                ),
            ],
          ),
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
        title: Text('Quit workout?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Your progress will not be saved.',
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
  final VoidCallback onCompleteSet;

  const _ExerciseView({
    required this.exercise,
    required this.workoutSet,
    required this.currentSet,
    required this.totalSets,
    required this.onCompleteSet,
  });

  @override
  Widget build(BuildContext context) {
    final counter = workoutSet?.seconds != null
        ? '${workoutSet!.seconds}'
        : '${workoutSet?.reps ?? '?'}';

    return MinimalExerciseSessionLayout(
      media: exercise?.media,
      progressLabel: 'Set $currentSet of $totalSets',
      exerciseName: exercise?.name ?? 'Exercise',
      counterText: counter,
      onTap: () {},
      onAction: onCompleteSet,
      actionTooltip: 'Complete set',
    );
  }
}

// ─────────────────────────────────────────────
// Rest timer view
// ─────────────────────────────────────────────
class _RestView extends StatelessWidget {
  final int secondsLeft;
  final VoidCallback onSkip;
  final String exerciseName;
  final ExerciseMedia? media;
  final double mediaBlurSigma;

  const _RestView({
    required this.secondsLeft,
    required this.onSkip,
    required this.exerciseName,
    this.media,
    this.mediaBlurSigma = 0,
  });

  @override
  Widget build(BuildContext context) {
    return MinimalExerciseSessionLayout(
      media: media,
      progressLabel: '',
      exerciseName: exerciseName,
      counterText: '${secondsLeft}s',
      mediaBlurSigma: mediaBlurSigma,
      isRestScreen: true,
      onAction: onSkip,
      actionTooltip: 'Skip rest',
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
      style: TextStyle(
        color: AppTheme.primary,
        fontWeight: FontWeight.w700,
        fontSize: AppTheme.textBody,
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
        Text(icon, style: TextStyle(fontSize: 21)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: AppTheme.textLabel,
            )),
      ],
    );
  }
}
