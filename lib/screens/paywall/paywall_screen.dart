import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../config/revenue_cat_config.dart';
import '../../providers/premium_providers.dart';
import '../../theme/app_theme.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Package? _selectedPackage;
  bool _isPurchasing = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(premiumNotifierProvider.notifier).loadOfferings();
    });
  }

  void _leavePaywall() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/workouts');
  }

  Future<void> _purchase() async {
    if (_selectedPackage == null) return;
    setState(() => _isPurchasing = true);
    final success =
        await ref.read(premiumNotifierProvider.notifier).purchase(_selectedPackage!);
    if (!mounted) return;
    setState(() => _isPurchasing = false);
    if (success) _leavePaywall();
  }

  Future<void> _restore() async {
    setState(() => _isRestoring = true);
    final restored = await ref.read(premiumNotifierProvider.notifier).restore();
    if (!mounted) return;
    setState(() => _isRestoring = false);
    if (restored) _leavePaywall();
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(premiumNotifierProvider);
    final annualPackage = premium.annualPackage;
    final monthlyPackage = premium.monthlyPackage;

    _selectedPackage ??= annualPackage ?? monthlyPackage;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned(
            top: -150,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Spacer(),
                      IconButton(
                        onPressed: _leavePaywall,
                        icon:
                            const Icon(Icons.close, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: AppGradients.primaryGlow,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.bolt_rounded,
                              color: AppTheme.background, size: 46),
                        ).animate().scale(
                              duration: 600.ms,
                              curve: Curves.elasticOut,
                            ),
                        const SizedBox(height: 24),
                        Text(
                          'REPP UP PRO',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: AppTheme.primary,
                                letterSpacing: 3,
                              ),
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 8),
                        Text(
                          'Unlock your full training toolkit',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                        ).animate().fadeIn(delay: 300.ms),
                        const SizedBox(height: 36),
                        for (final feature in [
                          (
                            '⚡',
                            'AI Workout Plans',
                            'Personalized multi-day plans for your goals'
                          ),
                          (
                            '🏋️',
                            'Custom Workouts',
                            'Build unlimited workouts with your equipment'
                          ),
                          (
                            '📊',
                            'Progress Tracking',
                            'Streaks, charts, and milestone badges'
                          ),
                          (
                            '🌐',
                            'Community Sharing',
                            'Share and discover workouts with others'
                          ),
                        ])
                          _FeatureRow(
                            icon: feature.$1,
                            title: feature.$2,
                            subtitle: feature.$3,
                          ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
                        const SizedBox(height: 32),
                        if (!RevenueCatConfig.hasApiKeys)
                          _ConfigNotice()
                        else if (premium.isLoadingOfferings)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primary,
                              ),
                            ),
                          )
                        else if (annualPackage != null ||
                            monthlyPackage != null) ...[
                          Text(
                            'Choose your plan',
                            style:
                                Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                          ),
                          const SizedBox(height: 12),
                          if (annualPackage != null)
                            _PlanCard(
                              package: annualPackage,
                              isSelected: _selectedPackage?.identifier ==
                                  annualPackage.identifier,
                              badge: 'BEST VALUE',
                              onTap: () => setState(
                                () => _selectedPackage = annualPackage,
                              ),
                            ),
                          const SizedBox(height: 10),
                          if (monthlyPackage != null)
                            _PlanCard(
                              package: monthlyPackage,
                              isSelected: _selectedPackage?.identifier ==
                                  monthlyPackage.identifier,
                              onTap: () => setState(
                                () => _selectedPackage = monthlyPackage,
                              ),
                            ),
                        ] else
                          Column(
                            children: [
                              _SkeletonCard(),
                              const SizedBox(height: 10),
                              _SkeletonCard(),
                            ],
                          ),
                        if (premium.lastError != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.accent.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              premium.lastError!,
                              style: TextStyle(
                                color: AppTheme.accent,
                                fontSize: AppTheme.textCaption,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: _isPurchasing ||
                                !RevenueCatConfig.hasApiKeys ||
                                _selectedPackage == null
                            ? null
                            : _purchase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.background,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isPurchasing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: AppTheme.background,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'Subscribe',
                                style: TextStyle(
                                  fontSize: AppTheme.textBody,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isRestoring || !RevenueCatConfig.hasApiKeys
                            ? null
                            : _restore,
                        child: Text(
                          _isRestoring
                              ? 'Restoring...'
                              : 'Restore Purchase',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: AppTheme.textCaption,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cancel anytime. Billed through App Store / Google Play.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        'RevenueCat is not configured yet. Add API keys via --dart-define to load offerings and enable purchases.',
        style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child:
                Center(child: Text(icon, style: TextStyle(fontSize: AppTheme.textIcon))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: AppTheme.textBody,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: AppTheme.textLabel,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded,
              color: AppTheme.primary, size: 18),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Package package;
  final bool isSelected;
  final String? badge;
  final VoidCallback onTap;

  const _PlanCard({
    required this.package,
    required this.isSelected,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.1)
              : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                  width: 2,
                ),
                color: isSelected ? AppTheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: AppTheme.background, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        package.storeProduct.title,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: AppTheme.textBody,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              color: AppTheme.background,
                              fontSize: AppTheme.textCaption,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    package.storeProduct.description,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: AppTheme.textLabel,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              package.storeProduct.priceString,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: AppTheme.textBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
