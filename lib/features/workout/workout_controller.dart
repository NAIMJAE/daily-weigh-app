import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/workout_routine.dart';
import '../home/home_controller.dart';
import '../records/records_controller.dart';
import '../session/session_controller.dart';

/// 내 루틴. 사용 중인 루틴이 맨 앞이다.
final myRoutinesProvider = FutureProvider<List<Routine>>((ref) async {
  await ref.watch(sessionProvider.future);
  return ref.read(routineRepositoryProvider).fetchMyRoutines();
});

final routineTemplatesProvider = FutureProvider<List<Routine>>((ref) async {
  return ref.read(routineRepositoryProvider).fetchTemplates();
});

/// 기본 종목과 내가 추가한 종목.
final exercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  await ref.watch(sessionProvider.future);
  return ref.read(routineRepositoryProvider).fetchExercises();
});

/// 사용 중인 루틴과 오늘 할 날.
class TodayPlan {
  const TodayPlan({required this.routine, required this.next, this.lastDay});

  final Routine routine;
  final RoutineDay? next;

  /// 이 루틴으로 마지막에 한 날. 없으면 아직 이 루틴으로 운동하지 않았다.
  final RoutineDay? lastDay;
}

final todayPlanProvider = FutureProvider<TodayPlan?>((ref) async {
  ref.watch(recordRevisionProvider);
  final routines = await ref.watch(myRoutinesProvider.future);
  final active = routines.where((routine) => routine.isActive).firstOrNull;
  if (active == null) return null;
  final lastDayId = await ref.read(routineRepositoryProvider).lastDayId(active.id);
  return TodayPlan(
    routine: active,
    next: active.nextDay(lastDayId: lastDayId),
    lastDay: active.days.where((day) => day.id == lastDayId).firstOrNull,
  );
});

/// 루틴을 바꾼 뒤 루틴 화면들이 다시 읽게 한다.
void refreshRoutines(WidgetRef ref) {
  ref.invalidate(myRoutinesProvider);
  ref.invalidate(todayPlanProvider);
}
