import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import 'router_refresh.dart';
import '../screens/auth/login_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/workout/workout_plans_screen.dart';
import '../screens/workout/create_plan_screen.dart';
import '../screens/workout/active_workout_screen.dart';
import '../screens/workout/plan_detail_screen.dart';
import '../screens/workout/custom_workout_start_screen.dart';
import '../screens/library/custom_workout_builder_screen.dart';
import '../screens/progress/progress_screen.dart';
import '../screens/paywall/paywall_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/library/custom_workout_detail_screen.dart';
import '../screens/share/shared_workout_preview_screen.dart';
import '../screens/share/notifications_screen.dart';
import '../screens/community/community_library_screen.dart';
import '../screens/community/community_workout_detail_screen.dart';
import '../screens/community/publish_workout_screen.dart';
import '../screens/splash/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);

  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/splash',
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final user = authState.valueOrNull;
      final profileState =
          user == null ? null : ref.read(userProfileProvider(user.uid));

      final isSplash = state.matchedLocation == '/splash';
      if (isSplash) return null;

      if (authState.isLoading) return null;

      final isLoggedIn = user != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (!isLoggedIn) return null;

      if (profileState?.isLoading ?? false) return null;

      final onboardingComplete =
          profileState?.valueOrNull?.onboardingComplete ?? false;
      if (!onboardingComplete && !isOnboarding) return '/onboarding';
      if (onboardingComplete && (isLoggingIn || isOnboarding)) {
        return '/workouts';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: '/workouts',
            name: 'workouts',
            builder: (context, state) => const WorkoutPlansScreen(),
            routes: [
              GoRoute(
                path: 'create',
                name: 'create-plan',
                builder: (context, state) => const CreatePlanScreen(),
              ),
              GoRoute(
                path: 'custom/new',
                name: 'create-custom-workout',
                builder: (context, state) => const CustomWorkoutBuilderScreen(),
              ),
              GoRoute(
                path: 'custom/:workoutId',
                name: 'custom-workout-detail',
                builder: (context, state) => CustomWorkoutDetailScreen(
                  workoutId: state.pathParameters['workoutId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'publish',
                    name: 'publish-workout',
                    builder: (context, state) => PublishWorkoutScreen(
                      workoutId: state.pathParameters['workoutId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: ':planId',
                name: 'plan-detail',
                builder: (context, state) => PlanDetailScreen(
                  planId: state.pathParameters['planId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/progress',
            name: 'progress',
            builder: (context, state) => const ProgressScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/community',
            name: 'community',
            builder: (context, state) => const CommunityLibraryScreen(),
            routes: [
              GoRoute(
                path: ':workoutId',
                name: 'community-workout-detail',
                builder: (context, state) => CommunityWorkoutDetailScreen(
                  workoutId: state.pathParameters['workoutId']!,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/share/:shareId',
        name: 'shared-workout-preview',
        builder: (context, state) => SharedWorkoutPreviewScreen(
          shareId: state.pathParameters['shareId']!,
        ),
      ),
      GoRoute(
        path: '/w/:shareId',
        name: 'external-share-deeplink',
        builder: (context, state) => SharedWorkoutPreviewScreen(
          shareId: state.pathParameters['shareId']!,
          isExternal: true,
        ),
      ),
      GoRoute(
        path: '/workout/custom/:workoutId/start',
        name: 'start-custom-workout',
        builder: (context, state) => CustomWorkoutStartScreen(
          workoutId: state.pathParameters['workoutId']!,
        ),
      ),
      GoRoute(
        path: '/workout/plan/:planId/start/:dayId',
        name: 'active-workout',
        builder: (context, state) => ActiveWorkoutScreen(
          planId: state.pathParameters['planId']!,
          dayId: state.pathParameters['dayId']!,
        ),
      ),
      GoRoute(
        path: '/paywall',
        name: 'paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
    ],
  );
});
