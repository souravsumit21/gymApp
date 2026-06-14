import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Centralized Android/iOS back handling — never exits the app from a root tab.
class AppBackNavigation {
  AppBackNavigation._();

  /// Pops the route stack or navigates to a sensible parent. Does not exit the app.
  static void navigateBack(BuildContext context, {String? fallback}) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    if (fallback != null) {
      router.go(fallback);
      return;
    }
    final parent = _parentPath(GoRouterState.of(context).matchedLocation);
    if (parent != null) {
      router.go(parent);
    }
  }

  static String? _parentPath(String location) {
    if (location.startsWith('/workouts/') && location != '/workouts') {
      return '/workouts';
    }
    if (location.startsWith('/community/') && location != '/community') {
      return '/community';
    }
    if (location == '/notifications' ||
        location.startsWith('/share/') ||
        location.startsWith('/w/') ||
        location == '/paywall') {
      return '/workouts';
    }
    return null;
  }

  /// Absorbs back at shell roots instead of closing the app.
  static Widget shellScope({required Widget child}) {
    return Builder(
      builder: (context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          navigateBack(context);
        },
        child: child,
      ),
    );
  }

  /// Workout screens. Circuit: first back pauses, second back leaves.
  /// Standard: each back steps to the previous in-workout screen (no pause).
  static Widget workoutScope({
    required Widget child,
    required bool isActiveSession,
    required VoidCallback onBack,
    bool pauseBeforeLeave = true,
    bool isPaused = false,
    VoidCallback? onPause,
  }) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!isActiveSession) {
          onBack();
          return;
        }
        if (!pauseBeforeLeave) {
          onBack();
          return;
        }
        if (isPaused) {
          onBack();
          return;
        }
        onPause?.call();
      },
      child: child,
    );
  }
}
