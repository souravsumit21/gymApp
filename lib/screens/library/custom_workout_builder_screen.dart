// lib/screens/library/custom_workout_builder_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/exercise_media.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/library_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/equipment_filter.dart';
import '../../utils/muscle_filter.dart';
import '../../widgets/exercise_media_widget.dart';

const _uuid = Uuid();

const _bodyPartOptions = [
  ('chest', 'Chest'),
  ('back', 'Back'),
  ('shoulders', 'Shoulders'),
  ('biceps', 'Biceps'),
  ('triceps', 'Triceps'),
  ('quads', 'Quads'),
  ('hamstrings', 'Hamstrings'),
  ('glutes', 'Glutes'),
  ('core', 'Core'),
  ('forearms', 'Forearms'),
];

class CustomWorkoutBuilderScreen extends ConsumerStatefulWidget {
  final String? existingWorkoutId;

  const CustomWorkoutBuilderScreen({super.key, this.existingWorkoutId});

  @override
  ConsumerState<CustomWorkoutBuilderScreen> createState() =>
      _CustomWorkoutBuilderScreenState();
}

class _CustomWorkoutBuilderScreenState
    extends ConsumerState<CustomWorkoutBuilderScreen> {
  final _nameController = TextEditingController();
  final _pageController = PageController();
  final _selectedEquipment = <String>{};
  final _selectedBodyParts = <String>{};
  int _currentStep = 0;
  bool _isSaving = false;
  bool _isLoadingExisting = false;
  String? _error;
  CustomWorkout? _existingWorkout;

  @override
  void initState() {
    super.initState();
    Future(() {
      if (!mounted) return;
      if (widget.existingWorkoutId != null) {
        _loadExistingWorkout();
      } else {
        ref.read(workoutBuilderProvider.notifier).clear();
      }
    });
  }

  Future<void> _loadExistingWorkout() async {
    setState(() => _isLoadingExisting = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
      final workout = await ref
          .read(libraryServiceProvider)
          .getCustomWorkout(uid, widget.existingWorkoutId!);
      if (!mounted || workout == null) {
        setState(() => _error = 'Workout not found.');
        return;
      }
      _existingWorkout = workout;
      _nameController.text = workout.name;
      setState(() {
        _selectedEquipment
          ..clear()
          ..addAll(workout.selectedEquipment);
        _selectedBodyParts
          ..clear()
          ..addAll(workout.targetBodyParts.isNotEmpty
              ? workout.targetBodyParts
              : workout.targetMuscles);
      });
      ref.read(workoutBuilderProvider.notifier).loadExercises(workout.exercises);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error loading workout: $e');
    } finally {
      if (mounted) setState(() => _isLoadingExisting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
      _error = null;
    });
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handleBackNavigation() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/workouts');
    }
  }

  void _next() {
    if (!_validateStep()) return;
    if (_currentStep == 3) {
      _saveWorkout();
      return;
    }
    _goToStep(_currentStep + 1);
  }

  bool _validateStep() {
    final exercises = ref.read(workoutBuilderProvider);
    String? message;
    if (_currentStep == 0 && _selectedEquipment.isEmpty) {
      message = 'Choose at least one equipment type.';
    } else if (_currentStep == 1 && _selectedBodyParts.isEmpty) {
      message = 'Choose at least one body part.';
    } else if (_currentStep == 2 && exercises.isEmpty) {
      message = 'Add at least one exercise.';
    } else if (_currentStep == 3 && _nameController.text.trim().isEmpty) {
      message = 'Workout name is required.';
    }

    if (message == null) return true;
    setState(() => _error = message);
    return false;
  }

  List<LibraryExercise> _filteredExercises(List<LibraryExercise> library) {
    return library.where((exercise) {
      final matchesBodyPart = _selectedBodyParts.any(
        (part) => exerciseMatchesBodyPart(
          exercise.muscleGroups,
          exercise.secondaryMuscles,
          part,
        ),
      );
      final matchesEquipment = exerciseMatchesSelectedEquipment(
        exercise.requiredEquipment,
        _selectedEquipment,
      );
      return matchesBodyPart && matchesEquipment;
    }).toList();
  }

  Map<String, List<LibraryExercise>> _groupedExercises(
    List<LibraryExercise> library,
  ) {
    final grouped = <String, List<LibraryExercise>>{};
    final filtered = _filteredExercises(library);
    for (final bodyPart in _selectedBodyParts) {
      grouped[bodyPart] = filtered
          .where(
            (exercise) => exerciseMatchesBodyPart(
              exercise.muscleGroups,
              exercise.secondaryMuscles,
              bodyPart,
            ),
          )
          .toList();
    }
    grouped.removeWhere((_, exercises) => exercises.isEmpty);
    return grouped;
  }

  int _estimatedMinutes(List<CustomWorkoutExercise> exercises) {
    return exercises.fold<int>(0, (acc, e) {
      final workSeconds = e.seconds ?? ((e.reps ?? 10) * 3);
      return acc + (e.sets * (workSeconds + e.restSeconds)) ~/ 60;
    }).clamp(5, 999);
  }

  Future<void> _saveWorkout() async {
    final exercises = ref.read(workoutBuilderProvider);
    if (!_validateStep()) return;

    setState(() => _isSaving = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null || uid.isEmpty) {
        setState(() => _error = 'You must be signed in to save workouts.');
        return;
      }
      final svc = ref.read(libraryServiceProvider);
      final now = DateTime.now();
      final workout = CustomWorkout(
        id: widget.existingWorkoutId ?? _uuid.v4(),
        userId: uid,
        name: _nameController.text.trim(),
        exercises: exercises,
        targetMuscles: _selectedBodyParts.toList(),
        selectedEquipment: _selectedEquipment.toList(),
        targetBodyParts: _selectedBodyParts.toList(),
        estimatedMinutes: _estimatedMinutes(exercises),
        createdAt: _existingWorkout?.createdAt ?? now,
        updatedAt: now,
        lastPerformed: _existingWorkout?.lastPerformed,
        importedFromShare: _existingWorkout?.importedFromShare ?? false,
        importedFromCommunity:
            _existingWorkout?.importedFromCommunity ?? false,
        sourceShareId: _existingWorkout?.sourceShareId,
        sourceCommunityWorkoutId: _existingWorkout?.sourceCommunityWorkoutId,
      );

      await svc.saveCustomWorkout(workout);
      ref.read(workoutBuilderProvider.notifier).clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingWorkoutId != null
                  ? 'Workout updated'
                  : 'Workout saved',
            ),
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/workouts/custom/${workout.id}');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error saving workout: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showExerciseDetails(LibraryExercise exercise) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExerciseDetailSheet(exercise: exercise),
    );
  }

  void _showEditSheet(int index, CustomWorkoutExercise exercise) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExerciseEditSheet(
        exercise: exercise,
        onSave: (updated) {
          ref.read(workoutBuilderProvider.notifier).updateExercise(index, updated);
        },
      ),
    );
  }

  void _retryLibraryLoad() {
    ref.read(exerciseLibraryProvider.notifier).retry();
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(workoutBuilderProvider);
    final libraryAsync = ref.watch(exerciseLibraryProvider);
    final libraryStatus = ref.watch(exerciseLibraryStatusProvider);
    final library = libraryAsync.valueOrNull ?? const <LibraryExercise>[];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/workouts');
            }
          },
          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
        ),
        title: Text(
          widget.existingWorkoutId != null ? 'Edit Workout' : 'Custom Workout',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: _isLoadingExisting
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : Column(
        children: [
          _StepHeader(
            currentStep: _currentStep,
            onStepTap: (step) {
              if (step <= _currentStep) _goToStep(step);
            },
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _EquipmentStep(
                  isLoading: libraryStatus.isLoading,
                  loadError: libraryAsync.hasError
                      ? (libraryStatus.errorMessage ??
                          'Could not load exercises.')
                      : null,
                  fetchWarning: !libraryStatus.isLoading &&
                          !libraryAsync.hasError &&
                          libraryStatus.errorMessage != null
                      ? libraryStatus.errorMessage
                      : null,
                  onRetry: _retryLibraryLoad,
                  selected: _selectedEquipment,
                  exerciseCounts: equipmentExerciseCounts(
                    library,
                    allEquipment.map((e) => e.id),
                  ),
                  onToggle: (id) {
                    setState(() {
                      _selectedEquipment.contains(id)
                          ? _selectedEquipment.remove(id)
                          : _selectedEquipment.add(id);
                      _error = null;
                    });
                  },
                ),
                _BodyPartsStep(
                  isLoading: libraryStatus.isLoading,
                  loadError: libraryAsync.hasError
                      ? (libraryStatus.errorMessage ??
                          'Could not load exercises.')
                      : null,
                  fetchWarning: !libraryStatus.isLoading &&
                          !libraryAsync.hasError &&
                          libraryStatus.errorMessage != null
                      ? libraryStatus.errorMessage
                      : null,
                  onRetry: _retryLibraryLoad,
                  selected: _selectedBodyParts,
                  exerciseCounts: bodyPartExerciseCounts(
                    library,
                    _bodyPartOptions.map((e) => e.$1),
                    selectedEquipment: _selectedEquipment,
                  ),
                  onToggle: (id) {
                    setState(() {
                      _selectedBodyParts.contains(id)
                          ? _selectedBodyParts.remove(id)
                          : _selectedBodyParts.add(id);
                      _error = null;
                    });
                  },
                ),
                _ExerciseLibraryStep(
                  isLoading: libraryStatus.isLoading,
                  loadError: libraryAsync.hasError
                      ? (libraryStatus.errorMessage ??
                          'Could not load exercises.')
                      : null,
                  fetchWarning: !libraryStatus.isLoading &&
                          !libraryAsync.hasError &&
                          libraryStatus.errorMessage != null
                      ? libraryStatus.errorMessage
                      : null,
                  onRetry: _retryLibraryLoad,
                  groupedExercises: _groupedExercises(library),
                  selectedExerciseIds:
                      exercises.map((e) => e.exerciseId).toSet(),
                  onToggle: (exercise) => ref
                      .read(workoutBuilderProvider.notifier)
                      .toggleExercise(exercise),
                  onInfo: _showExerciseDetails,
                ),
                _ReviewSaveStep(
                  nameController: _nameController,
                  selectedEquipment: _selectedEquipment.toList(),
                  selectedBodyParts: _selectedBodyParts.toList(),
                  exercises: exercises,
                  libraryMap: ref.watch(exerciseLibraryMapProvider),
                  estimatedMinutes: _estimatedMinutes(exercises),
                  onEditExercise: _showEditSheet,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    ref
                        .read(workoutBuilderProvider.notifier)
                        .reorder(oldIndex, newIndex);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    if (_currentStep > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () => _goToStep(_currentStep - 1),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _next,
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.background,
                                ),
                              )
                            : Text(_currentStep == 3 ? 'Save Workout' : 'Continue'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int currentStep;
  final ValueChanged<int> onStepTap;

  const _StepHeader({
    required this.currentStep,
    required this.onStepTap,
  });

  static const _labels = ['Equipment', 'Body', 'Library', 'Review'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Row(
        children: [
          for (var index = 0; index < _labels.length; index++) ...[
            if (index > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
              ),
            Expanded(
              child: _StepTab(
                label: _labels[index],
                isActive: currentStep == index,
                isDone: currentStep > index,
                enabled: index <= currentStep,
                onTap: () => onStepTap(index),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDone;
  final bool enabled;
  final VoidCallback onTap;

  const _StepTab({
    required this.label,
    required this.isActive,
    required this.isDone,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isActive
        ? AppTheme.primary
        : isDone
            ? AppTheme.surfaceElevated
            : AppTheme.cardBg;
    final borderColor =
        isActive ? AppTheme.primary : AppTheme.border;
    final labelColor = isActive
        ? AppTheme.background
        : isDone
            ? AppTheme.primary
            : AppTheme.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDone && !isActive) ...[
                const Icon(Icons.check_rounded, size: 12, color: AppTheme.primary),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: AppTheme.textLabel,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EquipmentStep extends StatelessWidget {
  final bool isLoading;
  final String? loadError;
  final String? fetchWarning;
  final VoidCallback onRetry;
  final Set<String> selected;
  final Map<String, int> exerciseCounts;
  final ValueChanged<String> onToggle;

  const _EquipmentStep({
    required this.isLoading,
    this.loadError,
    this.fetchWarning,
    required this.onRetry,
    required this.selected,
    required this.exerciseCounts,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final sortedEquipment = List<Equipment>.from(allEquipment)
      ..removeWhere((e) => (exerciseCounts[e.id] ?? 0) == 0)
      ..sort((a, b) => a.name.compareTo(b.name));

    return _BuilderStep(
      title: 'Choose Equipment',
      subtitle: 'Select what you have. Choose Bodyweight for floor-only moves.',
      child: _LibraryStepContent(
        isLoading: isLoading,
        loadError: loadError,
        fetchWarning: fetchWarning,
        onRetry: onRetry,
        emptyTitle: 'No equipment available',
        emptySubtitle: 'Try again once the exercise library has loaded.',
        isEmpty: sortedEquipment.isEmpty,
        builder: () => GridView.builder(
          itemCount: sortedEquipment.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.95,
          ),
          itemBuilder: (context, index) {
            final equipment = sortedEquipment[index];
            final isSelected = selected.contains(equipment.id);
            return _SelectionCard(
              label: equipment.name,
              icon: equipment.icon,
              exerciseCount: exerciseCounts[equipment.id] ?? 0,
              isSelected: isSelected,
              onTap: () => onToggle(equipment.id),
            );
          },
        ),
      ),
    );
  }
}

class _BodyPartsStep extends StatelessWidget {
  final bool isLoading;
  final String? loadError;
  final String? fetchWarning;
  final VoidCallback onRetry;
  final Set<String> selected;
  final Map<String, int> exerciseCounts;
  final ValueChanged<String> onToggle;

  const _BodyPartsStep({
    required this.isLoading,
    this.loadError,
    this.fetchWarning,
    required this.onRetry,
    required this.selected,
    required this.exerciseCounts,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final sortedBodyParts = List<(String, String)>.from(_bodyPartOptions)
      ..sort((a, b) => a.$2.compareTo(b.$2))
      ..removeWhere((bodyPart) => (exerciseCounts[bodyPart.$1] ?? 0) == 0);

    return _BuilderStep(
      title: 'Choose Body Parts',
      subtitle:
          'Counts show primary muscles for exercises matching your selected equipment.',
      child: _LibraryStepContent(
        isLoading: isLoading,
        loadError: loadError,
        fetchWarning: fetchWarning,
        onRetry: onRetry,
        emptyTitle: 'No body parts available',
        emptySubtitle:
            'Select equipment first, or try again once the library loads.',
        isEmpty: sortedBodyParts.isEmpty,
        builder: () => GridView.builder(
          itemCount: sortedBodyParts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.95,
          ),
          itemBuilder: (context, index) {
            final bodyPart = sortedBodyParts[index];
            return _SelectionCard(
              label: bodyPart.$2,
              icon: _muscleIcon(bodyPart.$1),
              exerciseCount: exerciseCounts[bodyPart.$1] ?? 0,
              isSelected: selected.contains(bodyPart.$1),
              onTap: () => onToggle(bodyPart.$1),
            );
          },
        ),
      ),
    );
  }
}

class _ExerciseLibraryStep extends StatelessWidget {
  final bool isLoading;
  final String? loadError;
  final String? fetchWarning;
  final VoidCallback onRetry;
  final Map<String, List<LibraryExercise>> groupedExercises;
  final Set<String> selectedExerciseIds;
  final ValueChanged<LibraryExercise> onToggle;
  final ValueChanged<LibraryExercise> onInfo;

  const _ExerciseLibraryStep({
    required this.isLoading,
    this.loadError,
    this.fetchWarning,
    required this.onRetry,
    required this.groupedExercises,
    required this.selectedExerciseIds,
    required this.onToggle,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return _BuilderStep(
      title: 'Exercise Library',
      subtitle: 'Tap to preview. Use + to add or remove exercises.',
      child: _LibraryStepContent(
        isLoading: isLoading,
        loadError: loadError,
        fetchWarning: fetchWarning,
        onRetry: onRetry,
        emptyTitle: 'No matching exercises',
        emptySubtitle: 'Try selecting more equipment or body parts.',
        isEmpty: groupedExercises.isEmpty,
        builder: () => ListView(
          children: groupedExercises.entries.expand((entry) {
            return [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 10),
                child: Text(
                  _label(entry.key),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              ...entry.value.map(
                (exercise) => _LibraryExerciseTile(
                  exercise: exercise,
                  isSelected: selectedExerciseIds.contains(exercise.id),
                  onToggle: () => onToggle(exercise),
                  onInfo: () => onInfo(exercise),
                ),
              ),
            ];
          }).toList(),
        ),
      ),
    );
  }
}

class _ReviewSaveStep extends StatelessWidget {
  final TextEditingController nameController;
  final List<String> selectedEquipment;
  final List<String> selectedBodyParts;
  final List<CustomWorkoutExercise> exercises;
  final Map<String, LibraryExercise> libraryMap;
  final int estimatedMinutes;
  final void Function(int, CustomWorkoutExercise) onEditExercise;
  final ReorderCallback onReorder;

  const _ReviewSaveStep({
    required this.nameController,
    required this.selectedEquipment,
    required this.selectedBodyParts,
    required this.exercises,
    required this.libraryMap,
    required this.estimatedMinutes,
    required this.onEditExercise,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return _BuilderStep(
      title: 'Review & Save',
      subtitle: 'Name your workout, then drag the handle to reorder exercises.',
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: Theme.of(context).textTheme.headlineSmall,
                  decoration: InputDecoration(
                    hintText: 'Workout name',
                    filled: true,
                    fillColor: AppTheme.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _TagWrap(title: 'Equipment', values: selectedEquipment),
                const SizedBox(height: 12),
                _TagWrap(title: 'Body Parts', values: selectedBodyParts),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatBadge(
                      icon: '🏋️',
                      label: '${exercises.length} exercises',
                    ),
                    const SizedBox(width: 8),
                    _StatBadge(icon: '⏱️', label: '~$estimatedMinutes min'),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (exercises.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: const _EmptyMessage(
                title: 'No exercises selected',
                subtitle: 'Go back to the library and add exercises first.',
              ),
            )
          else
            SliverReorderableList(
              itemCount: exercises.length,
              onReorder: onReorder,
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return _ReviewExerciseTile(
                  key: ValueKey(exercise.exerciseId),
                  index: index,
                  exercise: exercise,
                  libraryMedia: libraryMap[exercise.exerciseId]?.media,
                  onTap: () => onEditExercise(index, exercise),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _BuilderStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _BuilderStep({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String label;
  final String icon;
  final int? exerciseCount;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.label,
    required this.icon,
    this.exerciseCount,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.12)
              : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: TextStyle(fontSize: AppTheme.textIcon)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          isSelected ? AppTheme.primary : AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: AppTheme.textBody,
                    ),
                  ),
                  if (exerciseCount != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.primary.withOpacity(0.72)
                            : AppTheme.textMuted,
                        fontSize: AppTheme.textLabel,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _LibraryExerciseTile extends StatelessWidget {
  final LibraryExercise exercise;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onInfo;

  const _LibraryExerciseTile({
    required this.exercise,
    required this.isSelected,
    required this.onToggle,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primary.withOpacity(0.12)
            : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppTheme.primary : AppTheme.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onInfo,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _ExerciseThumb(media: exercise.media, size: 54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise.name,
                            style: TextStyle(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            exercise.requiredEquipment.map(_label).join(', '),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: AppTheme.textLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      exercise.media?.videoUrl != null
                          ? Icons.play_circle_outline
                          : Icons.info_outline,
                      color: AppTheme.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onToggle,
            icon: Icon(
              isSelected ? Icons.check_circle : Icons.add_circle,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewExerciseTile extends StatelessWidget {
  final int index;
  final CustomWorkoutExercise exercise;
  final ExerciseMedia? libraryMedia;
  final VoidCallback onTap;

  const _ReviewExerciseTile({
    super.key,
    required this.index,
    required this.exercise,
    required this.libraryMedia,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final media = resolveExerciseMedia(
      exerciseId: exercise.exerciseId,
      libraryMedia: libraryMedia,
      savedThumbnailUrl: exercise.thumbnailUrl,
    );

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
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.drag_handle,
                color: AppTheme.textMuted,
                size: 22,
              ),
            ),
          ),
          _ExerciseThumb(media: media, size: 52),
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
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.exerciseName,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.edit_outlined,
                        color: AppTheme.textMuted, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagWrap extends StatelessWidget {
  final String title;
  final List<String> values;

  const _TagWrap({required this.title, required this.values});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map((value) => _Tag(label: _label(value)))
              .toList(),
        ),
      ],
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
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.primary,
          fontSize: AppTheme.textLabel,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LibraryStepContent extends StatelessWidget {
  final bool isLoading;
  final String? loadError;
  final String? fetchWarning;
  final VoidCallback onRetry;
  final String emptyTitle;
  final String emptySubtitle;
  final bool isEmpty;
  final Widget Function() builder;

  const _LibraryStepContent({
    required this.isLoading,
    this.loadError,
    this.fetchWarning,
    required this.onRetry,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.isEmpty,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 14),
            Text(
              'Loading exercise library...',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: AppTheme.textLabel,
              ),
            ),
          ],
        ),
      );
    }

    if (loadError != null) {
      return _LibraryLoadError(
        message: loadError!,
        onRetry: onRetry,
      );
    }

    if (isEmpty) {
      return _EmptyMessage(
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return Column(
      children: [
        if (fetchWarning != null) ...[
          _LibraryFetchWarning(
            message: fetchWarning!,
            onRetry: onRetry,
          ),
          const SizedBox(height: 12),
        ],
        Expanded(child: builder()),
      ],
    );
  }
}

class _LibraryFetchWarning extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LibraryFetchWarning({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentYellow.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentYellow.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_outlined,
              color: AppTheme.accentYellow, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: AppTheme.textLabel,
                height: 1.4,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _LibraryLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LibraryLoadError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.accent, size: 48),
            const SizedBox(height: 14),
            Text(
              'Could not load exercises',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyMessage({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              color: AppTheme.textMuted, size: 48),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ExerciseDetailSheet extends StatelessWidget {
  final LibraryExercise exercise;

  const _ExerciseDetailSheet({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final hasMedia = exercise.media?.videoUrl != null ||
        exercise.media?.gifUrl != null ||
        exercise.media?.thumbnailUrl != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: hasMedia
                    ? ExerciseMediaWidget(
                        media: exercise.media,
                        fit: BoxFit.cover,
                        autoplayVideo: true,
                        loopVideo: true,
                        placeholder: Container(
                          color: AppTheme.surfaceElevated,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: AppTheme.surfaceElevated,
                        child: const Center(
                          child: Icon(
                            Icons.fitness_center_rounded,
                            color: AppTheme.textMuted,
                            size: 48,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              exercise.name,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 10),
            _TagWrap(title: 'Target muscles', values: exercise.muscleGroups),
            if (exercise.secondaryMuscles.isNotEmpty) ...[
              const SizedBox(height: 14),
              _TagWrap(
                title: 'Secondary muscles',
                values: exercise.secondaryMuscles,
              ),
            ],
            const SizedBox(height: 14),
            _TagWrap(
              title: 'Equipment needed',
              values: exercise.requiredEquipment,
            ),
            const SizedBox(height: 18),
            Text('How to', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              exercise.instructions.isNotEmpty
                  ? exercise.instructions
                  : exercise.description,
              style: TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExerciseThumb extends StatelessWidget {
  final ExerciseMedia? media;
  final double size;

  const _ExerciseThumb({required this.media, required this.size});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppTheme.surfaceElevated,
      child: const Center(
        child: Icon(Icons.fitness_center_rounded,
            color: AppTheme.textMuted, size: 24),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
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

String _label(String value) => value
    .split('_')
    .map((part) => part.isEmpty
        ? part
        : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _muscleIcon(String id) {
  switch (id) {
    case 'chest':
      return '🫁';
    case 'back':
      return '🔙';
    case 'shoulders':
      return '💪';
    case 'biceps':
      return '💪';
    case 'triceps':
      return '🦾';
    case 'quads':
      return '🦵';
    case 'hamstrings':
      return '🏃';
    case 'glutes':
      return '🍑';
    case 'core':
      return '⚡';
    case 'forearms':
      return '✊';
    default:
      return '🏋️';
  }
}

// ─────────────────────────────────────────────
// Edit sheet for per-exercise sets/reps/rest
// ─────────────────────────────────────────────
class _ExerciseEditSheet extends StatefulWidget {
  final CustomWorkoutExercise exercise;
  final ValueChanged<CustomWorkoutExercise> onSave;

  const _ExerciseEditSheet({
    required this.exercise,
    required this.onSave,
  });

  @override
  State<_ExerciseEditSheet> createState() => _ExerciseEditSheetState();
}

class _ExerciseEditSheetState extends State<_ExerciseEditSheet> {
  late int _sets;
  late int _reps;
  late int _seconds;
  late int _rest;
  late bool _isCircuit;

  @override
  void initState() {
    super.initState();
    _sets = widget.exercise.sets;
    _reps = widget.exercise.reps ?? 12;
    _seconds = widget.exercise.seconds ?? 30;
    _rest = widget.exercise.restSeconds;
    _isCircuit = widget.exercise.seconds != null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              widget.exercise.exerciseName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Text('Mode:',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(width: 12),
                _ModeChip(
                  label: 'Standard',
                  selected: !_isCircuit,
                  onTap: () => setState(() {
                    _isCircuit = false;
                    _sets = kStandardDefaultSets;
                  }),
                ),
                const SizedBox(width: 8),
                _ModeChip(
                  label: 'Circuit',
                  selected: _isCircuit,
                  onTap: () => setState(() {
                    _isCircuit = true;
                    _sets = kCircuitDefaultRounds;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _StepperRow(
              label: _isCircuit ? 'Rounds' : 'Sets',
              value: _sets,
              min: 1,
              max: 10,
              onDecrement: () => setState(() => _sets = (_sets - 1).clamp(1, 10)),
              onIncrement: () => setState(() => _sets = (_sets + 1).clamp(1, 10)),
            ),
            const SizedBox(height: 14),

            if (_isCircuit)
              _StepperRow(
                label: 'Exercise time',
                value: _seconds,
                min: 5,
                max: 300,
                step: 5,
                onDecrement: () =>
                    setState(() => _seconds = (_seconds - 5).clamp(5, 300)),
                onIncrement: () =>
                    setState(() => _seconds = (_seconds + 5).clamp(5, 300)),
              )
            else
              _StepperRow(
                label: 'Reps',
                value: _reps,
                min: 1,
                max: 100,
                onDecrement: () => setState(() => _reps = (_reps - 1).clamp(1, 100)),
                onIncrement: () => setState(() => _reps = (_reps + 1).clamp(1, 100)),
              ),

            const SizedBox(height: 14),

            _StepperRow(
              label: 'Rest',
              value: _rest,
              min: 0,
              max: 300,
              step: 15,
              onDecrement: () =>
                  setState(() => _rest = (_rest - 15).clamp(0, 300)),
              onIncrement: () =>
                  setState(() => _rest = (_rest + 15).clamp(0, 300)),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                widget.onSave(widget.exercise.copyWith(
                  sets: _sets,
                  reps: _isCircuit ? null : _reps,
                  seconds: _isCircuit ? _seconds : null,
                  restSeconds: _rest,
                ));
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.background : AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: AppTheme.textCaption,
          ),
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: AppTheme.textBody,
              )),
        ),
        _StepButton(
          icon: Icons.remove,
          onTap: value > min ? onDecrement : null,
        ),
        SizedBox(
          width: 52,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: AppTheme.textBody,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          onTap: value < max ? onIncrement : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null ? AppTheme.surfaceElevated : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(
          icon,
          color: onTap != null ? AppTheme.primary : AppTheme.textMuted,
          size: 18,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Stat badge
// ─────────────────────────────────────────────
class _StatBadge extends StatelessWidget {
  final String icon;
  final String label;

  const _StatBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: TextStyle(fontSize: AppTheme.textIcon)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: AppTheme.textCaption,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}
