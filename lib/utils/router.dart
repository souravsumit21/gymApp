import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;
  final profileState =
      user == null ? null : ref.watch(userProfileProvider(user.uid));

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
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
        ],
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
