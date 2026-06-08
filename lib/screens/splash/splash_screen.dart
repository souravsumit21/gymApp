import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../services/auth_service.dart';
import '../../utils/launch_prefs.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _videoAsset = 'assets/animations/reppup_splash.mp4';

  VideoPlayerController? _controller;
  bool _bootstrapDone = false;
  bool _introSeen = true;
  bool _videoFinished = false;
  bool _videoStarted = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final introSeen = await LaunchPrefs.hasSeenIntroVideo();
    if (!mounted) return;
    setState(() {
      _bootstrapDone = true;
      _introSeen = introSeen;
      if (introSeen) _videoFinished = true;
    });
    _onReadyToProceed();
  }

  Future<void> _maybeStartIntroVideo() async {
    if (_videoStarted || _introSeen || _videoFinished) return;
    _videoStarted = true;

    final controller = VideoPlayerController.asset(_videoAsset);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;

      controller.setLooping(false);
      controller.setVolume(0);
      await controller.seekTo(Duration.zero);

      setState(() {});
      controller.addListener(_onVideoProgress);
      await controller.play();
    } catch (_) {
      _videoFinished = true;
      await LaunchPrefs.markIntroVideoSeen();
      if (mounted) setState(() => _introSeen = true);
      _onReadyToProceed();
    }
  }

  void _onVideoProgress() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _videoFinished) {
      return;
    }

    final position = controller.value.position;
    final duration = controller.value.duration;
    if (duration <= Duration.zero) return;

    if (position >= duration - const Duration(milliseconds: 50)) {
      _videoFinished = true;
      controller.removeListener(_onVideoProgress);
      controller.pause();
      LaunchPrefs.markIntroVideoSeen();
      if (mounted) setState(() => _introSeen = true);
      _onReadyToProceed();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoProgress);
    _controller?.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildBody(authState),
    );
  }

  Widget _buildBody(AsyncValue<User?> authState) {
    if (!_bootstrapDone) {
      return const SizedBox.expand();
    }

    final user = authState.valueOrNull;
    if (user != null || _introSeen) {
      return const SizedBox.expand();
    }

    if (_controller?.value.isInitialized == true) {
      return _CenteredVideo(controller: _controller!);
    }

    return const SizedBox.expand();
  }

  void _onReadyToProceed() {
    if (!mounted || !_bootstrapDone || _navigated) return;

    final authState = ref.read(authStateProvider);
    if (authState.isLoading) return;

    final user = authState.valueOrNull;

    if (user != null) {
      _completeNavigation(user);
      return;
    }

    if (!_introSeen && !_videoStarted) {
      _maybeStartIntroVideo();
      return;
    }

    if (!_videoFinished) return;

    _completeNavigation(null);
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

class _CenteredVideo extends StatelessWidget {
  const _CenteredVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}
