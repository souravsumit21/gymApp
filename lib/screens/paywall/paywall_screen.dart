import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/purchase_service.dart';
import '../../theme/app_theme.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isLoading = false;
  bool _isRestoring = false;
  Offerings? _offerings;
  Package? _selectedPackage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) {
      await PurchaseService.initialize(uid);
    }
    final svc = ref.read(purchaseServiceProvider);
    if (!PurchaseService.isConfigured) {
      setState(() {
        _error = 'Purchases are not configured yet.';
      });
      return;
    }
    final offerings = await svc.getOfferings();
    setState(() {
      _offerings = offerings;
      // Default to annual if available
      _selectedPackage = offerings?.current?.annual ?? offerings?.current?.monthly;
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
    setState(() { _isLoading = true; _error = null; });
    try {
      final svc = ref.read(purchaseServiceProvider);
      final success = await svc.purchase(_selectedPackage!);
      if (!mounted) return;
      if (success) {
        _leavePaywall();
      } else {
        setState(() => _error = 'Purchase was cancelled.');
      }
    } catch (e) {
      setState(() => _error = 'Purchase failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restore() async {
    setState(() { _isRestoring = true; _error = null; });
    try {
      final svc = ref.read(purchaseServiceProvider);
      final restored = await svc.restore();
      if (!mounted) return;
      if (restored) {
        _leavePaywall();
      } else {
        setState(() => _error = 'No active subscription found.');
      }
    } catch (e) {
      setState(() => _error = 'Restore failed.');
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final annualPackage = _offerings?.current?.annual;
    final monthlyPackage = _offerings?.current?.monthly;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background glow
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
                // Close button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Spacer(),
                      IconButton(
                        onPressed: _leavePaywall,
                        icon: const Icon(Icons.close, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Crown icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: AppGradients.primaryGlow,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.bolt_rounded,
                              color: AppTheme.background, size: 46),
                        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

                        const SizedBox(height: 24),

                        Text(
                          'FORGE PRO',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: AppTheme.primary,
                            letterSpacing: 3,
                          ),
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 8),

                        Text(
                          'Unlock your full potential',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ).animate().fadeIn(delay: 300.ms),

                        const SizedBox(height: 36),

                        // Feature list
                        for (final feature in [
                          ('⚡', 'AI-Powered Workout Plans', 'Custom plans built by Claude AI for your exact goals'),
                          ('🎯', 'Body Part Targeting', 'Isolate and train specific muscle groups'),
                          ('📅', 'Weekly Schedules', 'Plan your full week with rest days'),
                          ('📊', 'Progress Tracking', 'Calendar, streaks, and performance charts'),
                          ('♾️', 'Unlimited Plans', 'Create and save as many plans as you need'),
                        ])
                          _FeatureRow(
                            icon: feature.$1,
                            title: feature.$2,
                            subtitle: feature.$3,
                          ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),

                        const SizedBox(height: 32),

                        // Plan selector
                        if (annualPackage != null || monthlyPackage != null) ...[
                          Text('Choose your plan',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppTheme.textSecondary,
                              )),
                          const SizedBox(height: 12),

                          if (annualPackage != null)
                            _PlanCard(
                              package: annualPackage,
                              isSelected: _selectedPackage?.identifier ==
                                  annualPackage.identifier,
                              badge: 'BEST VALUE',
                              onTap: () =>
                                  setState(() => _selectedPackage = annualPackage),
                            ),

                          const SizedBox(height: 10),

                          if (monthlyPackage != null)
                            _PlanCard(
                              package: monthlyPackage,
                              isSelected: _selectedPackage?.identifier ==
                                  monthlyPackage.identifier,
                              onTap: () =>
                                  setState(() => _selectedPackage = monthlyPackage),
                            ),
                        ] else
                          // Skeleton while loading
                          Column(
                            children: [
                              _SkeletonCard(),
                              const SizedBox(height: 10),
                              _SkeletonCard(),
                            ],
                          ),

                        const SizedBox(height: 24),

                        // Error
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                            ),
                            child: Text(_error!,
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 13,
                                )),
                          ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // Bottom CTA
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: _isLoading ? null : _purchase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.background,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: AppTheme.background,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Start Free Trial',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isRestoring ? null : _restore,
                        child: Text(
                          _isRestoring ? 'Restoring...' : 'Restore Purchase',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
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
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    )),
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
                          fontSize: 15,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: AppTheme.background,
                              fontSize: 9,
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
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
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
                fontSize: 16,
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
