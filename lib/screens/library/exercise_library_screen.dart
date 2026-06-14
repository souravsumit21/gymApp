// lib/screens/library/exercise_library_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/exercise_media.dart';
import '../../services/library_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/exercise_media_widget.dart';
import 'exercise_detail_screen.dart';

const _muscleEmoji = {
  'chest': '💪',
  'back': '🪽',
  'shoulders': '🏋️',
  'arms': '💪',
  'legs': '🦵',
  'core': '🔥',
  'glutes': '🍑',
  'full_body': '⚡',
};

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  /// When non-null, show an "Add to workout" action instead of view-only
  final bool selectionMode;
  final void Function(LibraryExercise)? onExerciseSelected;

  const ExerciseLibraryScreen({
    super.key,
    this.selectionMode = false,
    this.onExerciseSelected,
  });

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState
    extends ConsumerState<ExerciseLibraryScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;

  final _categories = ['all', 'strength', 'cardio', 'core', 'flexibility', 'plyometric'];
  final _muscles = ['all', 'chest', 'back', 'shoulders', 'arms', 'legs', 'core', 'glutes', 'full_body'];
  final _difficulties = ['all', 'beginner', 'intermediate', 'advanced'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(libraryFilterProvider.notifier)
            .setCategory(_categories[_tabController.index]);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(filteredExerciseLibraryProvider);
    final filter = ref.watch(libraryFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerScrolled) => [
          SliverAppBar(
            backgroundColor: AppTheme.background,
            floating: true,
            pinned: true,
            snap: true,
            leading: widget.selectionMode
                ? IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            title: Text(
              widget.selectionMode ? 'Add Exercise' : 'Exercise Library',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(116),
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _SearchBar(
                      controller: _searchController,
                      onChanged: (q) => ref
                          .read(libraryFilterProvider.notifier)
                          .setQuery(q),
                    ),
                  ),
                  // Category tabs
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicator: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: AppTheme.background,
                    unselectedLabelColor: AppTheme.textSecondary,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: AppTheme.textLabel,
                    ),
                    tabs: _categories
                        .map((c) => Tab(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  c == 'all'
                                      ? 'All'
                                      : c[0].toUpperCase() + c.substring(1),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            // Muscle / difficulty filter chips
            _FilterChipsRow(
              selectedMuscle: filter.muscle,
              selectedDifficulty: filter.difficulty,
              muscles: _muscles,
              difficulties: _difficulties,
              hasActiveFilters: filter.hasActiveFilters,
              onMuscleChanged: (m) =>
                  ref.read(libraryFilterProvider.notifier).setMuscle(m),
              onDifficultyChanged: (d) =>
                  ref.read(libraryFilterProvider.notifier).setDifficulty(d),
              onReset: () {
                _searchController.clear();
                ref.read(libraryFilterProvider.notifier).reset();
                _tabController.animateTo(0);
              },
            ),

            // Exercise count
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  Text(
                    '${exercises.length} exercise${exercises.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: AppTheme.textLabel,
                    ),
                  ),
                ],
              ),
            ),

            // Grid
            Expanded(
              child: exercises.isEmpty
                  ? _EmptyLibraryState(
                      onReset: () {
                        _searchController.clear();
                        ref.read(libraryFilterProvider.notifier).reset();
                        _tabController.animateTo(0);
                      },
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: exercises.length,
                      itemBuilder: (context, i) {
                        return _ExerciseCard(
                          exercise: exercises[i],
                          selectionMode: widget.selectionMode,
                          onTap: () {
                            if (widget.selectionMode) {
                              widget.onExerciseSelected?.call(exercises[i]);
                              Navigator.of(context).pop();
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ExerciseDetailScreen(
                                    exercise: exercises[i],
                                  ),
                                ),
                              );
                            }
                          },
                        ).animate().fadeIn(
                              delay: (i * 40).ms,
                              duration: 300.ms,
                            );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: AppTheme.textLabel),
        decoration: const InputDecoration(
          hintText: 'Search exercises, muscles, tags…',
          hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: AppTheme.textLabel),
          prefixIcon: Icon(Icons.search, color: AppTheme.textMuted, size: 18),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
          isDense: true,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Filter chips row
