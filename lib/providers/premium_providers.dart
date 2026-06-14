import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/revenue_cat_config.dart';
import '../models/premium_status.dart';
import '../services/auth_service.dart';
import '../services/purchase_service.dart';

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = PurchaseService();
  ref.onDispose(service.dispose);
  return service;
});

class PremiumNotifier extends Notifier<PremiumStatus> {
  @override
  PremiumStatus build() {
    ref.onDispose(() {
      ref.read(purchaseServiceProvider).dispose();
    });

    ref.listen<AsyncValue<User?>>(authStateProvider, (_, next) {
      _handleAuthChange(next.valueOrNull?.uid);
    }, fireImmediately: true);

    return const PremiumStatus();
  }

  Future<void> _handleAuthChange(String? uid) async {
    final service = ref.read(purchaseServiceProvider);

    if (uid == null || uid.isEmpty) {
      await service.logOut();
      state = const PremiumStatus();
      return;
    }

    if (!RevenueCatConfig.hasApiKeys) {
      state = const PremiumStatus(
        isConfigured: false,
        isPremium: false,
      );
      return;
    }

    await service.configure(uid);
    service.listenToCustomerInfo(_onCustomerInfoUpdated);

    try {
      final info = await service.getCustomerInfo();
      _onCustomerInfoUpdated(info);
    } catch (error) {
      state = state.copyWith(
        isConfigured: service.isConfigured,
        lastError: error.toString(),
      );
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    final service = ref.read(purchaseServiceProvider);
    state = state.copyWith(
      isConfigured: service.isConfigured,
      isPremium: service.hasPremiumEntitlement(info),
      customerInfo: info,
      clearError: true,
    );
  }

  Future<void> loadOfferings() async {
    final service = ref.read(purchaseServiceProvider);
    if (!service.isConfigured) {
      state = state.copyWith(
        lastError: RevenueCatConfig.hasApiKeys
            ? 'Purchases are not configured yet.'
            : 'Add RevenueCat API keys via --dart-define.',
      );
      return;
    }

    state = state.copyWith(isLoadingOfferings: true, clearError: true);
    final offerings = await service.getOfferings();
    state = state.copyWith(
      offerings: offerings,
      isLoadingOfferings: false,
      lastError: offerings == null ? 'No offerings available.' : null,
      clearError: offerings != null,
    );
  }

  Future<bool> purchase(Package package) async {
    final service = ref.read(purchaseServiceProvider);
    state = state.copyWith(clearError: true);
    try {
      final info = await service.purchase(package);
      _onCustomerInfoUpdated(info);
      return service.hasPremiumEntitlement(info);
    } on PurchaseException catch (error) {
      if (!error.isCancelled) {
        state = state.copyWith(lastError: error.message);
      }
      return false;
    } catch (error) {
      state = state.copyWith(lastError: error.toString());
      return false;
    }
  }

  Future<bool> restore() async {
    final service = ref.read(purchaseServiceProvider);
    state = state.copyWith(clearError: true);
    try {
      final info = await service.restore();
      _onCustomerInfoUpdated(info);
      final restored = service.hasPremiumEntitlement(info);
      if (!restored) {
        state = state.copyWith(lastError: 'No active subscription found.');
      }
      return restored;
    } on PurchaseException catch (error) {
      state = state.copyWith(lastError: error.message);
      return false;
    } catch (error) {
      state = state.copyWith(lastError: error.toString());
      return false;
    }
  }
}

final premiumNotifierProvider =
    NotifierProvider<PremiumNotifier, PremiumStatus>(PremiumNotifier.new);

/// Simple premium bool for feature gates.
final premiumStatusProvider = Provider<bool>((ref) {
  return ref.watch(premiumNotifierProvider).isPremium;
});

final premiumConfiguredProvider = Provider<bool>((ref) {
  return ref.watch(premiumNotifierProvider).isConfigured;
});

final premiumFeatureAccessProvider =
    Provider.family<bool, PremiumFeature>((ref, feature) {
  final isPremium = ref.watch(premiumStatusProvider);
  return RevenueCatConfig.canAccessFeature(feature, isPremium: isPremium);
});
