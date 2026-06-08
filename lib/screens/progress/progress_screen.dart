import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../services/progress_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/progress/body_part_streaks_grid.dart';
import '../../widgets/progress/consistency_score_section.dart';
import '../../widgets/progress/milestone_badges_section.dart';
import '../../widgets/progress/weekly_streak_card.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  DateTime? _selectedMonth;
  bool _activatingFreeze = false;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final snapshot = ref.watch(
      progressSnapshotProvider(
        ProgressSnapshotRequest(
          userId: uid,
          selectedMonth: _selectedMonth,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: snapshot == null
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: AppTheme.background,
                  floating: true,
                  title: Text('Progress',
                      style: Theme.of(context).textTheme.headlineLarge),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WeeklyStreakCard(
                          summary: snapshot.weeklyStreak,
                          activatingFreeze: _activatingFreeze,
                          onActivateFreeze: () => _activateFreeze(uid),
                        ).animate().fadeIn(),
                        const SizedBox(height: 28),
                        BodyPartStreaksGrid(
                          streaks: snapshot.bodyPartStreaks,
                        ).animate().fadeIn(delay: 80.ms),
                        const SizedBox(height: 28),
                        ConsistencyScoreSection(
                          month: snapshot.selectedMonth,
                          history: snapshot.monthHistory,
                          onMonthChanged: (month) =>
                              setState(() => _selectedMonth = month),
                        ).animate().fadeIn(delay: 120.ms),
                        const SizedBox(height: 28),
                        MilestoneBadgesSection(
                          badges: snapshot.badges,
                        ).animate().fadeIn(delay: 160.ms),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _activateFreeze(String uid) async {
    if (uid.isEmpty) return;
    setState(() => _activatingFreeze = true);
    try {
      await ref.read(progressServiceProvider).activateStreakFreeze(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Streak freeze activated for this week'),
        ),
      );
    } on ProgressException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not activate freeze: $e')),
      );
    } finally {
      if (mounted) setState(() => _activatingFreeze = false);
    }
  }
}
