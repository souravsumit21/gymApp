import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../widgets/reppup_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _minSplashDuration = Duration(milliseconds: 900);

  bool _bootstrapDone = false;
  bool _navigated = false;
  late final DateTime _splashShownAt;

  @override
  void initState() {
    super.initState();
    _splashShownAt = DateTime.now();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    setState(() => _bootstrapDone = true);
    _onReadyToProceed();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (previous, next) {
      if (!next.isLoading) _onReadyToProceed();
    });

    final authState = ref.watch(authStateProvider);
    if (_bootstrapDone && !authState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onReadyToProceed());
    }

    return const Scaffold(
      backgroundColor: Colors.white,
      body: _SplashBranding(),
    );
  }

  Future<void> _onReadyToProceed() async {
    if (!mounted || !_bootstrapDone || _navigated) return;

    final authState = ref.read(authStateProvider);
    if (authState.isLoading) return;

    final elapsed = DateTime.now().difference(_splashShownAt);
    if (elapsed < _minSplashDuration) {
      await Future.delayed(_minSplashDuration - elapsed);
      if (!mounted || _navigated) return;
    }

    await _completeNavigation(authState.valueOrNull);
  }

  Future<void> _completeNavigation(User? user) async {
    if (_navigated || !mounted) return;
    _navigated = true;

    if (user == null) {
      context.go('/login');
      return;
    }

    final profile =
        await ref.read(authServiceProvider).loadUserProfile(user.uid);
    if (!mounted) return;

    if (profile?.onboardingComplete ?? false) {
      context.go('/workouts');
    } else {
      context.go('/onboarding');
    }
  }
}

class _SplashBranding extends StatelessWidget {
  const _SplashBranding();

  /// Matches the zoomed intro video footprint on a typical phone.
  static const _logoWidthFactor = 0.82;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ReppUpLogo(
        width: MediaQuery.sizeOf(context).width * _logoWidthFactor,
      ),
    );
  }
}
