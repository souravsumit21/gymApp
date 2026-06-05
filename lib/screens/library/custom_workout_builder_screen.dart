// lib/screens/library/custom_workout_builder_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/exercise_media.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/library_service.dart';
import '../../theme/app_theme.dart';

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
  String? _error;

  @override
  void initState() {
    super.initState();
    Future(() {
      if (mounted) {
        ref.read(workoutBuilderProvider.notifier).clear();
      }
    });
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
      message = 'Choose equipment or tap Select All.';
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
        (part) =>
            exercise.muscleGroups.contains(part) ||
            exercise.secondaryMuscles.contains(part),
      );
      final matchesEquipment = exercise.requiredEquipment.every(
        (eq) => eq == 'none' || _selectedEquipment.contains(eq),
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
          .where((exercise) =>
              exercise.muscleGroups.contains(bodyPart) ||
              exercise.secondaryMuscles.contains(bodyPart))
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
      final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
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
        createdAt: now,
        updatedAt: now,
      );

      await svc.saveCustomWorkout(workout);
      ref.read(workoutBuilderProvider.notifier).clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout saved')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error saving workout: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleAllEquipment() {
    setState(() {
      if (_selectedEquipment.length == allEquipment.length) {
        _selectedEquipment.clear();
      } else {
        _selectedEquipment
          ..clear()
          ..addAll(allEquipment.map((e) => e.id));
      }
      _error = null;
    });
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

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(workoutBuilderProvider);
    final libraryAsync = ref.watch(exerciseLibraryProvider);
    final library = libraryAsync.valueOrNull ?? const <LibraryExercise>[];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          onPressed: () => context.go('/workouts'),
          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
        ),
        title: Text('Custom Workout',
            style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: Column(
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
                  selected: _selectedEquipment,
                  onToggleAll: _toggleAllEquipment,
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
                  selected: _selectedBodyParts,
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
                  groupedExercises: _groupedExercises(library),
                  isLoading: libraryAsync.isLoading && library.isEmpty,
                  loadError: libraryAsync.hasError
                      ? 'Using local fallback. Firestore error: ${libraryAsync.error}'
                      : null,
                  selectedExercises: exercises,
                  onAdd: (exercise) =>
                      ref.read(workoutBuilderProvider.notifier).addExercise(exercise),
                  onInfo: _showExerciseDetails,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    ref
                        .read(workoutBuilderProvider.notifier)
                        .reorder(oldIndex, newIndex);
                  },
                  onRemove: (index) =>
                      ref.read(workoutBuilderProvider.notifier).removeAt(index),
                  onEdit: _showEditSheet,
                ),
                _ReviewSaveStep(
                  nameController: _nameController,
                  selectedEquipment: _selectedEquipment.toList(),
                  selectedBodyParts: _selectedBodyParts.toList(),
                  exercises: exercises,
                  estimatedMinutes: _estimatedMinutes(exercises),
                  onEditExercise: _showEditSheet,
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
                    fontSize: 12,
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
  final Set<String> selected;
  final VoidCallback onToggleAll;
  final ValueChanged<String> onToggle;

  const _EquipmentStep({
    required this.selected,
    required this.onToggleAll,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _BuilderStep(
      title: 'Choose Equipment',
      subtitle: 'Select what is available for this workout.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onToggleAll,
              icon: const Icon(Icons.done_all_rounded),
              label: Text(selected.length == allEquipment.length
                  ? 'Clear All'
                  : 'Select All'),
            ),
          ),
          Expanded(
            child: GridView.builder(
              itemCount: allEquipment.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.15,
              ),
              itemBuilder: (context, index) {
                final equipment = allEquipment[index];
                final isSelected = selected.contains(equipment.id);
                return _SelectionCard(
                  label: equipment.name,
                  icon: equipment.icon,
                  isSelected: isSelected,
                  onTap: () => onToggle(equipment.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyPartsStep extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _BodyPartsStep({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return _BuilderStep(
      title: 'Choose Body Parts',
      subtitle: 'Pick the muscles this custom workout should target.',
      child: GridView.builder(
        itemCount: _bodyPartOptions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.25,
        ),
        itemBuilder: (context, index) {
          final bodyPart = _bodyPartOptions[index];
          return _SelectionCard(
            label: bodyPart.$2,
            icon: _muscleIcon(bodyPart.$1),
            isSelected: selected.contains(bodyPart.$1),
            onTap: () => onToggle(bodyPart.$1),
          );
        },
      ),
    );
  }
}

class _ExerciseLibraryStep extends StatelessWidget {
  final Map<String, List<LibraryExercise>> groupedExercises;
  final bool isLoading;
  final String? loadError;
  final List<CustomWorkoutExercise> selectedExercises;
  final ValueChanged<LibraryExercise> onAdd;
  final ValueChanged<LibraryExercise> onInfo;
  final ReorderCallback onReorder;
  final ValueChanged<int> onRemove;
  final void Function(int, CustomWorkoutExercise) onEdit;

  const _ExerciseLibraryStep({
    required this.groupedExercises,
    this.isLoading = false,
    this.loadError,
    required this.selectedExercises,
    required this.onAdd,
    required this.onInfo,
    required this.onReorder,
    required this.onRemove,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return _BuilderStep(
      title: 'Exercise Library',
      subtitle: 'Tap to add. Drag selected exercises to reorder.',
      child: Column(
        children: [
          if (loadError != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: Text(
                loadError!,
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (selectedExercises.isNotEmpty) ...[
            SizedBox(
              height: 152,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                itemCount: selectedExercises.length,
                onReorder: onReorder,
                itemBuilder: (context, index) {
                  final exercise = selectedExercises[index];
                  return _SelectedExerciseCard(
                    key: ValueKey('${exercise.exerciseId}-$index'),
                    exercise: exercise,
                    index: index,
                    onRemove: () => onRemove(index),
                    onEdit: () => onEdit(index, exercise),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
          ],
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : groupedExercises.isEmpty
                ? const _EmptyMessage(
                    title: 'No matching exercises',
                    subtitle: 'Try selecting more equipment or body parts.',
                  )
                : ListView(
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
                            onAdd: () => onAdd(exercise),
                            onInfo: () => onInfo(exercise),
                          ),
                        ),
                      ];
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSaveStep extends StatelessWidget {
  final TextEditingController nameController;
  final List<String> selectedEquipment;
  final List<String> selectedBodyParts;
  final List<CustomWorkoutExercise> exercises;
  final int estimatedMinutes;
  final void Function(int, CustomWorkoutExercise) onEditExercise;

  const _ReviewSaveStep({
    required this.nameController,
    required this.selectedEquipment,
    required this.selectedBodyParts,
    required this.exercises,
    required this.estimatedMinutes,
    required this.onEditExercise,
  });

  @override
  Widget build(BuildContext context) {
    return _BuilderStep(
      title: 'Review & Save',
      subtitle: 'Name your workout and confirm the exercise order.',
      child: ListView(
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
              _StatBadge(icon: '🏋️', label: '${exercises.length} exercises'),
              const SizedBox(width: 8),
              _StatBadge(icon: '⏱️', label: '~$estimatedMinutes min'),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < exercises.length; i++)
            _ReviewExerciseTile(
              index: i,
              exercise: exercises[i],
              onTap: () => onEditExercise(i, exercises[i]),
            ),
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
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.label,
    required this.icon,
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
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
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
  final VoidCallback onAdd;
  final VoidCallback onInfo;

  const _LibraryExerciseTile({
    required this.exercise,
    required this.onAdd,
    required this.onInfo,
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
          _ExerciseThumb(url: exercise.media?.displayUrl, size: 54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  exercise.requiredEquipment.map(_label).join(', '),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onInfo,
            icon: const Icon(Icons.info_outline, color: AppTheme.textSecondary),
          ),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

class _SelectedExerciseCard extends StatelessWidget {
  final CustomWorkoutExercise exercise;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  const _SelectedExerciseCard({
    super.key,
    required this.exercise,
    required this.index,
    required this.onRemove,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.drag_handle,
                    color: AppTheme.textMuted, size: 18),
                const Spacer(),
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(Icons.close,
                      color: AppTheme.textMuted, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                exercise.exerciseName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            GestureDetector(
              onTap: onEdit,
              child: Text(
                '${exercise.sets} sets · ${exercise.reps ?? exercise.seconds}${exercise.seconds == null ? ' reps' : ' sec'} · ${exercise.restSeconds}s rest',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewExerciseTile extends StatelessWidget {
  final int index;
  final CustomWorkoutExercise exercise;
  final VoidCallback onTap;

  const _ReviewExerciseTile({
    required this.index,
    required this.exercise,
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
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primary,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: AppTheme.background,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.exerciseName,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${exercise.sets} sets · ${exercise.reps ?? exercise.seconds}${exercise.seconds == null ? ' reps' : ' sec'} · ${exercise.restSeconds}s rest',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, color: AppTheme.textMuted, size: 18),
          ],
        ),
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
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
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
              child: SizedBox(
                height: 220,
                child: _ExerciseThumb(
                  url: exercise.media?.displayUrl,
                  size: double.infinity,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(exercise.name, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 10),
            _TagWrap(title: 'Target muscles', values: exercise.muscleGroups),
            const SizedBox(height: 14),
            _TagWrap(title: 'Equipment needed', values: exercise.requiredEquipment),
            const SizedBox(height: 18),
            Text('How to', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              exercise.instructions.isNotEmpty
                  ? exercise.instructions
                  : exercise.description,
              style: const TextStyle(
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
  final String? url;
  final double size;

  const _ExerciseThumb({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppTheme.surfaceElevated,
      child: const Center(
        child: Icon(Icons.fitness_center_rounded,
            color: AppTheme.textMuted, size: 24),
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: url == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              placeholder: (_, __) => placeholder,
              errorWidget: (_, __, ___) => placeholder,
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
  late bool _isTimeBased;

  @override
  void initState() {
    super.initState();
    _sets = widget.exercise.sets;
    _reps = widget.exercise.reps ?? 12;
    _seconds = widget.exercise.seconds ?? 30;
    _rest = widget.exercise.restSeconds;
    _isTimeBased = widget.exercise.seconds != null;
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

            // Time vs Reps toggle
            Row(
              children: [
                const Text('Mode:',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(width: 12),
                _ModeChip(
                  label: 'Reps',
                  selected: !_isTimeBased,
                  onTap: () => setState(() => _isTimeBased = false),
                ),
                const SizedBox(width: 8),
                _ModeChip(
                  label: 'Time',
                  selected: _isTimeBased,
                  onTap: () => setState(() => _isTimeBased = true),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Sets stepper
            _StepperRow(
              label: 'Sets',
              value: _sets,
              min: 1,
              max: 10,
              onDecrement: () => setState(() => _sets = (_sets - 1).clamp(1, 10)),
              onIncrement: () => setState(() => _sets = (_sets + 1).clamp(1, 10)),
            ),
            const SizedBox(height: 14),

            // Reps or seconds
            if (_isTimeBased)
              _StepperRow(
                label: 'Seconds',
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

            // Rest
            _StepperRow(
              label: 'Rest (seconds)',
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
                  reps: _isTimeBased ? null : _reps,
                  seconds: _isTimeBased ? _seconds : null,
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
            fontSize: 13,
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
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
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
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 20,
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
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}