// ─────────────────────────────────────────────
class _FilterChipsRow extends StatelessWidget {
  final String selectedMuscle;
  final String selectedDifficulty;
  final List<String> muscles;
  final List<String> difficulties;
  final bool hasActiveFilters;
  final ValueChanged<String> onMuscleChanged;
  final ValueChanged<String> onDifficultyChanged;
  final VoidCallback onReset;

  const _FilterChipsRow({
    required this.selectedMuscle,
    required this.selectedDifficulty,
    required this.muscles,
    required this.difficulties,
    required this.hasActiveFilters,
    required this.onMuscleChanged,
    required this.onDifficultyChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          // Reset chip
          if (hasActiveFilters)
            _Chip(
              label: '✕ Reset',
              selected: false,
              accent: AppTheme.accent,
              onTap: onReset,
            ),

          // Muscle filter
          for (final m in muscles)
            _Chip(
              label: m == 'all'
                  ? '💪 All Muscles'
                  : '${_muscleEmoji[m] ?? '💪'} ${m[0].toUpperCase()}${m.substring(1)}',
              selected: selectedMuscle == m,
              onTap: () => onMuscleChanged(m),
            ),

          const SizedBox(width: 8),
          Container(width: 1, height: 20, color: AppTheme.border),
          const SizedBox(width: 8),

          // Difficulty filter
          for (final d in difficulties)
            _Chip(
              label: d == 'all'
                  ? 'Any Level'
                  : d[0].toUpperCase() + d.substring(1),
              selected: selectedDifficulty == d,
              accent: AppTheme.accentYellow,
              onTap: () => onDifficultyChanged(d),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? accent;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppTheme.textSecondary,
            fontSize: AppTheme.textLabel,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Exercise card with GIF/video preview
// ─────────────────────────────────────────────
class _ExerciseCard extends StatefulWidget {
  final LibraryExercise exercise;
  final bool selectionMode;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.exercise,
    required this.selectionMode,
    required this.onTap,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media preview
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ExerciseMediaWidget(
                    media: ex.media,
                    fit: BoxFit.cover,
                    autoplayVideo: false,
                    loopVideo: false,
                    placeholder: _MediaPlaceholder(name: ex.name),
                  ),

                  // Gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppTheme.cardBg.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // GIF badge
                  if (ex.media?.primaryType == MediaType.gif)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.background.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'GIF',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: AppTheme.textCaption,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                  // Add button in selection mode
                  if (widget.selectionMode)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: AppTheme.background,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ex.name,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: AppTheme.textCaption,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        // Primary muscle chip
                        if (ex.muscleGroups.isNotEmpty)
                          _MiniChip(
                            label: ex.muscleGroups.first,
                            color: AppTheme.primary,
                          ),
                        const Spacer(),
                        // Difficulty dot
                        _DifficultyDot(difficulty: ex.difficulty),
                      ],
                    ),
                    // Sets/reps line
                    Text(
                      ex.isTimeBased
                          ? '${ex.defaultSets}×${ex.defaultSeconds}s'
                          : '${ex.defaultSets}×${ex.defaultReps ?? '?'} reps',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: AppTheme.textLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  final String name;
  const _MediaPlaceholder({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceElevated,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center_rounded,
                color: AppTheme.textMuted, size: 32),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: AppTheme.textCaption,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: AppTheme.textCaption,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DifficultyDot extends StatelessWidget {
  final String difficulty;
  const _DifficultyDot({required this.difficulty});

  Color get _color {
    switch (difficulty) {
      case 'beginner': return const Color(0xFF4DFFB4);
      case 'intermediate': return const Color(0xFFFFD74D);
      case 'advanced': return AppTheme.accent;
      default: return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          difficulty[0].toUpperCase() + difficulty.substring(1, 3),
          style: TextStyle(color: _color, fontSize: AppTheme.textCaption, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  final VoidCallback onReset;
  const _EmptyLibraryState({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('No exercises found',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Try adjusting your filters',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onReset, child: const Text('Clear Filters')),
        ],
      ),
    );
  }
}
