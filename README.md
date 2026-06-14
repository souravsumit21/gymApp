# 🏋️ Repp Up — Flutter Home Workout App

A full-stack Flutter app for iOS & Android with Google auth, AI-generated workout plans, 
an exercise library with GIF previews, paywall, and progress tracking.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Dart) |
| Auth | Firebase Auth + Google Sign-In |
| Database | Cloud Firestore |
| State | Riverpod 2 (StateNotifier + StreamProvider) |
| Navigation | go_router |
| Paywall | RevenueCat (purchases_flutter) |
| AI Plans | Claude Sonnet API |
| Media | GIF / MP4 via CachedNetworkImage |
| Charts | fl_chart |
| Calendar | table_calendar |
| Animations | flutter_animate |

---

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── theme/
│   └── app_theme.dart                 # Dark energetic theme (black + neon lime)
├── models/
│   ├── models.dart                    # UserProfile, WorkoutPlan, WorkoutSession
│   └── exercise_media.dart            # LibraryExercise, CustomWorkout, ExerciseMedia
├── data/
│   └── exercise_library_data.dart     # 20+ seed exercises with GIF URLs
├── services/
│   ├── auth_service.dart              # Google Sign-In, Firestore profile CRUD
│   ├── workout_service.dart           # Plan/session CRUD + Claude AI generation
│   ├── library_service.dart           # Exercise library, filter state, builder state
│   └── purchase_service.dart          # RevenueCat paywall
├── utils/
│   └── router.dart                    # go_router with auth guards
└── screens/
    ├── auth/login_screen.dart
    ├── onboarding/onboarding_screen.dart   # 5-step: age/gender → body → level → equipment → goals
    ├── home/home_screen.dart               # Dashboard + bottom nav shell
    ├── library/
    │   ├── exercise_library_screen.dart    # Grid browse + search + filter chips
    │   ├── exercise_detail_screen.dart     # Full GIF + instructions + tips
    │   └── custom_workout_builder_screen.dart  # Drag-reorder builder + set editor
    ├── workout/
    │   ├── workout_plans_screen.dart       # Plan list with paywall gate
    │   ├── create_plan_screen.dart         # Body part / weekly + AI toggle
    │   ├── plan_detail_screen.dart         # Day cards with Start button
    │   └── active_workout_screen.dart      # Live workout + rest timer + GIF
    ├── progress/progress_screen.dart       # Calendar + bar chart + recent sessions
    └── paywall/paywall_screen.dart         # RevenueCat offerings UI
```

---

## Setup Instructions

### 1. Firebase

1. Create a Firebase project at https://console.firebase.google.com
2. Enable **Authentication** → Google sign-in method
3. Enable **Cloud Firestore** (start in production mode, add rules below)
4. Download `google-services.json` → `android/app/`
5. Download `GoogleService-Info.plist` → `ios/Runner/`

**Firestore security rules:**
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 2. Android — Google Sign-In SHA-1

```bash
cd android
./gradlew signingReport
# Copy the SHA1 and add it to Firebase Console → Project Settings → Your App
```

Add to `android/app/build.gradle`:
```gradle
android {
  defaultConfig {
    minSdkVersion 21
    targetSdkVersion 34
  }
}
```

### 3. iOS — Google Sign-In URL scheme

In `ios/Runner/Info.plist`, add the reversed client ID from `GoogleService-Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

### 4. RevenueCat Paywall

1. Create an account at https://app.revenuecat.com
2. Create products in App Store Connect + Google Play Console:
   - `repp_up_monthly` — monthly subscription
   - `repp_up_annual` — annual subscription
3. Create an Entitlement: `repp_up_premium`
4. Replace keys in `lib/services/purchase_service.dart`:
```dart
const _revenueCatApiKeyAndroid = 'YOUR_ANDROID_KEY';
const _revenueCatApiKeyIOS = 'YOUR_IOS_KEY';
```

### 5. Claude AI Workout Generation

Pass your Anthropic API key as a build-time environment variable:
```bash
flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...
```

Or for release builds:
```bash
flutter build ios --dart-define=ANTHROPIC_API_KEY=sk-ant-...
flutter build apk --dart-define=ANTHROPIC_API_KEY=sk-ant-...
```

> ⚠️ For production: proxy the API call through your own backend to avoid exposing the key in the app binary.

### 6. Exercise Media (GIFs/Videos)

The seed data uses free GIF URLs from `fitnessprogramer.com`. To use your own:

**Option A — Firebase Storage:**
```dart
// Upload via Firebase Console or use firebase_storage package
// Then update the gifUrl in exercise_library_data.dart:
gifUrl: 'https://firebasestorage.googleapis.com/v0/b/YOUR_PROJECT.appspot.com/o/exercises%2Fpush_up.gif?alt=media',
```

**Option B — Any CDN:**
Simply replace the URLs in `kExerciseLibrary` in `lib/data/exercise_library_data.dart`.

**Adding exercises to Firestore (optional):**
If you want admin-managed exercises, seed the library to Firestore:
```dart
// One-time seed script
for (final ex in kExerciseLibrary) {
  await FirebaseFirestore.instance
      .collection('exercise_library')
      .doc(ex.id)
      .set(ex.toMap());
}
```

### 7. Install & Run

```bash
flutter pub get
flutter run
```

---

## Key User Flows

```
Launch
  ↓
Login (Google) ──→ New user → Onboarding (5 steps) → Home
                └→ Returning user → Home

Home
  ↓ bottom nav
┌─────────────────────────────────────────────────┐
│ Home Tab          Workouts Tab     Progress Tab  │
│ ─ Greeting        ─ [Paywall Gate] ─ Stats grid  │
│ ─ Weekly stats    ─ Plan list      ─ Calendar    │
│ ─ Today's card    ─ Create Plan    ─ Bar chart   │
│ ─ Quick actions                   ─ Sessions    │
└─────────────────────────────────────────────────┘

Workouts → Create Plan
  ↓ choose body part or weekly
  ↓ toggle AI on/off
  ↓ AI calls Claude Sonnet → structured JSON → WorkoutPlan saved

Workouts → Browse Library → Exercise detail (GIF + instructions)
  → + Add to workout (builder) → drag reorder → edit sets/reps → Save

Plan → Day → Active Workout
  ↓ GIF plays fullscreen
  ↓ Set counter + Complete Set button
  ↓ Rest timer (circular countdown)
  ↓ Next exercise...
  ↓ Workout Complete → session saved → Progress updated
```

---

## Customisation Checklist

- [x] Repp Up branding in `app_theme.dart` and `login_screen.dart`
- [ ] Add more exercises to `exercise_library_data.dart`
- [ ] Upload exercise GIFs to Firebase Storage and update URLs
- [ ] Set RevenueCat product IDs and entitlement names
- [ ] Add Anthropic API key (or proxy endpoint)
- [ ] Set up Firebase SHA-1 for Android Google Sign-In
- [ ] Add iOS URL scheme for Google Sign-In
- [ ] Configure Firestore security rules
- [ ] Add app icons (`flutter_launcher_icons` package recommended)
- [ ] Add splash screen (`flutter_native_splash` package recommended)
