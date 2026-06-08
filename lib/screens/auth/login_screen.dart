import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/open_web_page.dart';
import '../../utils/share_config.dart';
import '../../widgets/reppup_logo.dart';

const _ink = Color(0xFF2C2C2A);
const _bodyGray = Color(0xFF555555);
const _termsGray = Color(0xFFBBBBBB);
const _iconGray = Color(0xFFB8B8B8);
const _btnBorder = Color(0xFFE5E5E5);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  String? _error;
  late final TapGestureRecognizer _termsTapRecognizer;
  late final TapGestureRecognizer _privacyTapRecognizer;

  @override
  void initState() {
    super.initState();
    _termsTapRecognizer = TapGestureRecognizer()
      ..onTap = () => openWebPage(
            context,
            url: ShareConfig.termsUrl,
            title: 'Terms',
          );
    _privacyTapRecognizer = TapGestureRecognizer()
      ..onTap = () => openWebPage(
            context,
            url: ShareConfig.privacyUrl,
            title: 'Privacy Policy',
          );
  }

  @override
  void dispose() {
    _termsTapRecognizer.dispose();
    _privacyTapRecognizer.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      final profile = await authService.signInWithGoogle();
      if (!mounted) return;
      if (profile == null) return;

      if (!profile.onboardingComplete) {
        context.go('/onboarding');
      } else {
        context.go('/workouts');
      }
    } catch (e) {
      if (!mounted) return;
      // Auth may have succeeded even if profile sync failed.
      if (ref.read(authServiceProvider).currentUser != null) return;
      setState(() {
        _error = 'Sign-in failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFAFAFA),
              Color(0xFFFFF5EE),
              Color(0xFFFFE8D6),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 44),
                Center(
                  child: ReppUpLogo(
                    width: MediaQuery.of(context).size.width * 0.55,
                  )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: -0.06, end: 0),
                ),
                const SizedBox(height: 40),
                _FeatureBullet(
                  delay: 200,
                  iconAsset: _LoginIcons.dumbbell,
                  text: 'Your equipment. Your exercises. Your workout.',
                ),
                const SizedBox(height: 22),
                _FeatureBullet(
                  delay: 280,
                  iconAsset: _LoginIcons.chart,
                  text: 'Log every rep and track your progress',
                ),
                const SizedBox(height: 22),
                _FeatureBullet(
                  delay: 360,
                  iconAsset: _LoginIcons.community,
                  text: 'Share and discover workouts with the community',
                ),
                const SizedBox(height: 22),
                _FeatureBullet(
                  delay: 440,
                  iconAsset: _LoginIcons.flame,
                  iconSize: 26,
                  text: 'Build streaks that keep you coming back',
                ),
                const Spacer(),
                Text(
                  'Sign in to get started',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ).animate().fadeIn(delay: 500.ms, duration: 450.ms),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.accent.withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppTheme.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.onest(
                              color: AppTheme.accent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _GoogleSignInButton(
                  isLoading: _isLoading,
                  onTap: _handleGoogleSignIn,
                )
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 500.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    style: GoogleFonts.onest(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: _termsGray,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(
                        text: 'By continuing, you agree to our ',
                      ),
                      TextSpan(
                        text: 'Terms',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          decorationColor: _termsGray,
                        ),
                        recognizer: _termsTapRecognizer,
                      ),
                      const TextSpan(text: ' & '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          decorationColor: _termsGray,
                        ),
                        recognizer: _privacyTapRecognizer,
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 750.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginIcons {
  static const dumbbell = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M6 4v16" stroke="currentColor" stroke-width="1.75" stroke-linecap="round"/>
  <path d="M18 4v16" stroke="currentColor" stroke-width="1.75" stroke-linecap="round"/>
  <path d="M6 12h12" stroke="currentColor" stroke-width="1.75" stroke-linecap="round"/>
  <path d="M3 8v8" stroke="currentColor" stroke-width="1.75" stroke-linecap="round"/>
  <path d="M21 8v8" stroke="currentColor" stroke-width="1.75" stroke-linecap="round"/>
</svg>''';

  static const chart = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M3 3v18h18" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M7 16l4-6 4 4 5-8" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

  static const community = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="9" cy="7" r="4" stroke="currentColor" stroke-width="1.75"/>
  <path d="M22 21v-2a4 4 0 0 0-3-3.87" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M16 3.13a4 4 0 0 1 0 7.75" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

  static const flame = '''
<svg viewBox="5.5 0.5 13 17.5" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 2c1 3 2.5 3.5 3.5 4.5A5 5 0 0 1 17 10a5 5 0 0 1-10 0c0-1.5.5-2 1-3" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M12 14a2.5 2.5 0 0 0 2.5-2.5c0-1.5-2.5-3.5-2.5-3.5s-2.5 2-2.5 3.5A2.5 2.5 0 0 0 12 14z" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({
    required this.iconAsset,
    required this.text,
    required this.delay,
    this.iconSize = 22,
  });

  final String iconAsset;
  final String text;
  final int delay;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: SvgPicture.string(
              iconAsset,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              colorFilter: const ColorFilter.mode(_iconGray, BlendMode.srcIn),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: GoogleFonts.onest(
                fontSize: 14.5,
                fontWeight: FontWeight.w400,
                color: _bodyGray,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: delay.ms, duration: 450.ms)
        .slideX(begin: -0.03, end: 0, curve: Curves.easeOut);
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.isLoading,
    required this.onTap,
  });

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _btnBorder, width: 1.5),
          ),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      child: Text(
                        'G',
                        style: GoogleFonts.onest(
                          color: const Color(0xFF4285F4),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Google',
                      style: GoogleFonts.onest(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
