import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/exercise_media.dart';
import '../theme/app_theme.dart';

bool isVideoUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final lower = url.toLowerCase();
  return lower.contains('.mp4') ||
      lower.contains('.mov') ||
      lower.contains('.webm') ||
      lower.contains('.m3u8');
}

bool isImageUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  if (isVideoUrl(url)) return false;
  final lower = url.toLowerCase();
  return lower.contains('.gif') ||
      lower.contains('.jpg') ||
      lower.contains('.jpeg') ||
      lower.contains('.png') ||
      lower.contains('.webp');
}

/// Resolve playable/displayable media for a workout row or saved exercise entry.
ExerciseMedia? resolveExerciseMedia({
  required String exerciseId,
  ExerciseMedia? libraryMedia,
  String? savedThumbnailUrl,
}) {
  if (libraryMedia != null &&
      (libraryMedia.videoUrl != null ||
          libraryMedia.gifUrl != null ||
          libraryMedia.thumbnailUrl != null)) {
    return libraryMedia;
  }
  if (savedThumbnailUrl == null || savedThumbnailUrl.isEmpty) return null;
  if (isVideoUrl(savedThumbnailUrl)) {
    return ExerciseMedia(
      exerciseId: exerciseId,
      primaryType: MediaType.video,
      videoUrl: savedThumbnailUrl,
    );
  }
  return ExerciseMedia(
    exerciseId: exerciseId,
    primaryType: MediaType.image,
    thumbnailUrl: savedThumbnailUrl,
    gifUrl: isImageUrl(savedThumbnailUrl) && savedThumbnailUrl.contains('.gif')
        ? savedThumbnailUrl
        : null,
  );
}

/// Subtle blur for upcoming-exercise previews during rest; animates to sharp.
class AnimatedMediaBlur extends StatefulWidget {
  const AnimatedMediaBlur({
    super.key,
    required this.sigma,
    required this.child,
    this.duration = const Duration(milliseconds: 450),
  });

  final double sigma;
  final Widget child;
  final Duration duration;

  @override
  State<AnimatedMediaBlur> createState() => _AnimatedMediaBlurState();
}

class _AnimatedMediaBlurState extends State<AnimatedMediaBlur>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _sigmaAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _sigmaAnimation = _tween(widget.sigma, widget.sigma);
    _controller.value = 1;
  }

  Animation<double> _tween(double begin, double end) {
    return Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedMediaBlur oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sigma == widget.sigma) return;
    _sigmaAnimation = _tween(_sigmaAnimation.value, widget.sigma);
    _controller
      ..duration = widget.duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sigmaAnimation,
      builder: (context, child) {
        final sigma = _sigmaAnimation.value;
        if (sigma < 0.5) return child!;
        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class ExerciseMediaWidget extends StatefulWidget {
  final ExerciseMedia? media;
  final BoxFit fit;
  final bool loopVideo;
  final bool autoplayVideo;
  /// Scales video past the frame before cropping — useful during workouts.
  final double videoZoom;
  final Widget? placeholder;

  const ExerciseMediaWidget({
    super.key,
    required this.media,
    this.fit = BoxFit.cover,
    this.loopVideo = true,
    this.autoplayVideo = true,
    this.videoZoom = 1.0,
    this.placeholder,
  });

  @override
  State<ExerciseMediaWidget> createState() => _ExerciseMediaWidgetState();
}

class _ExerciseMediaWidgetState extends State<ExerciseMediaWidget> {
  VideoPlayerController? _controller;
  bool _videoFailed = false;
  bool _initializing = false;

  String? get _videoUrl {
    final media = widget.media;
    if (media == null) return null;
    if (media.videoUrl != null && media.videoUrl!.isNotEmpty) {
      return media.videoUrl;
    }
    if (isVideoUrl(media.gifUrl)) return media.gifUrl;
    if (isVideoUrl(media.thumbnailUrl)) return media.thumbnailUrl;
    return null;
  }

  bool get _isVideo => _videoUrl != null;

  String? get _imageUrl {
    final media = widget.media;
    if (media == null) return null;
    for (final candidate in [media.gifUrl, media.thumbnailUrl]) {
      if (candidate != null && candidate.isNotEmpty && isImageUrl(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(covariant ExerciseMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUrl = _videoUrlFor(oldWidget.media);
    final newUrl = _videoUrl;
    if (oldUrl != newUrl ||
        oldWidget.autoplayVideo != widget.autoplayVideo ||
        oldWidget.media?.primaryType != widget.media?.primaryType) {
      _disposeController();
      _videoFailed = false;
      _initVideo();
    }
  }

  String? _videoUrlFor(ExerciseMedia? media) {
    if (media == null) return null;
    if (media.videoUrl != null && media.videoUrl!.isNotEmpty) {
      return media.videoUrl;
    }
    if (isVideoUrl(media.gifUrl)) return media.gifUrl;
    if (isVideoUrl(media.thumbnailUrl)) return media.thumbnailUrl;
    return null;
  }

  Future<void> _initVideo() async {
    if (!_isVideo || _videoFailed || _initializing) return;
    final url = _videoUrl;
    if (url == null) return;

    _initializing = true;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) return;
      controller.addListener(_onVideoTick);
      await controller.setLooping(widget.loopVideo);
      if (widget.autoplayVideo) {
        await controller.play();
      } else {
        await controller.pause();
      }
      setState(() {});
    } catch (error, stack) {
      debugPrint('ExerciseMediaWidget: failed to load $url — $error');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      setState(() => _videoFailed = true);
      _disposeController();
    } finally {
      _initializing = false;
    }
  }

  void _onVideoTick() {
    if (!mounted) return;
    setState(() {});
  }

  void _disposeController() {
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Widget _defaultPlaceholder() {
    return Container(
      color: AppTheme.surfaceElevated,
      child: const Center(
        child: Icon(
          Icons.fitness_center_rounded,
          color: AppTheme.textMuted,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildVideo(VideoPlayerController controller) {
    final size = controller.value.size;
    final width = size.width > 0 ? size.width : 16;
    final height = size.height > 0 ? size.height : 9;
    final zoom = widget.videoZoom.clamp(1.0, 1.5);

    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: ClipRect(
          child: FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.center,
            child: SizedBox(
              width: width * zoom,
              height: height * zoom,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _retryVideo() async {
    setState(() => _videoFailed = false);
    await _initVideo();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.placeholder ?? _defaultPlaceholder();

    if (_isVideo && !_videoFailed) {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        return _buildVideo(controller);
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          placeholder,
          if (!widget.autoplayVideo)
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white70,
                size: 40,
              ),
            ),
        ],
      );
    }

    if (_isVideo && _videoFailed) {
      return Stack(
        fit: StackFit.expand,
        children: [
          placeholder,
          Center(
            child: TextButton.icon(
              onPressed: _retryVideo,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
              label: const Text(
                'Retry video',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      );
    }

    final imageUrl = _imageUrl;
    if (imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: widget.fit,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      );
    }

    return placeholder;
  }
}
