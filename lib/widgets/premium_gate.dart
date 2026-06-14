import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/revenue_cat_config.dart';
import '../providers/premium_providers.dart';
import '../theme/app_theme.dart';

/// Wraps premium-only content. Shows [locked] when the user lacks access.
class PremiumGate extends ConsumerWidget {
  const PremiumGate({
    super.key,
    required this.feature,
    required this.child,
    required this.locked,
  });

  final PremiumFeature feature;
  final Widget child;
  final Widget locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccess = ref.watch(premiumFeatureAccessProvider(feature));
    return hasAccess ? child : locked;
  }
}

class PremiumLockedCard extends StatelessWidget {
  const PremiumLockedCard({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.lock_outline,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                child: Icon(icon, color: AppTheme.accentYellow),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/paywall'),
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: const Text('Unlock Premium'),
            ),
          ),
        ],
      ),
    );
  }
}
