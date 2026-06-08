import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../models/share_models.dart';
import '../../services/community_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/workout_share_utils.dart';

class CommunityLibraryScreen extends ConsumerStatefulWidget {
  const CommunityLibraryScreen({super.key});

  @override
  ConsumerState<CommunityLibraryScreen> createState() =>
      _CommunityLibraryScreenState();
}

class _CommunityLibraryScreenState
    extends ConsumerState<CommunityLibraryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(communityFilterProvider);
    final workoutsAsync = ref.watch(communityWorkoutsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Community Library'),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(communityWorkoutsProvider);
          await ref.read(communityWorkoutsProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search workouts or keywords',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: filter.query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(communityFilterProvider.notifier)
                                  .setQuery('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => ref
                      .read(communityFilterProvider.notifier)
                      .setQuery(v),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _FilterBar(filter: filter)),
            SliverToBoxAdapter(child: _SortBar(sort: filter.sort)),
            workoutsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e')),
              ),
              data: (workouts) {
                if (workouts.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No community workouts found',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _CommunityWorkoutCard(
                        workout: workouts[i],
                        onTap: () =>
                            context.push('/community/${workouts[i].id}'),
                      ),
                      childCount: workouts.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  final CommunityFilterState filter;

  const _FilterBar({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _FilterChip(
            label: 'Experience',
            value: filter.experienceLevel == 'all'
                ? null
                : labelTag(filter.experienceLevel),
            onTap: () => _showExperiencePicker(context, ref),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Duration',
            value: filter.maxDuration != null
                ? '≤ ${filter.maxDuration} min'
                : null,
            onTap: () => _showDurationPicker(context, ref),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Mode',
            value:
                filter.workoutMode == 'all' ? null : labelTag(filter.workoutMode),
            onTap: () => _showModePicker(context, ref),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Body part',
            value: filter.bodyParts.isEmpty
                ? null
                : '${filter.bodyParts.length} selected',
            onTap: () => _showBodyPartPicker(context, ref),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Equipment',
            value: filter.equipment.isEmpty
                ? null
                : '${filter.equipment.length} selected',
            onTap: () => _showEquipmentPicker(context, ref),
          ),
          if (filter.hasActiveFilters) ...[
            const SizedBox(width: 8),
            ActionChip(
              label: const Text('Clear'),
              onPressed: () =>
                  ref.read(communityFilterProvider.notifier).reset(),
            ),
          ],
        ],
      ),
    );
  }

  void _showExperiencePicker(BuildContext context, WidgetRef ref) {
    _showOptions(
      context,
      title: 'Experience level',
      options: const ['all', 'beginner', 'intermediate', 'advanced'],
      selected: ref.read(communityFilterProvider).experienceLevel,
      onSelect: (v) =>
          ref.read(communityFilterProvider.notifier).setExperienceLevel(v),
    );
  }

  void _showDurationPicker(BuildContext context, WidgetRef ref) {
    _showOptions(
      context,
      title: 'Max duration',
      options: const ['all', '20', '30', '45', '60'],
      selected: ref.read(communityFilterProvider).maxDuration?.toString() ?? 'all',
      onSelect: (v) => ref.read(communityFilterProvider.notifier).setMaxDuration(
            v == 'all' ? null : int.parse(v),
          ),
    );
  }

  void _showModePicker(BuildContext context, WidgetRef ref) {
    _showOptions(
      context,
      title: 'Workout mode',
      options: const ['all', 'standard', 'circuit'],
      selected: ref.read(communityFilterProvider).workoutMode,
      onSelect: (v) =>
          ref.read(communityFilterProvider.notifier).setWorkoutMode(v),
    );
  }

  void _showBodyPartPicker(BuildContext context, WidgetRef ref) {
    final options = [
      'chest',
      'back',
      'shoulders',
      'arms',
      'legs',
      'core',
      'glutes',
      'full_body',
    ];
    final current = ref.read(communityFilterProvider).bodyParts;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => _MultiSelectSheet(
        title: 'Body parts',
        options: options,
        selected: current,
        onApply: (selected) =>
            ref.read(communityFilterProvider.notifier).setBodyParts(selected),
      ),
    );
  }

  void _showEquipmentPicker(BuildContext context, WidgetRef ref) {
    final options = allEquipment.map((e) => e.id).toList();
    final current = ref.read(communityFilterProvider).equipment;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => _MultiSelectSheet(
        title: 'Equipment',
        options: options,
        selected: current,
        labelBuilder: labelTag,
        onApply: (selected) =>
            ref.read(communityFilterProvider.notifier).setEquipment(selected),
      ),
    );
  }

  void _showOptions(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title,
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            ...options.map(
              (opt) => ListTile(
                title: Text(opt == 'all' ? 'All' : labelTag(opt)),
                trailing: selected == opt
                    ? const Icon(Icons.check_rounded, color: AppTheme.primary)
                    : null,
                onTap: () {
                  onSelect(opt);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortBar extends ConsumerWidget {
  final CommunitySort sort;

  const _SortBar({required this.sort});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          const Text('Sort by',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(width: 10),
          ChoiceChip(
            label: const Text('Popular'),
            selected: sort == CommunitySort.popular,
            onSelected: (_) => ref
                .read(communityFilterProvider.notifier)
                .setSort(CommunitySort.popular),
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('Newest'),
            selected: sort == CommunitySort.newest,
            onSelected: (_) => ref
                .read(communityFilterProvider.notifier)
                .setSort(CommunitySort.newest),
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('Most saved'),
            selected: sort == CommunitySort.mostSaved,
            onSelected: (_) => ref
                .read(communityFilterProvider.notifier)
                .setSort(CommunitySort.mostSaved),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = value != null;
    return ActionChip(
      label: Text(active ? '$label: $value' : label),
      backgroundColor: active ? AppTheme.primary.withOpacity(0.08) : null,
      onPressed: onTap,
    );
  }
}

class _MultiSelectSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final List<String> selected;
  final String Function(String)? labelBuilder;
  final ValueChanged<List<String>> onApply;

  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.onApply,
    this.labelBuilder,
  });

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.labelBuilder ?? (s) => s;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.title,
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView(
              shrinkWrap: true,
              children: widget.options.map((opt) {
                return CheckboxListTile(
                  title: Text(label(opt)),
                  value: _selected.contains(opt),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(opt);
                      } else {
                        _selected.remove(opt);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_selected.toList());
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityWorkoutCard extends StatelessWidget {
  final CommunityWorkout workout;
  final VoidCallback onTap;

  const _CommunityWorkoutCard({
    required this.workout,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workout.name,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '@${workout.creatorUsername}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...workout.bodyParts
                    .take(3)
                    .map((p) => _MiniTag(labelTag(p))),
                ...workout.equipment
                    .take(2)
                    .map((e) => _MiniTag(labelTag(e))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${workout.exerciseCount} exercises · ~${workout.estimatedMinutes} min',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                const Icon(Icons.bookmark_border_rounded,
                    size: 16, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${workout.saveCount}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
