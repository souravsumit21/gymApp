import 'package:equatable/equatable.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PremiumStatus extends Equatable {
  const PremiumStatus({
    this.isConfigured = false,
    this.isPremium = false,
    this.customerInfo,
    this.offerings,
    this.isLoadingOfferings = false,
    this.lastError,
  });

  final bool isConfigured;
  final bool isPremium;
  final CustomerInfo? customerInfo;
  final Offerings? offerings;
  final bool isLoadingOfferings;
  final String? lastError;

  Package? get annualPackage => offerings?.current?.annual;
  Package? get monthlyPackage => offerings?.current?.monthly;

  PremiumStatus copyWith({
    bool? isConfigured,
    bool? isPremium,
    CustomerInfo? customerInfo,
    Offerings? offerings,
    bool? isLoadingOfferings,
    String? lastError,
    bool clearError = false,
  }) {
    return PremiumStatus(
      isConfigured: isConfigured ?? this.isConfigured,
      isPremium: isPremium ?? this.isPremium,
      customerInfo: customerInfo ?? this.customerInfo,
      offerings: offerings ?? this.offerings,
      isLoadingOfferings: isLoadingOfferings ?? this.isLoadingOfferings,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => [
        isConfigured,
        isPremium,
        customerInfo,
        offerings,
        isLoadingOfferings,
        lastError,
      ];
}

class PurchaseException implements Exception {
  PurchaseException(this.message, {this.code});

  final String message;
  final PurchasesErrorCode? code;

  bool get isCancelled => code == PurchasesErrorCode.purchaseCancelledError;

  @override
  String toString() => message;
}
