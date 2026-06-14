import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../models/exercise_media.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/library_service.dart';
import '../../services/voice_cue_service.dart';
import '../../services/workout_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/progress_calculator.dart';
import '../../utils/share_config.dart';
import '../../widgets/exercise_media_widget.dart';
import '../../utils/back_navigation.dart';
import '../../widgets/minimal_exercise_session_layout.dart';
import '../../widgets/share_workout_sheet.dart';
import '../../widgets/workout_pause_overlay.dart';

const _uuid = Uuid();

enum _WorkoutMode { standard, circuit }

enum _WorkoutStage {
  config,
  warmup,
  exercise,
  restChoice,
  restCountdown,
  getReady,
  circuitExercise,
  circuitRestExercise,
  restExercise,
  complete,
}

class CustomWorkoutStartScreen extends ConsumerStatefulWidget {
  final String workoutId;

  const CustomWorkoutStartScreen({super.key, required this.workoutId});

  @override
  ConsumerState<CustomWorkoutStartScreen> createState() =>
      _CustomWorkoutStartScreenState();
}

class _CustomWorkoutStartScreenState
    extends ConsumerState<CustomWorkoutStartScreen> {
  CustomWorkout? _workout;
  final List<CustomWorkoutPreset> _presets = [];
  List<LibraryExercise> _libraryExercises = [];
  CustomWorkoutPreset? _selectedPreset;
  late Future<void> _loadFuture;

  bool _warmupEnabled = true;
  bool _shuffle = false;
  _WorkoutMode _mode = _WorkoutMode.standard;
  int _restBetweenSets = 60;
  int _restBetweenExercises = 60;
  int _restBetweenRounds = 60;
  int _getReadySeconds = 5;
  int _circuitExerciseSeconds = 30;
  int _rounds = 3;
  bool _isKg = true;

  final List<_RunExercise> _exercises = [];
  List<LibraryExercise> _warmups = [];
  _WorkoutStage _stage = _WorkoutStage.config;
  DateTime? _startedAt;
  Timer? _timer;
  bool _paused = false;
  bool _saving = false;

  int _warmupIndex = 0;
  int _timerLeft = 0;
  int _exerciseIndex = 0;
  int _roundIndex = 1;
  int _completedUnits = 0;
  int _totalUnits = 1;
  int _totalSets = 0;
  WorkoutSession? _completedSession;
  final Map<String, List<Map<String, dynamic>>> _weightLog = {};
  bool _announcedWorkoutStart = false;
  VoidCallback? _afterGetReady;
  String? _baselineSetupSignature;
  String? _startedSetupSignature;
  List<CustomWorkoutPresetExercise> _startedPresetExercises = [];

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadWorkout();
  }

  @override
  void dispose() {
    _timer?.cancel();
    ref.read(voiceCueServiceProvider).stop();
    super.dispose();
  }

  Future<void> _loadWorkout() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final service = ref.read(libraryServiceProvider);
    final results = await Future.wait([
      service.getCustomWorkout(uid, widget.workoutId),
      service.getPresets(uid, widget.workoutId),
      service.getExerciseLibrary(),
    ]);
    final workout = results[0] as CustomWorkout?;
    final presets = results[1] as List<CustomWorkoutPreset>;
    final libraryExercises = results[2] as List<LibraryExercise>;
    if (!mounted) return;
    setState(() {
      _workout = workout;
      _presets
        ..clear()
        ..addAll(presets);
      _libraryExercises = libraryExercises;
      _hydrateExercises(workout);
      _baselineSetupSignature = _setupSignature();
    });
  }

  void _hydrateExercises(CustomWorkout? workout) {
    _exercises
      ..clear()
      ..addAll((workout?.exercises ?? []).map((exercise) {
        final libraryExercise = _findExercise(exercise.exerciseId);
        return _RunExercise(
          source: exercise,
          libraryExercise: libraryExercise,
          sets: exercise.sets,
          reps: exercise.reps ?? 10,
          seconds: exercise.seconds,
          restBetweenSets: _restSeconds(exercise.restSeconds),
          restBetweenExercises: _restSeconds(_restBetweenExercises),
          weightKg: exercise.weightKg,
        );
      }));
  }

  void _applyPreset(CustomWorkoutPreset preset) {
    final workout = _workout;
    if (workout == null) return;
    final baseById = {
      for (final exercise in workout.exercises) exercise.exerciseId: exercise
    };
    final configuredIds = preset.exercises.map((e) => e.exerciseId).toSet();
    final configured = preset.exercises
        .where((presetExercise) => baseById[presetExercise.exerciseId] != null)
        .map((presetExercise) {
      final base = baseById[presetExercise.exerciseId]!;
      return _RunExercise(
        source: base,
        libraryExercise: _findExercise(base.exerciseId),
        sets: presetExercise.sets,
        reps: presetExercise.reps ?? base.reps ?? 10,
        seconds: presetExercise.seconds,
        restBetweenSets: _restSeconds(presetExercise.restBetweenSets),
        restBetweenExercises: _restSeconds(presetExercise.restBetweenExercises),
        weightKg: base.weightKg,
      );
    }).toList();
    final missing = workout.exercises
        .where((exercise) => !configuredIds.contains(exercise.exerciseId))
        .map((exercise) => _RunExercise(
              source: exercise,
              libraryExercise: _findExercise(exercise.exerciseId),
              sets: exercise.sets,
              reps: exercise.reps ?? 10,
              seconds: exercise.seconds,
              restBetweenSets: _restSeconds(exercise.restSeconds),
              restBetweenExercises: _restSeconds(preset.restBetweenExercises),
              weightKg: exercise.weightKg,
            ));

    setState(() {
      _selectedPreset = preset;
      _mode = preset.mode == 'circuit'
          ? _WorkoutMode.circuit
          : _WorkoutMode.standard;
      _warmupEnabled = preset.warmupEnabled;
      _shuffle = preset.shuffleEnabled;
      _rounds = preset.rounds;
      _getReadySeconds = preset.getReadySeconds;
      _restBetweenSets = _restSeconds(preset.restBetweenSets);
      _restBetweenExercises = _restSeconds(preset.restBetweenExercises);
      _restBetweenRounds = _restSeconds(preset.restBetweenRounds);
      final timedPresetExercises =
          preset.exercises.where((exercise) => exercise.seconds != null);
      _circuitExerciseSeconds = timedPresetExercises.isNotEmpty
          ? timedPresetExercises.first.seconds!
          : _circuitExerciseSeconds;
      _exercises
        ..clear()
        ..addAll([...configured, ...missing]);
      _baselineSetupSignature = _setupSignature();
    });
  }

  LibraryExercise? _findExercise(String id) {
    try {
      return _libraryExercises.firstWhere((exercise) => exercise.id == id);
    } catch (_) {
      return null;
    }
  }

  List<LibraryExercise> _buildWarmups() {
    final bodyParts = _workout?.targetBodyParts.toSet() ?? {};
    final warmups = _libraryExercises.where((exercise) {
      final isWarmup = exercise.tags.contains('warm_up') ||
          exercise.category == 'flexibility' ||
          exercise.category == 'cardio';
      final matchesBody = bodyParts.isEmpty ||
          exercise.muscleGroups.any(bodyParts.contains) ||
          exercise.secondaryMuscles.any(bodyParts.contains);
      return isWarmup && matchesBody;
    }).toList();
    warmups.shuffle(Random(DateTime.now().millisecondsSinceEpoch));
    return warmups.take(3).toList();
  }

  int get _estimatedDuration {
    final workSeconds = _exercises.fold<int>(0, (acc, exercise) {
      if (_mode == _WorkoutMode.standard) {
        return acc + (exercise.sets * exercise.reps * 3);
      }
      final unitSeconds = exercise.seconds ?? _circuitExerciseSeconds;
      return acc +
          (_rounds *
              (unitSeconds +
                  _getReadySeconds +
                  exercise.restBetweenExercises)) +
          ((_rounds - 1).clamp(0, 99) * _restBetweenRounds);
    });
    final warmupSeconds = _warmupEnabled ? 180 : 0;
    return ((workSeconds + warmupSeconds) / 60).ceil().clamp(1, 999);
  }

  int get _estimatedCalories => (_estimatedDuration * 5).clamp(0, 9999);

  void _applyRestBetweenSets(int seconds) {
    setState(() {
      _restBetweenSets = _restSeconds(seconds);
      for (final exercise in _exercises) {
        exercise.restBetweenSets = _restSeconds(seconds);
      }
    });
  }

  void _applyRestBetweenExercises(int seconds) {
    setState(() {
      _restBetweenExercises = _restSeconds(seconds);
      for (final exercise in _exercises) {
        exercise.restBetweenExercises = _restSeconds(seconds);
      }
    });
  }

  void _applyMode(_WorkoutMode mode) {
    setState(() {
      _mode = mode;
      if (mode == _WorkoutMode.circuit) {
        for (final exercise in _exercises) {
          exercise.seconds ??= _circuitExerciseSeconds;
        }
      } else {
        for (final exercise in _exercises) {
          exercise.seconds = null;
        }
      }
    });
  }

  void _applyCircuitExerciseSeconds(int seconds) {
    setState(() {
      _circuitExerciseSeconds = seconds;
      for (final exercise in _exercises) {
        exercise.seconds = seconds;
      }
    });
  }

  void _startWorkout() {
    if (_exercises.isEmpty) return;
    _startedSetupSignature = _setupSignature();
    _startedPresetExercises = _toPresetExercises();
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final preset = _selectedPreset;
    if (uid.isNotEmpty && preset != null) {
      ref
          .read(libraryServiceProvider)
          .updatePresetLastUsed(uid, preset.workoutId, preset.id);
    }
    final activeExercises = [..._exercises];
    if (_shuffle) activeExercises.shuffle();
    _exercises
      ..clear()
      ..addAll(activeExercises);
    _warmups = _warmupEnabled ? _buildWarmups() : [];
    _startedAt = DateTime.now();
    _completedUnits = 0;
    _totalSets = 0;
    _announcedWorkoutStart = false;
    _totalUnits = _mode == _WorkoutMode.standard
        ? _exercises.length
        : _exercises.length * _rounds;
    if (_warmups.isNotEmpty) {
      _startWarmup();
    } else if (_mode == _WorkoutMode.standard) {
      _startStandardExercise();
    } else {
      _startCircuitRound();
    }
  }

  String _exerciseTargetText(_RunExercise exercise) {
    if (exercise.seconds != null) {
      return '${exercise.sets} × ${exercise.seconds}s';
    }
    return '${exercise.sets} × ${exercise.reps}';
  }

  void _startStandardExercise() {
    _announceExerciseStart(_currentExercise.source.exerciseName);
    setState(() {
      _paused = false;
      _stage = _WorkoutStage.exercise;
    });
  }

  void _completeStandardExercise() {
    _logWeight(_currentExercise);
    _totalSets += _currentExercise.sets;
    _completedUnits++;

    if (_exerciseIndex >= _exercises.length - 1) {
      _completeWorkout();
      return;
    }

    setState(() => _stage = _WorkoutStage.restChoice);
  }

  void _onRestChoiceSelected(int seconds) {
    if (seconds <= 0) {
      _advanceToNextExercise();
      return;
    }
    setState(() {
      _stage = _WorkoutStage.restCountdown;
      _timerLeft = seconds;
      _paused = false;
    });
    _startTimer(_advanceToNextExercise);
  }

  void _advanceToNextExercise() {
    setState(() {
      _exerciseIndex++;
      _paused = false;
    });
    _startStandardExercise();
  }

  void _handleStandardBack() {
    switch (_stage) {
      case _WorkoutStage.restChoice:
        setState(() => _stage = _WorkoutStage.exercise);
        break;
      case _WorkoutStage.restCountdown:
        _timer?.cancel();
        setState(() => _stage = _WorkoutStage.restChoice);
        break;
      case _WorkoutStage.exercise:
        if (_exerciseIndex > 0) {
          final completedExercise = _exercises[_exerciseIndex - 1];
          setState(() {
            _exerciseIndex--;
            if (_completedUnits > 0) {
              _completedUnits--;
              _totalSets -= completedExercise.sets;
            }
            _stage = _WorkoutStage.exercise;
          });
          _announceExerciseStart(_currentExercise.source.exerciseName);
        } else if (_warmups.isNotEmpty) {
          setState(() {
            _warmupIndex = _warmups.length - 1;
            _stage = _WorkoutStage.warmup;
          });
        } else {
          _leaveWorkoutScreen();
        }
        break;
      case _WorkoutStage.warmup:
        if (_warmupIndex > 0) {
          setState(() => _warmupIndex--);
        } else {
          _leaveWorkoutScreen();
        }
        break;
      default:
        _leaveWorkoutScreen();
    }
  }

  void _startGetReady(String preview, VoidCallback onDone) {
    _afterGetReady = onDone;
    ref.read(voiceCueServiceProvider).announceGetReady(preview);
    setState(() {
      _paused = false;
      _stage = _WorkoutStage.getReady;
      _timerLeft = _getReadySeconds;
    });
    _startTimer(() {
      final callback = _afterGetReady;
      _afterGetReady = null;
      callback?.call();
    });
  }

  void _startWarmup() {
    final warmup = _warmups[_warmupIndex];
    _announceExerciseStart(warmup.name);
    setState(() {
      _paused = false;
      _stage = _WorkoutStage.warmup;
    });
  }

  void _completeWarmup() {
    if (_warmupIndex < _warmups.length - 1) {
      setState(() => _warmupIndex++);
      _startWarmup();
    } else if (_mode == _WorkoutMode.standard) {
      _startStandardExercise();
    } else {
      _startCircuitRound();
    }
  }

  void _startTimer(VoidCallback onDone, {bool countdownToRest = false}) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_paused) return;
      setState(() => _timerLeft--);
      if (countdownToRest && _timerLeft >= 1 && _timerLeft <= 3) {
        ref.read(voiceCueServiceProvider).announceCountdown(_timerLeft);
      }
      if (_timerLeft <= 0) {
        timer.cancel();
        onDone();
      }
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

  void _togglePause() {
    if (_stage == _WorkoutStage.config ||
        _stage == _WorkoutStage.complete ||
        _mode == _WorkoutMode.standard) {
      return;
    }
    if (_paused) {
      _resumeWorkout();
    } else {
      _pauseWorkout();
    }
  }

  _RunExercise get _currentExercise => _exercises[_exerciseIndex];

  int _restSeconds(int seconds) => seconds < 5 ? 5 : seconds;

  void _announceExerciseStart(String exerciseName) {
    final voice = ref.read(voiceCueServiceProvider);
    if (_announcedWorkoutStart) {
      voice.announceBegin();
      return;
    }
    _announcedWorkoutStart = true;
    voice.announceWorkoutStart(exerciseName);
  }

  void _startCircuitRound() {
    setState(() {
      _exerciseIndex = 0;
    });
    _startCircuitExerciseWithGetReady();
  }

  void _startCircuitExerciseWithGetReady() {
    _startGetReady(_currentExercise.source.exerciseName, _beginCircuitExercise);
  }

  void _beginCircuitExercise() {
    final seconds = _currentExercise.seconds ?? _circuitExerciseSeconds;
    setState(() {
      _paused = false;
      _stage = _WorkoutStage.circuitExercise;
      _timerLeft = seconds;
    });
    _announceExerciseStart(_currentExercise.source.exerciseName);
    _startTimer(_completeCircuitExercise, countdownToRest: true);
  }

  void _completeCircuitExercise() {
    if (_stage != _WorkoutStage.circuitExercise) return;
    _timer?.cancel();
    _logWeight(_currentExercise, round: _roundIndex);
    _totalSets++;
    _completedUnits++;
    if (_exerciseIndex < _exercises.length - 1) {
      setState(() {
        _paused = false;
        _stage = _WorkoutStage.circuitRestExercise;
        _timerLeft = _restSeconds(_currentExercise.restBetweenExercises);
      });
      ref.read(voiceCueServiceProvider).announceRest();
      _startTimer(() {
        setState(() => _exerciseIndex++);
        _startCircuitExerciseWithGetReady();
      });
    } else if (_roundIndex < _rounds) {
      setState(() {
        _paused = false;
        _stage = _WorkoutStage.restExercise;
        _timerLeft = _restSeconds(_restBetweenRounds);
      });
      ref.read(voiceCueServiceProvider).announceRest();
      _startTimer(() {
        setState(() => _roundIndex++);
        _startCircuitRound();
      });
    } else {
      _completeWorkout();
    }
  }

  void _skipTimer() {
    _timer?.cancel();
    _paused = false;
    if (_stage == _WorkoutStage.restCountdown) {
      _advanceToNextExercise();
    } else if (_stage == _WorkoutStage.getReady) {
      final callback = _afterGetReady;
      _afterGetReady = null;
      callback?.call();
    } else if (_stage == _WorkoutStage.restExercise) {
      setState(() => _roundIndex++);
      _startCircuitRound();
    } else if (_stage == _WorkoutStage.circuitRestExercise) {
      setState(() => _exerciseIndex++);
      _startCircuitExerciseWithGetReady();
    }
  }

  Set<String> _bodyPartsTrained() {
    final parts = <String>{};
    if (_workout != null) {
      parts.addAll(normalizeBodyParts(_workout!.targetBodyParts));
    }
    final limit = (_exerciseIndex + 1).clamp(0, _exercises.length);
    for (var i = 0; i < limit; i++) {
      parts.addAll(normalizeBodyParts(_exercises[i].source.bodyParts));
    }
    return parts;
  }

  void _logWeight(_RunExercise exercise, {int? set, int? round}) {
    final log = _weightLog.putIfAbsent(exercise.source.exerciseId, () => []);
    log.add({
      'exerciseName': exercise.source.exerciseName,
      'set': set,
      'round': round,
      'weight': exercise.weightKg,
      'unit': _isKg ? 'kg' : 'lbs',
      'completedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _completeWorkout({bool endedEarly = false}) async {
    if (_saving || _completedSession != null) return;
    _timer?.cancel();
    ref.read(voiceCueServiceProvider).stop();
    setState(() => _saving = true);
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final startedAt = _startedAt ?? DateTime.now();
    final end = DateTime.now();
    try {
      final bodyParts = _bodyPartsTrained();
      final session = WorkoutSession(
        id: _uuid.v4(),
        userId: uid,
        planId: _workout?.id ?? widget.workoutId,
        dayId: 'custom',
        dayName: _workout?.name ?? 'Custom Workout',
        startTime: startedAt,
        endTime: end,
        durationMinutes: end.difference(startedAt).inMinutes.clamp(1, 999),
        completedExerciseIds: _exercises
            .take(_exerciseIndex + 1)
            .map((e) => e.source.exerciseId)
            .toList(),
        totalSets: _totalSets,
        totalVolumeKg: volumeFromWeightLog(_weightLog),
        caloriesBurned:
            (end.difference(startedAt).inMinutes * 5).clamp(0, 9999),
        notes: endedEarly ? 'Ended early' : null,
        weightLog: _weightLog,
        workoutMode: _mode.name,
        sourceType: 'custom_workout',
        bodyPartsTrained: bodyParts.toList(),
      );
      await ref.read(workoutServiceProvider).saveSession(session);
      await ref
          .read(libraryServiceProvider)
          .updateLastPerformed(uid, _workout?.id ?? widget.workoutId);
      if (mounted) {
        setState(() {
          _completedSession = session;
          _stage = _WorkoutStage.complete;
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save workout: $e')),
        );
      }
    }
  }

  void _leaveWorkoutScreen() {
    _timer?.cancel();
    ref.read(voiceCueServiceProvider).stop();
    if (!mounted) return;
    AppBackNavigation.navigateBack(
      context,
      fallback: '/workouts/custom/${widget.workoutId}',
    );
  }

  void _exitToWorkouts() {
    _timer?.cancel();
    ref.read(voiceCueServiceProvider).stop();
    if (mounted) context.go('/workouts');
  }

  void _confirmEndWorkout() {
    if (_stage == _WorkoutStage.config) {
      _exitToWorkouts();
      return;
    }

    if (_paused) {
      ref.read(voiceCueServiceProvider).pause();
      setState(() => _paused = false);
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('End workout?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Your progress will be saved.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _completeWorkout(endedEarly: true);
            },
            child: const Text('End Workout',
                style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  void _editExerciseConfig(_RunExercise exercise) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExerciseConfigSheet(
        exercise: exercise,
        onChanged: () => setState(() {}),
      ),
    );
  }

  void _editWeight(_RunExercise exercise) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WeightSheet(
        exercise: exercise,
        isKg: _isKg,
        onUnitChanged: (isKg) => setState(() => _isKg = isKg),
        onChanged: () => setState(() {}),
      ),
    );
  }

  double get _progress =>
      _totalUnits == 0 ? 0 : (_completedUnits / _totalUnits).clamp(0, 1);

  List<CustomWorkoutPresetExercise> _toPresetExercises() =>
      _exercises.asMap().entries.map((entry) {
        final exercise = entry.value;
        return CustomWorkoutPresetExercise(
          exerciseId: exercise.source.exerciseId,
          order: entry.key,
          sets: exercise.sets,
          reps: exercise.seconds == null ? exercise.reps : null,
          seconds: exercise.seconds,
          restBetweenSets: exercise.restBetweenSets,
          restBetweenExercises: exercise.restBetweenExercises,
        );
      }).toList();

  String _setupSignature() {
    final exerciseSignature = _toPresetExercises()
        .map((exercise) =>
            '${exercise.order}:${exercise.exerciseId}:${exercise.sets}:'
            '${exercise.reps}:${exercise.seconds}:${exercise.restBetweenSets}:'
            '${exercise.restBetweenExercises}')
        .join('|');
    return [
      _mode.name,
      _warmupEnabled,
      _shuffle,
      _rounds,
      _restBetweenSets,
      _restBetweenExercises,
      _restBetweenRounds,
      _getReadySeconds,
      exerciseSignature,
    ].join('::');
  }

  bool get _canSaveCompletedSetupAsPreset =>
      _startedSetupSignature != null &&
      _baselineSetupSignature != null &&
      _startedSetupSignature != _baselineSetupSignature;

  Future<void> _saveCompletedSetupAsPreset() async {
    final workout = _workout;
    if (workout == null) return;
    final controller = TextEditingController(
      text: _selectedPreset == null
          ? '${workout.name} Preset'
          : '${_selectedPreset!.name} Copy',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Save as Preset',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Preset name',
            hintText: 'Heavy Strength, Quick Circuit...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    if (uid.isEmpty) return;
    final now = DateTime.now();
    final preset = CustomWorkoutPreset(
      id: ref.read(libraryServiceProvider).generateId(),
      userId: uid,
      workoutId: workout.id,
      name: name,
      mode: _mode.name,
      warmupEnabled: _warmupEnabled,
      shuffleEnabled: _shuffle,
      rounds: _rounds,
      getReadySeconds: _getReadySeconds,
      restBetweenSets: _restBetweenSets,
      restBetweenExercises: _restBetweenExercises,
      restBetweenRounds: _restBetweenRounds,
      estimatedMinutes: _estimatedDuration,
      estimatedCalories: _estimatedCalories,
      exercises: _startedPresetExercises,
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(libraryServiceProvider).savePreset(preset);
    if (!mounted) return;
    setState(() {
      _presets.insert(0, preset);
      _selectedPreset = preset;
      _baselineSetupSignature = _startedSetupSignature;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved "${preset.name}" preset')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(child: Text('Loading workout...')),
          );
        }
        if (_workout == null) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            appBar: AppBar(backgroundColor: AppTheme.background),
            body: const Center(
              child: Text('Workout not found',
                  style: TextStyle(color: AppTheme.textPrimary)),
            ),
          );
        }

        final inSession = _stage != _WorkoutStage.config &&
            _stage != _WorkoutStage.complete;

        return AppBackNavigation.workoutScope(
          isActiveSession: inSession,
          pauseBeforeLeave: _mode == _WorkoutMode.circuit,
          isPaused: _paused,
          onPause: _pauseWorkout,
          onBack: _mode == _WorkoutMode.standard
              ? _handleStandardBack
              : _leaveWorkoutScreen,
          child: Scaffold(
            backgroundColor:
                inSession ? AppTheme.surfaceElevated : AppTheme.background,
            body: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      if (_stage == _WorkoutStage.config)
                        _ConfigTopBar(
                          title: _workout!.name,
                          onClose: _leaveWorkoutScreen,
                        ),
                      if (inSession) WorkoutProgressBar(progress: _progress),
                      Expanded(child: _buildStage()),
                    ],
                  ),
                  if (_paused && _mode == _WorkoutMode.circuit)
                    WorkoutPauseOverlay(
                      onResume: _resumeWorkout,
                      onEnd: _confirmEndWorkout,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case _WorkoutStage.config:
        return _ConfigView(
          workout: _workout!,
          presets: _presets,
          selectedPreset: _selectedPreset,
          exercises: _exercises,
          estimatedDuration: _estimatedDuration,
          estimatedCalories: _estimatedCalories,
          warmupEnabled: _warmupEnabled,
          shuffle: _shuffle,
          mode: _mode,
          rounds: _rounds,
          restBetweenSets: _restBetweenSets,
          restBetweenExercises: _restBetweenExercises,
          restBetweenRounds: _restBetweenRounds,
          getReadySeconds: _getReadySeconds,
          circuitExerciseSeconds: _circuitExerciseSeconds,
          onWarmupChanged: (v) => setState(() => _warmupEnabled = v),
          onShuffleChanged: (v) => setState(() => _shuffle = v),
          onModeChanged: _applyMode,
          onRoundsChanged: (rounds) => setState(() => _rounds = rounds),
          onRestSetsChanged: _applyRestBetweenSets,
          onRestExercisesChanged: _applyRestBetweenExercises,
          onRestRoundsChanged: (seconds) =>
              setState(() => _restBetweenRounds = _restSeconds(seconds)),
          onGetReadyChanged: (seconds) =>
              setState(() => _getReadySeconds = seconds),
          onCircuitDurationChanged: _applyCircuitExerciseSeconds,
          onApplyPreset: _applyPreset,
          onReorder: (oldIndex, newIndex) {
            if (_shuffle) return;
            if (newIndex > oldIndex) newIndex--;
            setState(() {
              final item = _exercises.removeAt(oldIndex);
              _exercises.insert(newIndex, item);
            });
          },
          onEditExercise: _editExerciseConfig,
          onStart: _startWorkout,
        );
      case _WorkoutStage.warmup:
        return _WarmupView(
          warmup: _warmups[_warmupIndex],
          index: _warmupIndex,
          total: _warmups.length,
          onNext: _completeWarmup,
        );
      case _WorkoutStage.exercise:
        return _StandardExerciseView(
          exercise: _currentExercise,
          exerciseIndex: _exerciseIndex,
          totalExercises: _exercises.length,
          targetText: _exerciseTargetText(_currentExercise),
          isKg: _isKg,
          onEditWeight: () => _editWeight(_currentExercise),
          onNext: _completeStandardExercise,
        );
      case _WorkoutStage.restChoice:
        return _RestChoiceView(
          onSelect: _onRestChoiceSelected,
        );
      case _WorkoutStage.restCountdown:
        final nextExercise = _exercises[_exerciseIndex + 1];
        return _StandardRestCountdownView(
          secondsLeft: _timerLeft,
          upcomingExerciseName: nextExercise.source.exerciseName,
          upcomingMedia: resolveExerciseMedia(
            exerciseId: nextExercise.source.exerciseId,
            libraryMedia: nextExercise.libraryExercise?.media,
            savedThumbnailUrl: nextExercise.source.thumbnailUrl,
          ),
          onSkip: _skipTimer,
        );
      case _WorkoutStage.getReady:
        return _RestView(
          progressLabel: 'Get Ready',
          exerciseName: _currentExercise.source.exerciseName,
          secondsLeft: _timerLeft,
          media: resolveExerciseMedia(
            exerciseId: _currentExercise.source.exerciseId,
            libraryMedia: _currentExercise.libraryExercise?.media,
            savedThumbnailUrl: _currentExercise.source.thumbnailUrl,
          ),
          onSkip: _skipTimer,
          onTogglePause: _togglePause,
          showPauseHint: true,
        );
      case _WorkoutStage.restExercise:
        return _RestView(
          progressLabel: 'Rest Between Rounds',
          exerciseName: 'Round ${_roundIndex + 1}',
          secondsLeft: _timerLeft,
          onSkip: _skipTimer,
          onTogglePause: _togglePause,
          showPauseHint: true,
        );
      case _WorkoutStage.circuitExercise:
        return _ActiveExerciseView(
          exercise: _currentExercise,
          label: 'Round $_roundIndex of $_rounds',
          isKg: _isKg,
          progressText: '${_timerLeft}s',
          onEditWeight: () => _editWeight(_currentExercise),
          onDone: _completeCircuitExercise,
          onTogglePause: _togglePause,
          showPauseHint: true,
        );
      case _WorkoutStage.circuitRestExercise:
        final next = _exerciseIndex + 1 < _exercises.length
            ? _exercises[_exerciseIndex + 1]
            : null;
        return _RestView(
          progressLabel: 'Rest Between Exercises',
          exerciseName:
              next?.source.exerciseName ?? _currentExercise.source.exerciseName,
          secondsLeft: _timerLeft,
          media: next == null
              ? null
              : resolveExerciseMedia(
                  exerciseId: next.source.exerciseId,
                  libraryMedia: next.libraryExercise?.media,
                  savedThumbnailUrl: next.source.thumbnailUrl,
                ),
          onSkip: _skipTimer,
          onTogglePause: _togglePause,
          showPauseHint: true,
        );
      case _WorkoutStage.complete:
        return _CompleteView(
          session: _completedSession!,
          weightLog: _weightLog,
          canSavePreset: _canSaveCompletedSetupAsPreset,
          onSavePreset: _saveCompletedSetupAsPreset,
          onDone: () => context.go('/workouts'),
          onShareWorkout: _workout == null
              ? null
              : () async {
                  final uid =
                      ref.read(authStateProvider).valueOrNull?.uid ?? '';
                  final profile = await ref
                      .read(authServiceProvider)
                      .loadUserProfile(uid);
                  if (profile != null && context.mounted) {
                    await ShareWorkoutSheet.show(
                      context,
                      ref,
                      workout: _workout!,
                      creator: profile,
                    );
                  }
                },
        );
    }
  }
}

class _RunExercise {
  final CustomWorkoutExercise source;
  final LibraryExercise? libraryExercise;
  int sets;
  int reps;
  int? seconds;
  int restBetweenSets;
  int restBetweenExercises;
  double? weightKg;

  _RunExercise({
    required this.source,
    required this.libraryExercise,
    required this.sets,
    required this.reps,
    required this.seconds,
    required this.restBetweenSets,
    required this.restBetweenExercises,
    required this.weightKg,
  });
}

class _ConfigView extends StatelessWidget {
  final CustomWorkout workout;
  final List<CustomWorkoutPreset> presets;
  final CustomWorkoutPreset? selectedPreset;
  final List<_RunExercise> exercises;
  final int estimatedDuration;
  final int estimatedCalories;
  final bool warmupEnabled;
  final bool shuffle;
  final _WorkoutMode mode;
  final int rounds;
  final int restBetweenSets;
  final int restBetweenExercises;
  final int restBetweenRounds;
  final int getReadySeconds;
  final int circuitExerciseSeconds;
  final ValueChanged<bool> onWarmupChanged;
  final ValueChanged<bool> onShuffleChanged;
  final ValueChanged<_WorkoutMode> onModeChanged;
  final ValueChanged<int> onRoundsChanged;
  final ValueChanged<int> onRestSetsChanged;
  final ValueChanged<int> onRestExercisesChanged;
  final ValueChanged<int> onRestRoundsChanged;
  final ValueChanged<int> onGetReadyChanged;
  final ValueChanged<int> onCircuitDurationChanged;
  final ValueChanged<CustomWorkoutPreset> onApplyPreset;
  final ReorderCallback onReorder;
  final ValueChanged<_RunExercise> onEditExercise;
  final VoidCallback onStart;

  const _ConfigView({
    required this.workout,
    required this.presets,
    required this.selectedPreset,
    required this.exercises,
    required this.estimatedDuration,
    required this.estimatedCalories,
    required this.warmupEnabled,
    required this.shuffle,
    required this.mode,
    required this.rounds,
    required this.restBetweenSets,
    required this.restBetweenExercises,
    required this.restBetweenRounds,
    required this.getReadySeconds,
    required this.circuitExerciseSeconds,
    required this.onWarmupChanged,
    required this.onShuffleChanged,
    required this.onModeChanged,
    required this.onRoundsChanged,
    required this.onRestSetsChanged,
    required this.onRestExercisesChanged,
    required this.onRestRoundsChanged,
    required this.onGetReadyChanged,
    required this.onCircuitDurationChanged,
    required this.onApplyPreset,
    required this.onReorder,
    required this.onEditExercise,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(workout.name,
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                        label: 'Duration', value: '~$estimatedDuration min'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                        label: 'Calories', value: '~$estimatedCalories kcal'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (presets.isNotEmpty) ...[
                _ConfigCard(
                  title: 'Saved Presets',
                  children: presets
                      .map((preset) => _PresetTile(
                            preset: preset,
                            selected: selectedPreset?.id == preset.id,
                            onTap: () => onApplyPreset(preset),
                          ))
                      .toList(),
                ),
              ],
              _ConfigCard(
                title: 'Workout Mode',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ModeButton(
                          label: 'Standard',
                          selected: mode == _WorkoutMode.standard,
                          onTap: () => onModeChanged(_WorkoutMode.standard),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ModeButton(
                          label: 'Circuit',
                          selected: mode == _WorkoutMode.circuit,
                          onTap: () => onModeChanged(_WorkoutMode.circuit),
                        ),
                      ),
                    ],
                  ),
                  if (mode == _WorkoutMode.circuit) ...[
                    const SizedBox(height: 14),
                    _StepperConfig(
                      label: 'Rounds',
                      value: rounds,
                      min: 1,
                      max: 6,
                      onChanged: onRoundsChanged,
                    ),
                    const SizedBox(height: 12),
                    Text('Per Exercise Duration',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    _SecondsPicker(
                      value: circuitExerciseSeconds,
                      options: const [20, 30, 40, 45, 60],
                      onChanged: onCircuitDurationChanged,
                    ),
                  ],
                ],
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: warmupEnabled,
                      onChanged: onWarmupChanged,
                      title: const Text('Warmup'),
                    ),
                    SwitchListTile(
                      value: shuffle,
                      onChanged: onShuffleChanged,
                      title: const Text('Shuffle exercise order'),
                    ),
                  ],
                ),
              ),
              if (mode == _WorkoutMode.circuit)
                _ConfigCard(
                  title: 'Rest Timers',
                  children: [
                    Text('Get Ready Timer',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    _SecondsPicker(
                      value: getReadySeconds,
                      options: const [3, 5, 10, 15],
                      onChanged: onGetReadyChanged,
                    ),
                    const SizedBox(height: 14),
                    Text('Rest Between Exercises',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    _RestPicker(
                      value: restBetweenExercises,
                      onChanged: onRestExercisesChanged,
                    ),
                    const SizedBox(height: 14),
                    Text('Rest Between Rounds',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    _RestPicker(
                      value: restBetweenRounds,
                      onChanged: onRestRoundsChanged,
                    ),
                  ],
                ),
              _ConfigCard(
                title: 'Exercise List',
                children: [
                  if (shuffle)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Reorder is disabled while shuffle is on.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  SizedBox(
                    height: max(120, exercises.length * 86),
                    child: ReorderableListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: exercises.length,
                      onReorder: onReorder,
                      itemBuilder: (context, index) => _ConfigExerciseTile(
                        key: ValueKey(
                            '${exercises[index].source.exerciseId}-$index'),
                        exercise: exercises[index],
                        index: index,
                        dragEnabled: !shuffle,
                        isCircuit: mode == _WorkoutMode.circuit,
                        onTap: () => onEditExercise(exercises[index]),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ElevatedButton(
            onPressed: onStart,
            child: const Text('Start Workout'),
          ),
        ),
      ],
    );
  }
}

class _ConfigTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _ConfigTopBar({
    required this.title,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
          ),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarmupView extends StatelessWidget {
  final LibraryExercise warmup;
  final int index;
  final int total;
  final VoidCallback onNext;

  const _WarmupView({
    required this.warmup,
    required this.index,
    required this.total,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return MinimalExerciseSessionLayout(
      media: warmup.media,
      progressLabel: 'Warmup ${index + 1} of $total',
      exerciseName: warmup.name,
      counterText: 'Ready',
      onAction: onNext,
      actionIcon: Icons.skip_next_rounded,
      actionTooltip: 'Next',
    );
  }
}

class _StandardExerciseView extends StatelessWidget {
  final _RunExercise exercise;
  final int exerciseIndex;
  final int totalExercises;
  final String targetText;
  final bool isKg;
  final VoidCallback onEditWeight;
  final VoidCallback onNext;

  const _StandardExerciseView({
    required this.exercise,
    required this.exerciseIndex,
    required this.totalExercises,
    required this.targetText,
    required this.isKg,
    required this.onEditWeight,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return MinimalExerciseSessionLayout(
      media: resolveExerciseMedia(
        exerciseId: exercise.source.exerciseId,
        libraryMedia: exercise.libraryExercise?.media,
        savedThumbnailUrl: exercise.source.thumbnailUrl,
      ),
      progressLabel: 'Exercise ${exerciseIndex + 1} of $totalExercises',
      exerciseName: exercise.source.exerciseName,
      counterText: targetText,
      onAction: onNext,
      actionIcon: Icons.skip_next_rounded,
      actionTooltip: 'Next exercise',
      footer: GestureDetector(
        onTap: onEditWeight,
        child: Text(
          exercise.weightKg == null
              ? 'Tap to log weight'
              : 'Weight: ${exercise.weightKg!.toStringAsFixed(1)} ${isKg ? 'kg' : 'lbs'}',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: AppTheme.textLabel,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _RestChoiceView extends StatelessWidget {
  final ValueChanged<int> onSelect;

  const _RestChoiceView({
    required this.onSelect,
  });

  static const _options = [
    (0, 'Start now'),
    (15, 'Start in 15s'),
    (30, 'Start in 30s'),
    (60, 'Start in 60s'),
    (120, 'Start in 120s'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose rest time',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          ..._options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ElevatedButton(
                onPressed: () => onSelect(option.$1),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor:
                      option.$1 == 0 ? AppTheme.accent : AppTheme.cardBg,
                  foregroundColor:
                      option.$1 == 0 ? Colors.white : AppTheme.textPrimary,
                  side: option.$1 == 0
                      ? null
                      : const BorderSide(color: AppTheme.border),
                ),
                child: Text(option.$2),
              ),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _StandardRestCountdownView extends StatelessWidget {
  final int secondsLeft;
  final String upcomingExerciseName;
  final ExerciseMedia? upcomingMedia;
  final VoidCallback onSkip;

  const _StandardRestCountdownView({
    required this.secondsLeft,
    required this.upcomingExerciseName,
    required this.upcomingMedia,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
          child: Column(
            children: [
              const Spacer(),
              Text(
                'Rest',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                '$secondsLeft',
                style: AppTypography.statHero(),
              ),
              const Spacer(flex: 2),
              Text(
                'Upcoming Exercise',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: AppTheme.textLabel,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ExerciseImage(
                    media: upcomingMedia,
                    height: 56,
                    width: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      upcomingExerciseName,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: AppTheme.textBody,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: 28,
          child: FloatingActionButton(
            onPressed: onSkip,
            tooltip: 'Skip',
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            highlightElevation: 0,
            shape: const CircleBorder(),
            child: const Icon(Icons.skip_next_rounded),
          ),
        ),
      ],
    );
  }
}

class _ActiveExerciseView extends StatelessWidget {
  final _RunExercise exercise;
  final String label;
  final String progressText;
  final bool isKg;
  final VoidCallback onEditWeight;
  final VoidCallback onDone;
  final VoidCallback onTogglePause;
  final bool showPauseHint;

  const _ActiveExerciseView({
    required this.exercise,
    required this.label,
    required this.progressText,
    required this.isKg,
    required this.onEditWeight,
    required this.onDone,
    required this.onTogglePause,
    this.showPauseHint = false,
  });

  @override
  Widget build(BuildContext context) {
    return MinimalExerciseSessionLayout(
      media: resolveExerciseMedia(
        exerciseId: exercise.source.exerciseId,
        libraryMedia: exercise.libraryExercise?.media,
        savedThumbnailUrl: exercise.source.thumbnailUrl,
      ),
      progressLabel: label,
      exerciseName: exercise.source.exerciseName,
      counterText: progressText,
      onTap: showPauseHint ? onTogglePause : null,
      onAction: onDone,
      actionTooltip: 'Complete',
      showPauseHint: showPauseHint,
      footer: GestureDetector(
        onTap: onEditWeight,
        child: Text(
          exercise.weightKg == null
              ? 'Tap to log weight'
              : 'Weight: ${exercise.weightKg!.toStringAsFixed(1)} ${isKg ? 'kg' : 'lbs'}',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: AppTheme.textLabel,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _RestView extends StatelessWidget {
  final String progressLabel;
  final String exerciseName;
  final int secondsLeft;
  final ExerciseMedia? media;
  final VoidCallback onSkip;
  final VoidCallback? onTogglePause;
  final bool showPauseHint;

  const _RestView({
    required this.progressLabel,
    required this.exerciseName,
    required this.secondsLeft,
    this.media,
    required this.onSkip,
    this.onTogglePause,
    this.showPauseHint = false,
  });

  @override
  Widget build(BuildContext context) {
    return MinimalExerciseSessionLayout(
      media: media,
      progressLabel: progressLabel,
      exerciseName: exerciseName,
      counterText: '$secondsLeft',
      onTap: showPauseHint ? onTogglePause : null,
      onAction: onSkip,
      actionTooltip: 'Skip',
      showPauseHint: showPauseHint,
    );
  }
}

class _CompleteView extends StatefulWidget {
  final WorkoutSession session;
  final Map<String, List<Map<String, dynamic>>> weightLog;
  final bool canSavePreset;
  final Future<void> Function() onSavePreset;
  final VoidCallback onDone;
  final Future<void> Function()? onShareWorkout;

  const _CompleteView({
    required this.session,
    required this.weightLog,
    required this.canSavePreset,
    required this.onSavePreset,
    required this.onDone,
    this.onShareWorkout,
  });

  @override
  State<_CompleteView> createState() => _CompleteViewState();
}

class _CompleteViewState extends State<_CompleteView> {
  bool _saveWeightLog = true;
  bool _savingPreset = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
      children: [
        Text(
          'Workout Complete',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: AppTheme.primary,
              ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                  label: 'Duration',
                  value: '${widget.session.durationMinutes} min'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                  label: 'Calories', value: '${widget.session.caloriesBurned}'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _MetricCard(
          label: 'Exercises',
          value: '${widget.session.completedExerciseIds.length}',
        ),
        const SizedBox(height: 22),
        SwitchListTile(
          value: _saveWeightLog,
          onChanged: (v) => setState(() => _saveWeightLog = v),
          title: const Text('Save weight log for progress tracking'),
        ),
        if (widget.canSavePreset) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You changed this workout setup',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Save the mode, order, sets, reps, and rest timers as a reusable preset.',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.35),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _savingPreset
                      ? null
                      : () async {
                          setState(() => _savingPreset = true);
                          await widget.onSavePreset();
                          if (mounted) setState(() => _savingPreset = false);
                        },
                  child: Text(_savingPreset ? 'Saving...' : 'Save as Preset'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('Weight Log', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        if (widget.weightLog.isEmpty)
          Text('No weights logged.',
              style: TextStyle(color: AppTheme.textSecondary))
        else
          ...widget.weightLog.values.expand((entries) {
            return entries.map((entry) => _WeightLogTile(entry: entry));
          }),
        const SizedBox(height: 24),
        if (widget.onShareWorkout != null) ...[
          ElevatedButton.icon(
            onPressed: widget.onShareWorkout,
            icon: const Icon(Icons.fitness_center_rounded),
            label: const Text('Share Workout'),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _shareResults,
          icon: const Icon(Icons.share_outlined),
          label: const Text('Share Results'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: widget.onDone, child: const Text('Done')),
      ],
    );
  }

  Future<void> _shareResults() async {
    final buffer = StringBuffer()
      ..writeln(
          'I just completed ${widget.session.dayName} in ${ShareConfig.appName}.')
      ..writeln('Duration: ${widget.session.durationMinutes} min')
      ..writeln('Calories: ${widget.session.caloriesBurned}')
      ..writeln('Exercises: ${widget.session.completedExerciseIds.length}');
    if (widget.weightLog.isNotEmpty) {
      buffer.writeln('\nWeight log:');
      for (final entries in widget.weightLog.values) {
        for (final entry in entries) {
          final setLabel = entry['set'] != null
              ? 'Set ${entry['set']}'
              : 'Round ${entry['round']}';
          final weight = entry['weight'] == null
              ? 'Not set'
              : '${(entry['weight'] as num).toStringAsFixed(1)} ${entry['unit']}';
          buffer.writeln('${entry['exerciseName']} - $setLabel - $weight');
        }
      }
    }
    await SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: AppTheme.textLabel,
              )),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.stat()),
        ],
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ConfigCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: selected ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppTheme.background : AppTheme.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StepperConfig extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _StepperConfig({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              )),
        ),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 42,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.primary,
                ),
          ),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _RestPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _RestPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = [30, 45, 60, 90, 120];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final selected = option == value;
        return ChoiceChip(
          label: Text('${option}s'),
          selected: selected,
          onSelected: (_) => onChanged(option),
        );
      }).toList(),
    );
  }
}

class _SecondsPicker extends StatelessWidget {
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  const _SecondsPicker({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        return ChoiceChip(
          label: Text('${option}s'),
          selected: option == value,
          onSelected: (_) => onChanged(option),
        );
      }).toList(),
    );
  }
}

class _ConfigExerciseTile extends StatelessWidget {
  final _RunExercise exercise;
  final int index;
  final bool dragEnabled;
  final bool isCircuit;
  final VoidCallback onTap;

  const _ConfigExerciseTile({
    super.key,
    required this.exercise,
    required this.index,
    required this.dragEnabled,
    required this.isCircuit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            if (dragEnabled)
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle, color: AppTheme.textMuted),
              )
            else
              const Icon(Icons.shuffle, color: AppTheme.textMuted),
            const SizedBox(width: 10),
            _ExerciseImage(
              media: resolveExerciseMedia(
                exerciseId: exercise.source.exerciseId,
                libraryMedia: exercise.libraryExercise?.media,
                savedThumbnailUrl: exercise.source.thumbnailUrl,
              ),
              height: 52,
              width: 52,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.source.exerciseName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCircuit
                        ? '${exercise.seconds ?? 30}s work · ${exercise.restBetweenExercises}s rest'
                        : '${exercise.sets} sets · ${exercise.reps} reps',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: AppTheme.textLabel,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined,
                color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
    return tile;
  }
}

class _PresetTile extends StatelessWidget {
  final CustomWorkoutPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withOpacity(0.16)
              : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.tune_rounded,
              color: selected ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.name,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_label(preset.mode)} · ${preset.exercises.length} exercises · ~${preset.estimatedMinutes} min',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: AppTheme.textLabel,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ExerciseImage extends StatelessWidget {
  final ExerciseMedia? media;
  final double height;
  final double? width;

  const _ExerciseImage({
    required this.media,
    required this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final boxWidth = width ?? double.infinity;
    final placeholder = Container(
      height: height,
      width: boxWidth,
      color: AppTheme.surfaceElevated,
      child: const Center(
        child: Icon(Icons.fitness_center_rounded,
            color: AppTheme.textMuted, size: 42),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        width: boxWidth,
        child: ExerciseMediaWidget(
          media: media,
          fit: BoxFit.cover,
          autoplayVideo: false,
          loopVideo: false,
          placeholder: placeholder,
        ),
      ),
    );
  }
}

class _ExerciseConfigSheet extends StatefulWidget {
  final _RunExercise exercise;
  final VoidCallback onChanged;

  const _ExerciseConfigSheet({
    required this.exercise,
    required this.onChanged,
  });

  @override
  State<_ExerciseConfigSheet> createState() => _ExerciseConfigSheetState();
}

class _ExerciseConfigSheetState extends State<_ExerciseConfigSheet> {
  late int sets;
  late int reps;
  late int seconds;
  late int restSets;
  late int restExercises;
  late bool isCircuit;

  @override
  void initState() {
    super.initState();
    sets = widget.exercise.sets;
    reps = widget.exercise.reps;
    seconds = widget.exercise.seconds ?? 30;
    restSets = widget.exercise.restBetweenSets < 5
        ? 5
        : widget.exercise.restBetweenSets;
    restExercises = widget.exercise.restBetweenExercises < 5
        ? 5
        : widget.exercise.restBetweenExercises;
    isCircuit = widget.exercise.seconds != null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.exercise.source.exerciseName,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          if (isCircuit) ...[
            Text('Exercise Duration',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _SecondsPicker(
              value: seconds,
              options: const [20, 30, 40, 45, 60],
              onChanged: (v) => setState(() => seconds = v),
            ),
            const SizedBox(height: 14),
          ] else ...[
            _StepperConfig(
              label: 'Sets',
              value: sets,
              min: 1,
              max: 10,
              onChanged: (v) => setState(() => sets = v),
            ),
            _StepperConfig(
              label: 'Reps',
              value: reps,
              min: 1,
              max: 100,
              onChanged: (v) => setState(() => reps = v),
            ),
          ],
          if (isCircuit)
            _StepperConfig(
              label: 'Rest between exercises',
              value: restExercises,
              min: 5,
              max: 180,
              onChanged: (v) => setState(() => restExercises = v),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              widget.exercise
                ..sets = sets
                ..reps = reps
                ..seconds = isCircuit ? seconds : null
                ..restBetweenSets = restSets
                ..restBetweenExercises = restExercises;
              widget.onChanged();
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _WeightSheet extends StatefulWidget {
  final _RunExercise exercise;
  final bool isKg;
  final ValueChanged<bool> onUnitChanged;
  final VoidCallback onChanged;

  const _WeightSheet({
    required this.exercise,
    required this.isKg,
    required this.onUnitChanged,
    required this.onChanged,
  });

  @override
  State<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<_WeightSheet> {
  late bool isKg;
  late double weight;

  @override
  void initState() {
    super.initState();
    isKg = widget.isKg;
    weight = widget.exercise.weightKg ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weight', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),
          Row(
            children: [
              _ModeButton(
                label: 'kg',
                selected: isKg,
                onTap: () => setState(() => isKg = true),
              ),
              const SizedBox(width: 10),
              _ModeButton(
                label: 'lbs',
                selected: !isKg,
                onTap: () => setState(() => isKg = false),
              ),
            ],
          ),
          Slider(
            value: weight.clamp(0, 250),
            min: 0,
            max: 250,
            divisions: 500,
            activeColor: AppTheme.primary,
            onChanged: (v) => setState(() => weight = v),
          ),
          Center(
            child: Text(
              '${weight.toStringAsFixed(1)} ${isKg ? 'kg' : 'lbs'}',
              style: AppTypography.stat(color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              widget.exercise.weightKg = weight;
              widget.onUnitChanged(isKg);
              widget.onChanged();
              Navigator.pop(context);
            },
            child: const Text('Save Weight'),
          ),
        ],
      ),
    );
  }
}

class _WeightLogTile extends StatelessWidget {
  final Map<String, dynamic> entry;

  const _WeightLogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final setLabel = entry['set'] != null
        ? 'Set ${entry['set']}'
        : 'Round ${entry['round']}';
    final weight = entry['weight'] == null
        ? 'Not set'
        : '${(entry['weight'] as num).toStringAsFixed(1)} ${entry['unit']}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${entry['exerciseName']} · $setLabel',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(weight, style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

String _label(String value) => value
    .split('_')
    .map((part) =>
        part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
