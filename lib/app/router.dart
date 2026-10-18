import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/calendar/photo_calendar_screen.dart';
import '../features/home/home_screen.dart';
import '../features/member_room/member_room_screen.dart';
import '../features/mypage/body_edit_screen.dart';
import '../features/mypage/mypage_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/overlay/overlay_screen.dart';
import '../features/records/body_record_screen.dart';
import '../features/records/meal_record_screen.dart';
import '../features/records/records_screen.dart';
import '../features/records/workout_record_screen.dart';
import '../features/records/write/body_write_screen.dart';
import '../features/records/write/meal_write_screen.dart';
import '../features/session/session_controller.dart';
import '../features/shell/app_shell.dart';
import '../features/shop/shop_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/workout/routine_editor_screen.dart';
import '../features/workout/template_picker_screen.dart';
import '../features/workout/workout_session_screen.dart';
import '../features/workout/workout_summary_screen.dart';

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);
  // 리다이렉트가 보는 값(로그인, 온보딩, 첫 로딩)이 바뀔 때만 라우터를 다시 계산한다.
  // 기록을 저장할 때마다 세션을 다시 읽는데, 그때마다 다시 계산하면 방금 닫은 화면이 되살아난다.
  ({bool loading, bool loggedIn, bool onboarding}) gate(AsyncValue<SessionState> session) {
    final value = session.value;
    return (
      loading: session.isLoading && !session.hasValue,
      loggedIn: value?.isLoggedIn ?? false,
      onboarding: value?.needsOnboarding ?? false,
    );
  }
  ref.listen(sessionProvider, (previous, next) {
    if (previous == null || gate(previous) != gate(next)) refresh.ping();
  });

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
        builder: (context, state) => MemberRoomScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/overlay/:userId',
        builder: (context, state) => OverlayScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/calendar/:userId',
        builder: (context, state) => PhotoCalendarScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(path: '/edit-body', builder: (context, state) => const BodyEditScreen()),
      GoRoute(
        path: '/write/body',
        builder: (context, state) => BodyWriteScreen(date: state.uri.queryParameters['date']),
      ),
      GoRoute(path: '/workout/session', builder: (context, state) => const WorkoutSessionScreen()),
      GoRoute(
        path: '/workout/summary/:id',
        builder: (context, state) => WorkoutSummaryScreen(sessionId: state.pathParameters['id']!),
      ),
      // 'new' 가 ':id' 보다 먼저 와야 새 루틴 만들기가 편집 화면으로 잡히지 않는다.
      GoRoute(path: '/workout/routines/new', builder: (context, state) => const TemplatePickerScreen()),
      GoRoute(
        path: '/workout/routines/:id',
        builder: (context, state) => RoutineEditorScreen(
          routineId: state.pathParameters['id']!,
          fresh: state.uri.queryParameters['fresh'] == '1',
        ),
      ),
      GoRoute(
        path: '/write/meal',
        builder: (context, state) => MealWriteScreen(
          date: state.uri.queryParameters['date'],
          slot: state.uri.queryParameters['slot'],
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/records',
                builder: (context, state) => const RecordsScreen(),
                routes: [
                  GoRoute(path: 'body', builder: (context, state) => const BodyRecordScreen()),
                  GoRoute(path: 'meal', builder: (context, state) => const MealRecordScreen()),
                  GoRoute(path: 'workout', builder: (context, state) => const WorkoutRecordScreen()),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/stats', builder: (context, state) => const StatsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/shop', builder: (context, state) => const ShopScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/mypage', builder: (context, state) => const MyPageScreen())],
          ),
        ],
      ),
    ],
  );
});
