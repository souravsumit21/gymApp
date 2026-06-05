import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../../theme/app_theme.dart';

const _uuid = Uuid();

class CreatePlanScreen extends ConsumerStatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  PlanType _planType = PlanType.bodyPart;
  bool _useAI = true;
  bool _isGenerating = false;
  String? _error;

  // Body part selection
  final Set<String> _selectedBodyParts = {};

  // Weekly schedule
  final Map<String, String?> _weeklySchedule = {
    'Monday': null,
    'Tuesday': null,
    'Wednesday': null,
    'Thursday': null,
    'Friday': null,
    'Saturday': null,
    'Sunday': null,
  };

  final _bodyParts = [
    ('chest', '💪 Chest'),
    ('back', '🔙 Back'),
    ('shoulders', '🫸 Shoulders'),
    ('arms', '💪 Arms'),
    ('legs', '🦵 Legs'),
    ('core', '🎯 Core'),
    ('glutes', '🍑 Glutes'),
    ('full_body', '🏋️ Full Body'),
  ];

  final _workoutTypes = [
    'Strength',
    'HIIT',
    'Cardio',
    'Mobility',
    'Rest Day',
  ];

  Future<void> _generate() async {
    final authState = ref.read(authStateProvider);
    final uid = authState.valueOrNull?.uid;
    if (uid == null) return;

    setState(() { _isGenerating = true; _error = null; });

    try {
      final authService = ref.read(authServiceProvider);
      final profile = await authService.loadUserProfile(uid);
      if (profile == null) throw Exception('Profile not found');

      final workoutService = ref.read(workoutServiceProvider);

      WorkoutPlan plan;

      if (_useAI) {
        String description;
        if (_planType == PlanType.bodyPart) {
          description = 'Target these body parts: ${_selectedBodyParts.join(', ')}';
        } else {
          final days = _weeklySchedule.entries
              .where((e) => e.value != null && e.value != 'Rest Day')
              .map((e) => '${e.key}: ${e.value}')
              .join(', ');
          description = 'Weekly schedule: $days';
        }
        plan = await workoutService.generateAIPlan(
          user: profile,
          type: _planType,
          targetDescription: description,
        );
      } else {
        // Manual template plan
        plan = _buildManualPlan(uid);
      }

      await workoutService.savePlan(plan);
      if (mounted) context.go('/workouts/${plan.id}');
    } catch (e) {
      setState(() => _error = 'Failed to generate plan: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  WorkoutPlan _buildManualPlan(String userId) {
    List<WorkoutDay> days;

    if (_planType == PlanType.bodyPart) {
      days = _selectedBodyParts.map((bp) {
        return WorkoutDay(
          id: _uuid.v4(),
          name: bp.replaceAll('_', ' ').toUpperCase(),
          targetBodyPart: bp,
          exercises: [], // User will fill in
          estimatedMinutes: 40,
        );
      }).toList();
    } else {
      days = _weeklySchedule.entries
          .where((e) => e.value != null && e.value != 'Rest Day')
          .map((e) => WorkoutDay(
                id: _uuid.v4(),
                name: e.key,
                targetBodyPart: e.value,
                exercises: [],
                estimatedMinutes: 40,
              ))
          .toList();
    }

    return WorkoutPlan(
      id: _uuid.v4(),
      userId: userId,
      title: _planType == PlanType.bodyPart
          ? '${_selectedBodyParts.length}-Day Split'
          : 'My Weekly Plan',
      type: _planType,
      days: days,
      targetGoals: [],
      difficulty: 'intermediate',
      isAiGenerated: false,
      createdAt: DateTime.now(),
    );
  }

  bool get _canGenerate {
    if (_planType == PlanType.bodyPart) return _selectedBodyParts.isNotEmpty;
    return _weeklySchedule.values.any((v) => v != null && v != 'Rest Day');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          onPressed: () => context.go('/workouts'),
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textSecondary, size: 20),
        ),
        title: Text('Create Plan',
            style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan Type Toggle
            _SectionLabel('Plan Type'),
            const SizedBox(height: 10),
            _TypeToggle(
              selected: _planType,
              onChanged: (t) => setState(() => _planType = t),
            ),

            const SizedBox(height: 28),

            // AI Toggle
            _AIToggle(
              useAI: _useAI,
              onChanged: (v) => setState(() => _useAI = v),
            ),

            const SizedBox(height: 28),

            // Body Part Selector
            if (_planType == PlanType.bodyPart) ...[
              _SectionLabel('Target Body Parts'),
              const SizedBox(height: 10),
              _BodyPartSelector(
                bodyParts: _bodyParts,
                selected: _selectedBodyParts,
                onToggle: (id) => setState(() {
                  if (_selectedBodyParts.contains(id)) {
                    _selectedBodyParts.remove(id);
                  } else {
                    _selectedBodyParts.add(id);
                  }
                }),
              ),
            ]

            // Weekly Schedule
            else ...[
              _SectionLabel('Weekly Schedule'),
              const SizedBox(height: 10),
              _WeeklyScheduleBuilder(
                schedule: _weeklySchedule,
                workoutTypes: _workoutTypes,
                onChanged: (day, type) =>
                    setState(() => _weeklySchedule[day] = type),
              ),
            ],

            const SizedBox(height: 32),

            // Error
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: AppTheme.accent, fontSize: 13)),
              ),

            // Generate Button
            ElevatedButton(
              onPressed: (_canGenerate && !_isGenerating) ? _generate : null,
              child: _isGenerating
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: AppTheme.background,
                            strokeWidth: 2.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(_useAI
                            ? 'Claude is generating...'
                            : 'Creating plan...'),
                      ],
                    )
                  : Text(_useAI ? '⚡ Generate with AI' : 'Create Plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppTheme.textSecondary,
        letterSpacing: 1,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final PlanType selected;
  final ValueChanged<PlanType> onChanged;

  const _TypeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          _ToggleOption(
            label: '🎯 Body Part Split',
            selected: selected == PlanType.bodyPart,
            onTap: () => onChanged(PlanType.bodyPart),
          ),
          _ToggleOption(
            label: '📅 Weekly Schedule',
            selected: selected == PlanType.weeklySchedule,
            onTap: () => onChanged(PlanType.weeklySchedule),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppTheme.background : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AIToggle extends StatelessWidget {
  final bool useAI;
  final ValueChanged<bool> onChanged;

  const _AIToggle({required this.useAI, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: useAI
            ? AppTheme.accentYellow.withOpacity(0.08)
            : AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: useAI ? AppTheme.accentYellow.withOpacity(0.4) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Text('🤖', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Generate with AI',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: useAI ? AppTheme.accentYellow : AppTheme.textPrimary,
                    )),
                Text(
                  useAI
                      ? 'Claude will create a plan tailored to your profile'
                      : 'Start with a blank template',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Switch(
            value: useAI,
            onChanged: onChanged,
            activeColor: AppTheme.accentYellow,
          ),
        ],
      ),
    );
  }
}

class _BodyPartSelector extends StatelessWidget {
  final List<(String, String)> bodyParts;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _BodyPartSelector({
    required this.bodyParts,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.5,
      ),
      itemCount: bodyParts.length,
      itemBuilder: (context, i) {
        final (id, label) = bodyParts[i];
        final isSelected = selected.contains(id);
        return GestureDetector(
          onTap: () => onToggle(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withOpacity(0.12)
                  : AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeeklyScheduleBuilder extends StatelessWidget {
  final Map<String, String?> schedule;
  final List<String> workoutTypes;
  final void Function(String day, String? type) onChanged;

  const _WeeklyScheduleBuilder({
    required this.schedule,
    required this.workoutTypes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: schedule.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(entry.key,
                    style: Theme.of(context).textTheme.labelLarge),
              ),
              Expanded(
                child: DropdownButton<String>(
                  value: entry.value,
                  hint: const Text('Rest Day',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      )),
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: AppTheme.surfaceElevated,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Rest Day',
                          style: TextStyle(color: AppTheme.textMuted)),
                    ),
                    ...workoutTypes.map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t),
                        )),
                  ],
                  onChanged: (v) => onChanged(entry.key, v),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
