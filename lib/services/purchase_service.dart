import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/revenue_cat_config.dart';
import '../models/premium_status.dart';

/// Thin wrapper around the RevenueCat SDK.
class PurchaseService {
  bool _isConfigured = false;
  String? _activeUserId;
  CustomerInfoUpdateListener? _customerInfoListener;

  bool get isConfigured => _isConfigured;

  Future<void> configure(String userId) async {
    if (!RevenueCatConfig.hasApiKeys || userId.isEmpty) {
      _isConfigured = false;
      return;
    }

    try {
      if (_isConfigured) {
        if (_activeUserId != userId) {
          await Purchases.logIn(userId);
          _activeUserId = userId;
        }
        return;
      }

      if (RevenueCatConfig.isDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      final config = PurchasesConfiguration(RevenueCatConfig.platformApiKey);
      await Purchases.configure(config);
      await Purchases.logIn(userId);

      _isConfigured = true;
      _activeUserId = userId;
    } catch (error, stackTrace) {
      _isConfigured = false;
      debugPrint('RevenueCat configure failed: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> logOut() async {
    _removeCustomerInfoListener();
    _isConfigured = false;
    _activeUserId = null;

    if (!RevenueCatConfig.hasApiKeys) return;

    try {
      await Purchases.logOut();
    } catch (error) {
      debugPrint('RevenueCat logOut failed: $error');
    }
  }

  void listenToCustomerInfo(void Function(CustomerInfo info) onUpdate) {
    _removeCustomerInfoListener();
    _customerInfoListener = onUpdate;
    Purchases.addCustomerInfoUpdateListener(onUpdate);
  }

  void _removeCustomerInfoListener() {
    final listener = _customerInfoListener;
    if (listener != null) {
      Purchases.removeCustomerInfoUpdateListener(listener);
      _customerInfoListener = null;
    }
  }

  void dispose() => _removeCustomerInfoListener();

  bool hasPremiumEntitlement(CustomerInfo info) {
    return info.entitlements.active
        .containsKey(RevenueCatConfig.entitlementId);
  }

  Future<CustomerInfo> getCustomerInfo() async {
    _ensureConfigured();
    return Purchases.getCustomerInfo();
  }

  Future<Offerings?> getOfferings() async {
    if (!_isConfigured) return null;
    try {
      return await Purchases.getOfferings();
    } catch (error) {
      debugPrint('RevenueCat getOfferings failed: $error');
      return null;
    }
  }

  Future<CustomerInfo> purchase(Package package) async {
    _ensureConfigured();
    try {
      final result = await Purchases.purchasePackage(package);
      return result.customerInfo;
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    }
  }

  Future<CustomerInfo> restore() async {
    _ensureConfigured();
    try {
      return await Purchases.restorePurchases();
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    }
  }

  void _ensureConfigured() {
    if (!_isConfigured) {
      throw PurchaseException(
        RevenueCatConfig.hasApiKeys
            ? 'RevenueCat is not initialized yet.'
            : 'RevenueCat API keys are not configured.',
      );
    }
  }

  PurchaseException _mapPlatformException(PlatformException error) {
    final code = PurchasesErrorHelper.getErrorCode(error);
    return PurchaseException(
      error.message ?? 'Purchase failed.',
      code: code,
    );
  }
}
