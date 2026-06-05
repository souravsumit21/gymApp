# Forge Fit Product Requirements Document

## 1. Overview

Forge Fit is a mobile-first home workout app for iOS and Android. It helps users sign in, complete a short fitness onboarding flow, generate or create workout plans, follow guided active workouts, browse an exercise library with animated media, and track progress over time.

The current codebase is a Flutter app using Firebase for authentication and user data, RevenueCat for premium access, and Anthropic Claude for AI-generated workout plans. The product direction is a polished consumer fitness app that can start with seeded exercise media and grow into a richer managed library later.

## 2. Goals

- Make it easy for a user to start a personalized home workout plan in under five minutes.
- Support both AI-generated plans and manually created plans.
- Provide a visual exercise library with GIF previews, instructions, muscle groups, difficulty, equipment, and safety tips.
- Track completed sessions, weekly activity, workout streaks, and progress history.
- Monetize advanced workout planning and premium flows through subscriptions.
- Keep the first production implementation affordable by streaming exercise GIFs from a seeded media source before investing in owned media hosting.

## 3. User Flows

### First-Time User

1. User launches the app.
2. User signs in with Google.
3. App creates a user profile in Firestore.
4. User completes onboarding: age, gender, body stats, fitness level, equipment, and goals.
5. User lands on the home dashboard.
6. User creates a plan or starts from suggested workout content.

### Returning User

1. User launches the app.
2. Existing Firebase session restores.
3. User lands on the home dashboard.
4. User continues a plan, starts a workout, checks progress, or creates a new plan.

### Plan Creation

1. User opens Workouts.
2. User chooses body-part plan or weekly plan.
3. User selects target body part or schedule details.
4. User chooses AI-generated or manual plan creation.
5. App saves the plan to Firestore under the user.

### Active Workout

1. User opens a workout plan.
2. User selects a day.
3. App shows exercise media, instructions, set/repetition targets, and rest timing.
4. User completes sets and advances through the workout.
5. App saves a completed workout session.
6. Progress charts and weekly stats update.

### Exercise Library and Custom Workouts

1. User opens the exercise library.
2. User searches or filters by muscle group, equipment, or difficulty.
3. User opens exercise detail to view GIF, instructions, target muscles, and tips.
4. User adds exercises to a custom workout builder.
5. User reorders exercises, edits sets/reps/rest, and saves the custom workout.

## 4. Feature Specifications

### Authentication

- Google Sign-In using Firebase Auth.
- Create or load a `UserProfile` document after successful sign-in.
- Support sign-out from the profile menu.
- Route unauthenticated users to login.
- Route users with incomplete onboarding to onboarding before the main app.

### Onboarding

- Collect age, gender, height, weight, fitness level, available equipment, and goals.
- Save onboarding completion state to Firestore.
- Use onboarding answers to personalize workout generation prompts.

### Home Dashboard

- Show greeting and user name.
- Show weekly workout count, total minutes, and total sessions.
- Show quick actions for creating a plan, viewing workouts, browsing the library, and checking progress.
- Surface a next workout card when a plan is available.

### Workout Plans

- List saved workout plans.
- Support plan deletion.
- Show paywall gate for premium-only plan features.
- Create plans by body part or weekly schedule.
- Support AI generation via Claude using structured JSON output.
- Save plan data under `users/{userId}/plans/{planId}`.

### Active Workout

- Show exercise name, animated media, set target, repetition/seconds target, and rest duration.
- Let users complete sets and advance exercises.
- Include a rest timer between sets.
- Save completed sessions under `users/{userId}/sessions/{sessionId}`.

### Exercise Library

- Seed library exercises from ExerciseDB data.
- Search by exercise name.
- Filter by muscle group, equipment, and difficulty.
- Show exercise detail with GIF, instructions, target muscles, secondary muscles, and tips.
- Add exercises to a custom workout builder.

### Custom Workout Builder

- Add one or more library exercises.
- Edit sets, reps, seconds, rest, and notes per exercise.
- Reorder exercises.
- Save custom workouts under `users/{userId}/custom_workouts/{workoutId}`.

### Progress

