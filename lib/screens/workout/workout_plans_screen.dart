import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/exercise_media.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/library_service.dart';
import '../../services/purchase_service.dart';
import '../../services/notification_service.dart';
import '../../services/workout_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/share_workout_sheet.dart';

enum _WorkoutHeaderAction { profile, settings, premium, signOut }

class WorkoutPlansScreen extends ConsumerWidget {
  const WorkoutPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final uid = authState.valueOrNull?.uid ?? '';
    final hasUid = uid.isNotEmpty;
    final premiumAsync = ref.watch(premiumStatusProvider);
    final plansAsync = hasUid
        ? ref.watch(plansStreamProvider(uid))
        : const AsyncValue<List<WorkoutPlan>>.loading();
    final customWorkoutsAsync = hasUid
        ? ref.watch(customWorkoutsProvider(uid))
        : const AsyncValue<List<CustomWorkout>>.loading();

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
              IconButton(
                tooltip: 'Community Library',
                onPressed: () => context.go('/community'),
                icon: const Icon(
                  Icons.groups_outlined,
                  color: AppTheme.textSecondary,
                ),
              ),
              _NotificationBell(userId: uid),
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
            child: _PrimaryCustomWorkoutCta(
              onTap: () => context.go('/workouts/custom/new'),
            ),
          ),
          const SliverToBoxAdapter(
            child: _SectionHeader(title: 'Your Workouts'),
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
                      onTap: () =>
                          context.go('/workouts/custom/${workouts[i].id}'),
                      onStart: () => context
                          .go('/workout/custom/${workouts[i].id}/start'),
                      onShare: () async {
                        final profile =
                            await ref.read(userProfileProvider(uid).future);
                        if (profile != null && context.mounted) {
                          await ShareWorkoutSheet.show(
                            context,
                            ref,
                            workout: workouts[i],
                            creator: profile,
                          );
                        }
                      },
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
          premiumAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: _AiPlansSectionHeader(isLocked: true),
              ),
            ),
            error: (_, __) => SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: _AiPlansSectionHeader(isLocked: true),
                  ),
                  _AiPlansLockedCard(onTap: () => context.go('/paywall')),
                ],
              ),
            ),
            data: (isPremium) {
              if (!isPremium) {
                return SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: _AiPlansSectionHeader(isLocked: true),
                      ),
                      _AiPlansLockedCard(
                        onTap: () => context.go('/paywall'),
                      ),
                    ],
                  ),
                );
              }
              return SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: _AiPlansSectionHeader(
                        isLocked: false,
                        onCreate: () => context.go('/workouts/create'),
                      ),
                    ),
                  ),
                  plansAsync.when(
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
                  ),
                ],
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

class _NotificationBell extends ConsumerWidget {
  final String userId;

  const _NotificationBell({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.isEmpty) return const SizedBox.shrink();
    final unreadAsync = ref.watch(unreadNotificationCountProvider(userId));

    return unreadAsync.when(
      data: (count) => IconButton(
        onPressed: () => context.push('/notifications'),
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          child: const Icon(Icons.notifications_outlined,
              color: AppTheme.textSecondary),
        ),
      ),
      loading: () => IconButton(
        onPressed: () => context.push('/notifications'),
        icon: const Icon(Icons.notifications_outlined,
            color: AppTheme.textSecondary),
      ),
      error: (_, __) => IconButton(
        onPressed: () => context.push('/notifications'),
        icon: const Icon(Icons.notifications_outlined,
            color: AppTheme.textSecondary),
      ),
    );
  }
}

class _PrimaryCustomWorkoutCta extends StatelessWidget {
  final VoidCallback onTap;

  const _PrimaryCustomWorkoutCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Material(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Create Custom Workout',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your equipment. Your exercises. Your order.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.78),
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Start Building',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}

class _AiPlansSectionHeader extends StatelessWidget {
  final bool isLocked;
  final VoidCallback? onCreate;

  const _AiPlansSectionHeader({
    required this.isLocked,
    this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'AI Workout Plans',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (isLocked) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 12, color: AppTheme.textMuted),
                SizedBox(width: 4),
                Text(
                  'Premium',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
        const Spacer(),
        if (!isLocked && onCreate != null)
          TextButton(onPressed: onCreate, child: const Text('Create')),
      ],
    );
  }
}

class _CustomWorkoutCard extends ConsumerWidget {
  final CustomWorkout workout;
  final String userId;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _CustomWorkoutCard({
    required this.workout,
    required this.userId,
    required this.onTap,
    required this.onStart,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(customWorkoutPresetsProvider(
      (userId: userId, workoutId: workout.id),
    ));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: onShare,
                icon: const Icon(Icons.share_outlined,
                    color: AppTheme.textSecondary, size: 22),
              ),
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

class _AiPlansLockedCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AiPlansLockedCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.accentYellow.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.accentYellow,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Unlock AI Workout Plans',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Get personalized multi-day plans generated for your goals, equipment, and schedule. Premium unlocks AI plans — custom workouts will join the subscription before launch.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('Unlock Premium'),
              ),
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
