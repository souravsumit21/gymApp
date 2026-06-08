import 'dart:io' show Platform;

import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';

const _revenueCatApiKeyAndroid = 'YOUR_REVENUECAT_ANDROID_KEY';
const _revenueCatApiKeyIOS = 'YOUR_REVENUECAT_IOS_KEY';

/// Product identifiers — must match App Store / Play Store
const kMonthlyEntitlement = 'forge_fit_premium';
const kMonthlyProductId = 'forge_fit_monthly';
const kAnnualProductId = 'forge_fit_annual';

class PurchaseService {
  static bool _isConfigured = false;

  static bool get isConfigured => _isConfigured;

  static bool get isAvailable {
    final key =
        Platform.isIOS ? _revenueCatApiKeyIOS : _revenueCatApiKeyAndroid;
    return key.isNotEmpty && !key.startsWith('YOUR_');
  }

  static Future<void> initialize(String userId) async {
    if (!isAvailable || userId.isEmpty) return;

    try {
      if (_isConfigured) {
        await Purchases.logIn(userId);
        return;
      }

      await Purchases.setLogLevel(LogLevel.debug);
      final config = PurchasesConfiguration(
        Platform.isIOS ? _revenueCatApiKeyIOS : _revenueCatApiKeyAndroid,
      );
      await Purchases.configure(config);
      await Purchases.logIn(userId);
      _isConfigured = true;
    } catch (_) {
      _isConfigured = false;
    }
  }

  Future<bool> get isPremium async {
    if (!_isConfigured) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(kMonthlyEntitlement);
    } catch (_) {
      return false;
    }
  }

  /// Returns available offerings
  Future<Offerings?> getOfferings() async {
    if (!_isConfigured) return null;
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  /// Purchase a specific package
  Future<bool> purchase(Package package) async {
    if (!_isConfigured) return false;
    try {
      final result = await Purchases.purchasePackage(package);
      return result.customerInfo.entitlements.active
          .containsKey(kMonthlyEntitlement);
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  /// Restore purchases
  Future<bool> restore() async {
    if (!_isConfigured) return false;
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(kMonthlyEntitlement);
    } catch (_) {
      return false;
    }
  }
}

final purchaseServiceProvider =
    Provider<PurchaseService>((ref) => PurchaseService());

final premiumStatusProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return false;

  await PurchaseService.initialize(user.uid);
  return ref.watch(purchaseServiceProvider).isPremium;
});