- Show sessions by calendar date.
- Show recent sessions.
- Show weekly/monthly chart summaries.
- Compute streaks and aggregate duration from saved sessions.

### Paywall and Subscriptions

- Use RevenueCat for offerings, purchases, restore purchases, and entitlement checks.
- Product IDs:
  - `forge_fit_monthly`
  - `forge_fit_annual`
- Entitlement:
  - `forge_fit_premium`
- Premium checks should gracefully handle unavailable RevenueCat setup in development.

### AI Workout Generation

- Generate structured workout plan JSON with Claude.
- Use onboarding profile values in the prompt.
- Require `ANTHROPIC_API_KEY` at build/run time for direct app calls.
- Production recommendation: proxy AI calls through a backend to avoid shipping API keys in the app binary.

## 5. ExerciseDB Media Strategy

### Initial Source

Use ExerciseDB v1 on RapidAPI as the initial free/low-cost source for exercise metadata and GIF URLs. The app should not call RapidAPI from every client session. Instead, fetch the ExerciseDB catalog through a local Node.js seed script and write normalized exercise documents to Firestore.

### Seed Once, Stream Directly

1. Developer runs a Node.js script locally with a RapidAPI key.
2. Script fetches exercises from ExerciseDB v1.
3. Script normalizes fields into the app's exercise schema.
4. Script writes exercises to Firestore under `exercise_library/{exerciseId}`.
5. App reads exercise metadata from Firestore or bundled seed data.
6. GIF URLs continue to stream directly from ExerciseDB's CDN.

This keeps ongoing media hosting cost at zero for the initial product, because the app stores only references to hosted GIFs.

### Normalized Exercise Fields

- `id`
- `name`
- `bodyPart`
- `target`
- `secondaryMuscles`
- `equipment`
- `gifUrl`
- `instructions`
- `difficulty`
- `muscleGroups`
- `source`
- `sourceExerciseId`
- `createdAt`
- `updatedAt`

### Client Strategy

- Prefer Firestore exercise documents for remotely managed catalog updates.
- Keep a bundled seed list as an offline or development fallback.
- Cache media through `cached_network_image`.
- Show placeholders and retry-friendly UI when media fails to load.

### Upgrade Path

- Phase 1: ExerciseDB CDN URLs streamed directly.
- Phase 2: Copy high-value exercise GIFs to Firebase Storage for reliability.
- Phase 3: Replace third-party GIFs with owned media or licensed assets.
- Phase 4: Add video variants, thumbnails, and adaptive media delivery through a dedicated CDN.

### Risks and Mitigations

- CDN URLs may change: store source IDs and allow reseeding.
- Third-party media terms may change: keep an upgrade path to owned hosting.
- GIF loading may be heavy: use lazy loading, thumbnails, and image caching.
- RapidAPI limits may apply: seed from a script rather than calling from the app.

## 6. Data Model

### Firestore Collections

```text
users/{userId}
users/{userId}/plans/{planId}
users/{userId}/sessions/{sessionId}
users/{userId}/custom_workouts/{workoutId}
exercise_library/{exerciseId}
```

### UserProfile

- `uid`
- `email`
- `displayName`
- `photoUrl`
- `age`
- `gender`
- `weightKg`
- `heightCm`
- `fitnessLevel`
- `equipment`
- `goals`
- `isPremium`
- `createdAt`
- `onboardingComplete`

### WorkoutPlan

- `id`
- `userId`
- `title`
- `description`
- `type`
- `days`
- `targetGoals`
- `difficulty`
- `isAiGenerated`
- `createdAt`
- `updatedAt`

### WorkoutDay

- `id`
- `name`
- `targetBodyPart`
- `exercises`
- `estimatedMinutes`

### WorkoutSet

- `exerciseId`
- `sets`
- `reps`
- `seconds`
- `restSeconds`
- `notes`

### WorkoutSession

- `id`
- `userId`
- `planId`
- `dayId`
- `startTime`
- `endTime`
- `durationMinutes`
- `completedExercises`
- `totalSets`
- `caloriesEstimate`

### LibraryExercise

