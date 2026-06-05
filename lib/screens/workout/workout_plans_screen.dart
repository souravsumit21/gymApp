import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/exercise_media.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/library_service.dart';
import '../../services/purchase_service.dart';
import '../../services/workout_service.dart';
import '../../theme/app_theme.dart';

enum _WorkoutHeaderAction { profile, settings, premium, signOut }

class WorkoutPlansScreen extends ConsumerWidget {
  const WorkoutPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premiumAsync = ref.watch(premiumStatusProvider);
    final authState = ref.watch(authStateProvider);
    final uid = authState.valueOrNull?.uid ?? '';
    final plansAsync = ref.watch(plansStreamProvider(uid));
    final customWorkoutsAsync = ref.watch(customWorkoutsProvider(uid));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.background,
            floating: true,
            title: Text('Workouts',
                style: Theme.of(context).textTheme.headlineLarge),
            actions: [
              PopupMenuButton<_WorkoutHeaderAction>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppTheme.textSecondary),
                color: AppTheme.surface,
                onSelected: (action) async {
                  switch (action) {
                    case _WorkoutHeaderAction.profile:
                      _showComingSoon(context, 'Profile');
                      break;
                    case _WorkoutHeaderAction.settings:
                      context.go('/settings');
                      break;
                    case _WorkoutHeaderAction.premium:
                      context.go('/paywall');
                      break;
                    case _WorkoutHeaderAction.signOut:
                      await ref.read(authServiceProvider).signOut();
                      if (context.mounted) context.go('/login');
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _WorkoutHeaderAction.profile,
                    child: _HeaderMenuItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Profile',
                    ),
                  ),
                  PopupMenuItem(
                    value: _WorkoutHeaderAction.settings,
                    child: _HeaderMenuItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                    ),
                  ),
                  PopupMenuItem(
                    value: _WorkoutHeaderAction.premium,
                    child: _HeaderMenuItem(
                      icon: Icons.workspace_premium_outlined,
                      label: 'Premium',
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: _WorkoutHeaderAction.signOut,
                    child: _HeaderMenuItem(
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      isDestructive: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _CreateCustomWorkoutCard(
                onTap: () => context.go('/workouts/custom/new'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Custom Workouts',
              actionLabel: 'New',
              onAction: () => context.go('/workouts/custom/new'),
            ),
          ),
          customWorkoutsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Error: $e',
                    style: const TextStyle(color: AppTheme.accent)),
              ),
            ),
            data: (workouts) {
              if (workouts.isEmpty) {
                return const SliverToBoxAdapter(
                    child: _EmptyCustomWorkoutState());
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _CustomWorkoutCard(
                      workout: workouts[i],
                      userId: uid,
                      onStart: () => context
                          .go('/workout/custom/${workouts[i].id}/start'),
                      onDelete: () => ref
                          .read(libraryServiceProvider)
                          .deleteCustomWorkout(uid, workouts[i].id),
                    ).animate().fadeIn(delay: (i * 60).ms),
                    childCount: workouts.length,
                  ),
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'AI Workout Plans',
              actionLabel: 'Create',
              onAction: () => context.go('/workouts/create'),
            ),
          ),
          premiumAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              ),
            ),
            error: (_, __) => SliverToBoxAdapter(
              child: _InlinePaywallCard(onTap: () => context.go('/paywall')),
            ),
            data: (isPremium) {
              if (!isPremium) {
                return SliverToBoxAdapter(
                  child:
                      _InlinePaywallCard(onTap: () => context.go('/paywall')),
                );
              }
              return plansAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Error: $e',
                        style: const TextStyle(color: AppTheme.accent)),
                  ),
                ),
                data: (plans) {
                  if (plans.isEmpty) {
                    return SliverToBoxAdapter(child: _EmptyPlansState());
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _PlanCard(
                          plan: plans[i],
                          onTap: () => context.go('/workouts/${plans[i].id}'),
                          onDelete: () => ref
                              .read(workoutServiceProvider)
                              .deletePlan(uid, plans[i].id),
                        )
                            .animate()
                            .fadeIn(delay: (i * 80).ms)
                            .slideY(begin: 0.1),
                        childCount: plans.length,
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _HeaderMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;

  const _HeaderMenuItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppTheme.accent : AppTheme.textPrimary;
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

void _showComingSoon(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label coming soon')),
  );
}

class _CreateCustomWorkoutCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateCustomWorkoutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFDF5),
                Color(0xFFF7F7F8),
              ],
            ),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.tune_rounded,
                    color: AppTheme.background, size: 28),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create Custom Workout',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  const Text(
                    'Pick equipment, body parts, and exercises in your own order.',
                    style:
                        TextStyle(color: AppTheme.textSecondary, height: 1.35),
                  ),
                ],
              ),
            ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.primary, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const Spacer(),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _CustomWorkoutCard extends ConsumerWidget {
  final CustomWorkout workout;
  final String userId;
  final VoidCallback onStart;
  final VoidCallback onDelete;

  const _CustomWorkoutCard({
    required this.workout,
    required this.userId,
    required this.onStart,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(customWorkoutPresetsProvider(
      (userId: userId, workoutId: workout.id),
    ));
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.fitness_center_rounded,
                color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${workout.exerciseCount} exercises · ~${workout.estimatedMinutes} min',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (workout.targetBodyParts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: workout.targetBodyParts
                        .take(4)
                        .map((part) => _MiniChip(_label(part)))
                        .toList(),
                  ),
                ],
                presetsAsync.maybeWhen(
                  data: (presets) => presets.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${presets.length} preset${presets.length == 1 ? '' : 's'} saved',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: onStart,
                icon: const Icon(Icons.play_circle_fill_rounded,
                    color: AppTheme.primary, size: 30),
              ),
              IconButton(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.textMuted, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Workout?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('This custom workout will be removed.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child:
                const Text('Delete', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;

  const _MiniChip(this.label);

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
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyCustomWorkoutState extends StatelessWidget {
  const _EmptyCustomWorkoutState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 8, 40, 24),
      child: Column(
        children: [
          const Icon(Icons.playlist_add_rounded,
              color: AppTheme.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            'No custom workouts yet',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Create your own workout from the exercise library.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InlinePaywallCard extends StatelessWidget {
  final VoidCallback onTap;

  const _InlinePaywallCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI plans are premium',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Custom workouts are available now. Configure RevenueCat later to unlock AI plan subscriptions.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onTap,
              child: const Text('View Plans & Pricing'),
            ),
          ],
        ),
      ),
    );
  }
}

String _label(String value) => value
    .split('_')
    .map((part) =>
        part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

// ─────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────
class _EmptyPlansState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Text('🏋️', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          Text(
            'No plans yet',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first workout plan\nto get started.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go('/workouts/create'),
            icon: const Icon(Icons.add),
            label: const Text('Create a Plan'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Plan card
// ─────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final WorkoutPlan plan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PlanCard({
    required this.plan,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
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
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  plan.isAiGenerated ? '🤖' : '📋',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plan.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (plan.isAiGenerated)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentYellow.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: AppTheme.accentYellow.withOpacity(0.3)),
                          ),
                          child: const Text('AI',
                              style: TextStyle(
                                color: AppTheme.accentYellow,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              )),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${plan.days.length} days · ${plan.difficulty}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline,
                  color: AppTheme.textMuted, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Plan?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('This action cannot be undone.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child:
                const Text('Delete', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }
}
