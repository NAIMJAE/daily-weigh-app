import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/body/body_screen.dart';
import '../features/calendar/photo_calendar_screen.dart';
import '../features/home/home_screen.dart';
import '../features/member_room/member_room_screen.dart';
import '../features/mypage/body_edit_screen.dart';
import '../features/mypage/mypage_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/overlay/overlay_screen.dart';
import '../features/session/session_controller.dart';
import '../features/shell/app_shell.dart';
import '../features/stats/stats_screen.dart';

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);
  ref.listen(sessionProvider, (_, _) => refresh.ping());

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final value = session.value ?? const SessionState();
      if (session.isLoading && !session.hasValue) return null;
      final path = state.matchedLocation;
      final onAuth = path == '/login' || path == '/register';
      final onOnboarding = path == '/onboarding';

      if (!value.isLoggedIn) {
        return onAuth ? null : '/login';
      }
      if (value.needsOnboarding) {
        return onOnboarding ? null : '/onboarding';
      }
      if (onAuth || onOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(
        path: '/room/:userId',
        builder: (context, state) => MemberRoomScreen(
          userId: state.pathParameters['userId']!,
        ),
      ),
      GoRoute(
        path: '/overlay/:userId',
        builder: (context, state) => OverlayScreen(
          userId: state.pathParameters['userId']!,
        ),
      ),
      GoRoute(
        path: '/calendar/:userId',
        builder: (context, state) => PhotoCalendarScreen(
          userId: state.pathParameters['userId']!,
        ),
      ),
      GoRoute(path: '/edit-body', builder: (context, state) => const BodyEditScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/body', builder: (context, state) => const BodyScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/stats', builder: (context, state) => const StatsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/mypage', builder: (context, state) => const MyPageScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
