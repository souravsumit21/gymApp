// lib/screens/workout/plan_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../../theme/app_theme.dart';

class PlanDetailScreen extends ConsumerWidget {
  final String planId;
  const PlanDetailScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final plansAsync = ref.watch(plansStreamProvider(uid));

    return plansAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (plans) {
        final plan = plans.where((p) => p.id == planId).firstOrNull;
        if (plan == null) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            appBar: AppBar(backgroundColor: AppTheme.background),
            body: const Center(
              child: Text('Plan not found',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          );
        }
        return _PlanDetailContent(plan: plan);
      },
    );
  }
}

class _PlanDetailContent extends StatelessWidget {
  final WorkoutPlan plan;
  const _PlanDetailContent({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.background,
            floating: true,
            leading: IconButton(
              onPressed: () => context.go('/workouts'),
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: AppTheme.textSecondary, size: 20),
            ),
            title: Text(plan.title,
                style: Theme.of(context).textTheme.headlineMedium),
            actions: [
              if (plan.isAiGenerated)
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentYellow.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.accentYellow.withOpacity(0.3)),
                  ),
                  child: const Text('AI',
                      style: TextStyle(
                        color: AppTheme.accentYellow,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      )),
                ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final day = plan.days[i];
                  return _DayCard(
                    day: day,
                    onStart: () => context.go(
                      '/workout/plan/${plan.id}/start/${day.id}',
                    ),
                  ).animate().fadeIn(delay: (i * 80).ms).slideY(begin: 0.1);
                },
                childCount: plan.days.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final WorkoutDay day;
  final VoidCallback onStart;

  const _DayCard({required this.day, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                day.targetBodyPart != null
                    ? (kMuscleEmoji[day.targetBodyPart] ?? '💪')
                    : '📅',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.name,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  '${day.exercises.length} exercises · ~${day.estimatedMinutes} min',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(72, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

// Muscle emoji map (shared with library)
const Map<String, String> kMuscleEmoji = {
  'chest': '💪', 'back': '🔙', 'shoulders': '🫸', 'arms': '💪',
  'biceps': '💪', 'triceps': '💪', 'core': '🎯', 'abs': '🎯',
  'legs': '🦵', 'quads': '🦵', 'hamstrings': '🦵', 'glutes': '🍑',
  'calves': '🦵', 'full_body': '🏋️', 'hip_flexors': '🦵',
  'Strength': '⚡', 'HIIT': '🔥', 'Cardio': '🏃', 'Mobility': '🧘',
};
