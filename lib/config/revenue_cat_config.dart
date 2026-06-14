import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// RevenueCat + store configuration.
///
/// API keys are injected at build time via `--dart-define` or `.env.local`:
/// - Test Store (dev): `REVENUECAT_API_KEY=test_xxx` — works on iOS + Android
/// - Production: `REVENUECAT_ANDROID_KEY=goog_xxx` / `REVENUECAT_IOS_KEY=appl_xxx`
class RevenueCatConfig {
  RevenueCatConfig._();

  /// RevenueCat Test Store key (`test_...`) — single key for both platforms.
  static const unifiedApiKey = String.fromEnvironment('REVENUECAT_API_KEY');

  static const androidApiKey = String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static const iosApiKey = String.fromEnvironment('REVENUECAT_IOS_KEY');

  /// RevenueCat entitlement identifier.
  static const entitlementId = 'repp_up_premium';

  /// Default offering identifier in the RevenueCat dashboard.
  static const defaultOfferingId = 'default';

  /// Store product identifiers — must match App Store Connect / Play Console.
  static const monthlyProductId = 'repp_up_monthly';
  static const annualProductId = 'repp_up_annual';

  /// Feature gates — flip [gateCustomWorkouts] before launch.
  static const gateAiWorkoutPlans = true;
  static const gateCustomWorkouts = false;

  static String get platformApiKey {
    final platformKey = Platform.isIOS ? iosApiKey : androidApiKey;
    if (_isValidKey(platformKey)) return platformKey;
    if (_isValidKey(unifiedApiKey)) return unifiedApiKey;
    return '';
  }

  static bool get hasApiKeys => _isValidKey(platformApiKey);

  static bool get usesTestStore => platformApiKey.startsWith('test_');

  static bool _isValidKey(String key) =>
      key.isNotEmpty && !key.startsWith('YOUR_');

  static bool get isDebugMode => !kReleaseMode;

  static bool canAccessFeature(PremiumFeature feature, {required bool isPremium}) {
    if (!isPremium) {
      switch (feature) {
        case PremiumFeature.aiWorkoutPlans:
          return !gateAiWorkoutPlans;
        case PremiumFeature.customWorkouts:
          return !gateCustomWorkouts;
      }
    }
    return true;
  }
}

enum PremiumFeature {
  aiWorkoutPlans,
  customWorkouts,
}
