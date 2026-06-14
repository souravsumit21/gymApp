import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../utils/back_navigation.dart';

// ─────────────────────────────────────────────
// Shell with Bottom Nav
// ─────────────────────────────────────────────
class HomeScreen extends StatelessWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  int _locationToIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/progress')) return 1;
    if (location.startsWith('/community')) return 0;
    return 0;
  }

  bool _showBottomNav(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return !location.startsWith('/workouts/custom');
  }

  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/workouts'); break;
      case 1: context.go('/progress'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _locationToIndex(context);

    return AppBackNavigation.shellScope(
      child: Scaffold(
      backgroundColor: AppTheme.background,
      body: child,
      bottomNavigationBar: _showBottomNav(context)
          ? Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.fitness_center_rounded,
                  label: 'Workouts',
                  selected: selectedIndex == 0,
                  onTap: () => _onTabTapped(context, 0),
                ),
                _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Progress',
                  selected: selectedIndex == 1,
                  onTap: () => _onTabTapped(context, 1),
                ),
              ],
            ),
          ),
        ),
      )
          : null,
    ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppTheme.primary : AppTheme.textMuted,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.primary : AppTheme.textMuted,
                fontSize: AppTheme.textCaption,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