- `id`
- `name`
- `description`
- `muscleGroups`
- `equipment`
- `difficulty`
- `media`
- `instructions`
- `tips`
- `isFeatured`
- `source`

### CustomWorkout

- `id`
- `userId`
- `title`
- `description`
- `exercises`
- `estimatedMinutes`
- `createdAt`
- `updatedAt`

## 7. Tech Stack

- Flutter 3.x and Dart.
- Firebase Core, Firebase Auth, Google Sign-In, and Cloud Firestore.
- Riverpod for state management.
- go_router for navigation and auth guards.
- RevenueCat through `purchases_flutter`.
- Claude Messages API through `http`.
- ExerciseDB v1 on RapidAPI for catalog seeding.
- Node.js seed script for importing ExerciseDB data into Firestore.
- `cached_network_image` for GIF/media loading.
- `fl_chart` and `table_calendar` for progress visualization.

## 8. Non-Functional Requirements

### Performance

- Home screen should render quickly after auth state resolves.
- Exercise media should lazy-load and show placeholders.
- Workout interaction should not depend on repeated network requests once a plan is loaded.

### Reliability

- Auth and Firestore errors should show user-friendly fallbacks.
- Paywall failures should not crash the app.
- Exercise media failures should show placeholders.
- AI generation failures should preserve manual plan creation.

### Security

- Firestore user data must be scoped by authenticated `uid`.
- Do not ship long-lived Anthropic keys in production app binaries.
- Do not expose RapidAPI keys in the Flutter client.
- RevenueCat API keys should be platform-specific.

### Privacy

- Store only fitness profile fields required for personalization.
- Keep user workout data under user-owned Firestore paths.
- Avoid storing sensitive health claims beyond basic profile and workout history.

### Maintainability

- Keep generated media seed logic outside the app runtime.
- Keep exercise schema normalized and source-aware.
- Prefer feature-specific services and providers over global mutable state.

### Accessibility

- Maintain sufficient contrast in the dark theme.
- Ensure tappable targets are large enough for workout use.
- Support readable text sizes and clear progress indicators.

## 9. Setup Checklist

### Local Flutter App

- [ ] Scaffold missing Flutter platform folders.
- [ ] Resolve `flutter pub get`.
- [ ] Add missing dependencies used by code.
- [ ] Add required asset directories or remove unused asset declarations.
- [ ] Run `flutter analyze`.
- [ ] Run the app on iOS Simulator and Android Emulator.

### Firebase

- [ ] Create Firebase project.
- [ ] Enable Google Authentication.
- [ ] Enable Cloud Firestore.
- [ ] Add Android app and download `google-services.json`.
- [ ] Add iOS app and download `GoogleService-Info.plist`.
- [ ] Add Android SHA-1/SHA-256 fingerprints.
- [ ] Configure iOS reversed client ID URL scheme.
- [ ] Apply Firestore security rules.

### RevenueCat

- [ ] Create RevenueCat project.
- [ ] Create monthly and annual products in stores.
- [ ] Create `forge_fit_premium` entitlement.
- [ ] Configure offerings.
- [ ] Add Android and iOS RevenueCat API keys.
- [ ] Initialize RevenueCat after sign-in.

### ExerciseDB

- [ ] Create RapidAPI account.
- [ ] Subscribe to ExerciseDB v1.
- [ ] Add RapidAPI key to local seed script environment.
- [ ] Create Node.js seed script.
- [ ] Fetch and normalize exercise catalog.
- [ ] Seed Firestore `exercise_library`.
- [ ] Confirm app can read and display seeded GIF URLs.

### AI

- [ ] Add development `ANTHROPIC_API_KEY` via `--dart-define`.
- [ ] Add production backend proxy before public release.
- [ ] Validate AI output parsing and fallback error states.

### Release Readiness

- [ ] Add app icons and splash screen.
- [ ] Replace placeholder branding where needed.
- [ ] Configure bundle identifiers and app signing.
- [ ] Test subscription purchase and restore flows.
- [ ] Test onboarding, plan creation, active workout, and progress flows.
- [ ] Verify privacy policy and store listing requirements.
