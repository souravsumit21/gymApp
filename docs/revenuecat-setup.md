# RevenueCat Setup — Repp Up

## Overview

RevenueCat powers premium subscriptions. The app infra lives in:

| File | Purpose |
|------|---------|
| `lib/config/revenue_cat_config.dart` | API keys, product IDs, entitlement, feature gates |
| `lib/services/purchase_service.dart` | SDK wrapper (configure, purchase, restore) |
| `lib/providers/premium_providers.dart` | Riverpod state + auth lifecycle |
| `lib/widgets/premium_gate.dart` | Reusable locked-state UI |
| `lib/screens/paywall/paywall_screen.dart` | Offerings + subscribe UI |

## 1. RevenueCat Dashboard

1. Create a project at [app.revenuecat.com](https://app.revenuecat.com).
2. Add **iOS** and **Android** apps (bundle IDs match Firebase).
3. Create products in App Store Connect + Google Play Console:
   - `repp_up_monthly`
   - `repp_up_annual`
4. Create entitlement: **`repp_up_premium`**
5. Create offering **`default`** with monthly + annual packages.
6. Copy platform API keys (`goog_...` / `appl_...`).

## 2. Local Development (test API key)

### Option A — `.env.local` (recommended)

A `.env.local` file is already set up for local dev (gitignored). It uses a **Test Store** key (`test_...`) which works on both Android and iOS.

```bash
chmod +x scripts/flutter_run_dev.sh
./scripts/flutter_run_dev.sh
```

To reset from scratch:

```bash
cp .env.local.example .env.local
# paste REVENUECAT_API_KEY=test_... from RevenueCat dashboard
```

### Option B — inline dart-define

```bash
flutter run --dart-define=REVENUECAT_API_KEY=test_your_test_store_key
```

### Key types

| Key prefix | Use |
|------------|-----|
| `test_` | **Test Store** — single key, iOS + Android, no real billing (dev) |
| `goog_` | Production Android |
| `appl_` | Production iOS |

Test Store still needs products + entitlement in the RevenueCat dashboard (Test Store products, not App Store / Play yet).

Without keys, the app runs normally — premium stays locked and the paywall shows a config notice.

## 3. Feature Gates

Edit `lib/config/revenue_cat_config.dart`:

```dart
static const gateAiWorkoutPlans = true;      // locked until subscribed
static const gateCustomWorkouts = false;     // flip to true before launch
```

Use `premiumFeatureAccessProvider(PremiumFeature.x)` or `PremiumGate` widget to gate UI.

## 4. Auth Lifecycle

- On sign-in → `PremiumNotifier` configures RevenueCat and calls `Purchases.logIn(uid)`.
- On sign-out → `Purchases.logOut()` and premium state resets.
- Customer info updates stream into `premiumNotifierProvider` automatically.

## 5. Testing Checklist

- [ ] Offerings load on paywall
- [ ] Monthly + annual packages display prices
- [ ] Sandbox purchase unlocks `repp_up_premium`
- [ ] Restore purchase works after reinstall
- [ ] AI Workout Plans section unlocks when entitled
- [ ] Sign-out clears premium access

## 6. Production Builds

```bash
flutter build apk \
  --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx

flutter build ios \
  --dart-define=REVENUECAT_IOS_KEY=appl_xxx
```

Store API keys in CI secrets — never commit them.
