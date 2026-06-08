import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'share_config.dart';

/// Listens for incoming deep links and navigates to the appropriate route.
class DeepLinkHandler {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  void startListening(GoRouter router) {
    _subscription?.cancel();
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleUri(router, uri),
      onError: (_) {},
    );
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(router, uri);
    });
  }

  void dispose() {
    _subscription?.cancel();
  }

  void _handleUri(GoRouter router, Uri uri) {
    final path = uri.path;
    if (path.startsWith('/w/')) {
      final shareId = path.replaceFirst('/w/', '').split('/').first;
      if (shareId.isNotEmpty) {
        router.go('/w/$shareId');
      }
      return;
    }
    if (path.startsWith('/c/')) {
      final workoutId = path.replaceFirst('/c/', '').split('/').first;
      if (workoutId.isNotEmpty) {
        router.go('/community/$workoutId');
      }
      return;
    }
    final deepLinkHost = Uri.parse(ShareConfig.deepLinkBase).host;
    if (uri.host == deepLinkHost && uri.pathSegments.isNotEmpty) {
      final first = uri.pathSegments.first;
      if (first == 'w' && uri.pathSegments.length >= 2) {
        router.go('/w/${uri.pathSegments[1]}');
      } else if (first == 'c' && uri.pathSegments.length >= 2) {
        router.go('/community/${uri.pathSegments[1]}');
      }
    }
  }
}

/// Opens app store when a deep link is accessed without the app installed.
void openAppStoreFallback() {
  // Placeholder — platform-specific store redirect handled by universal links.
  debugPrint('Install ${ShareConfig.appName}: ${ShareConfig.appStoreUrl}');
}
