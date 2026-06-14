# Android External Setup Notes

This file tracks Android setup that is already complete and the external services intentionally parked for later.

## Completed Android Setup

- Firebase project created for Repp Up.
- Android Firebase app registered with package name `com.forgefit.forge_fit`.
- Google Sign-In provider enabled in Firebase Authentication.
- Debug SHA fingerprints added to the Firebase Android app.
- Fresh `google-services.json` downloaded and placed at `android/app/google-services.json`.
- Google Services Gradle plugin added to:
  - `android/settings.gradle.kts`
  - `android/app/build.gradle.kts`
- Android debug APK build verified after Firebase wiring.
- Google login verified on Android.

## Parked For Later

### Firestore Rules Verification

Use production rules that scope user data by Firebase Auth UID and allow authenticated reads for the public exercise library:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    match /exercise_library/{exerciseId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
  }
}
```

### RevenueCat

- Create products:
  - `repp_up_monthly`
  - `repp_up_annual`
- Create entitlement:
  - `repp_up_premium`
- Add Android RevenueCat API key to the app config before enabling paid flows.
- Verify offerings, purchase, restore, and entitlement status on Android.

### Anthropic AI Plans

- Provide `ANTHROPIC_API_KEY` during development with:

```bash
flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...
```

- Before production, proxy AI calls through a backend instead of shipping the key in the app binary.

### ExerciseDB Seeding

- Create or use a RapidAPI account.
- Subscribe to ExerciseDB v1.
- Copy `.env.example` to `.env` and fill:
  - `RAPIDAPI_KEY`
  - `FIREBASE_SERVICE_ACCOUNT`
  - `FIREBASE_PROJECT_ID`
- Run:

```bash
npm install
npm run seed:exercisedb
```

### Android Release Signing

- Create upload keystore.
- Configure release signing.
- Add upload certificate SHA-1 and SHA-256 to Firebase.
- After Play Console setup, add Play App Signing SHA-1 and SHA-256 to Firebase.

### App Check

- Enable Firebase App Check for production hardening after core app flows are stable.
- Start in monitor mode before enforcing.

### iOS Setup

- Add iOS Firebase app for bundle ID `com.forgefit.forgeFit`.
- Add `GoogleService-Info.plist`.
- Add Google Sign-In reversed client ID URL scheme.
- Validate iOS build and login separately.

## Useful Commands

```bash
flutter analyze
flutter test
flutter build apk --debug
flutter run
```
