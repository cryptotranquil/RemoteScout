import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/app_store.dart';
import 'data/providers.dart';
import 'features/applications/application_form_screen.dart';
import 'features/applications/applications_screen.dart';
import 'features/discover/discover_screen.dart';
import 'features/job_details/job_details_screen.dart';
import 'features/onboarding/notification_prefs_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/statistics_screen.dart';
import 'features/saved/saved_screen.dart';
import 'shell.dart';

/// Notifies the router when onboarding state changes (initial route guard).
class AppRouterRefresh extends ChangeNotifier {
  AppRouterRefresh(AppStore store) {
    _sub = store.watchMeta().skip(1).listen((_) => notifyListeners());
  }

  StreamSubscription<void>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

GoRouter buildRouter(AppRouterRefresh refresh) {
  return GoRouter(
    initialLocation: appStore.isOnboarded ? '/discover' : '/welcome',
    refreshListenable: refresh,
    routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(
        path: '/notifications-setup',
        builder: (_, __) => const NotificationPrefsScreen(initialSetup: true),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/discover', builder: (_, __) => const DiscoverScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/saved', builder: (_, __) => const SavedScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/applications',
              builder: (_, __) => const ApplicationsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/job/:id',
        builder: (_, state) =>
            JobDetailsScreen(jobId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/application/new',
        builder: (_, __) => const ApplicationFormScreen(),
      ),
      GoRoute(
        path: '/application/:id',
        builder: (_, state) =>
            ApplicationFormScreen(applicationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(path: '/stats', builder: (_, __) => const StatisticsScreen()),
    ],
  );
}
