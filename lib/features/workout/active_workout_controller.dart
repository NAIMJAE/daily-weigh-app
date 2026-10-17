import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/active_workout.dart';
import '../../data/models/workout_routine.dart';
import '../home/home_controller.dart';
import '../records/records_controller.dart';
import '../session/session_controller.dart';

/// 내 최근 운동. 진행 화면이 지난번 값을 채우는 데 쓴다.
final mySessionsProvider = FutureProvider<List<WorkoutSession>>((ref) async {
  ref.watch(recordRevisionProvider);
  final userId = (await ref.watch(sessionProvider.future)).userId;
  if (userId == null) return [];
  return ref.read(routineRepositoryProvider).fetchSessions(userId, limit: 60);
});

/// 내 운동 전부. 운동 기록 화면(주·일 보기)과 개인 최고 기록 비교에 쓴다.
final allMySessionsProvider = FutureProvider<List<WorkoutSession>>((ref) async {
  ref.watch(recordRevisionProvider);
  final userId = (await ref.watch(sessionProvider.future)).userId;
  if (userId == null) return [];
  return ref.read(routineRepositoryProvider).fetchSessions(userId);
});

/// 날짜('YYYY-MM-DD')별 운동. 하루에 여러 번 할 수 있어 목록이다.
final mySessionsByDateProvider = FutureProvider<Map<String, List<WorkoutSession>>>((ref) async {
  final sessions = await ref.watch(allMySessionsProvider.future);
  final byDate = <String, List<WorkoutSession>>{};
  for (final session in sessions.reversed) {
    byDate.putIfAbsent(session.recordDate, () => []).add(session);
  }
  return byDate;
});

class WorkoutSummary {
  const WorkoutSummary({required this.session, required this.records});

  final WorkoutSession session;
  final List<PersonalRecord> records;
}

/// 운동 하나의 요약: 그 운동과 개인 최고 기록.
final workoutSummaryProvider = FutureProvider.family<WorkoutSummary?, String>((ref, sessionId) async {
  final sessions = await ref.watch(allMySessionsProvider.future);
  final index = sessions.indexWhere((session) => session.id == sessionId);
  if (index < 0) return null;
  // 목록은 최근 운동부터라, 이 운동보다 앞선 기록은 그 뒤에 있는 것들이다.
  final session = sessions[index];
  return WorkoutSummary(session: session, records: personalRecords(session, sessions.sublist(index + 1)));
});

/// 진행 중인 운동. 바뀔 때마다 휴대폰에 저장해 앱이 꺼져도 이어 한다. 사람마다 따로 저장한다.
class ActiveWorkoutNotifier extends AsyncNotifier<ActiveWorkout?> {
  String? _key;

  @override
  Future<ActiveWorkout?> build() async {
    final userId = (await ref.watch(sessionProvider.future)).userId;
    if (userId == null) return null;
    _key = 'active_workout:$userId';
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key!);
    if (raw == null) return null;
    try {
      return ActiveWorkout.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      // 앱이 바뀌어 읽을 수 없는 기록은 버린다.
      await prefs.remove(_key!);
      return null;
    }
  }

  Future<void> start(ActiveWorkout workout) async {
    state = AsyncData(workout);
    await _persist(workout);
  }

  /// 세트를 고친 뒤 부른다. 화면을 다시 그리고 휴대폰에 저장한다.
  Future<void> changed() async {
    final workout = state.value;
    if (workout == null) return;
    state = AsyncData(workout);
    await _persist(workout);
  }

  Future<void> discard() async {
    state = const AsyncData(null);
    final key = _key;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// 서버에 저장하고 진행 중인 운동을 지운다. 저장한 운동의 id 를 돌려준다.
  Future<String> finish() async {
    final workout = state.value;
    if (workout == null) throw StateError('진행 중인 운동이 없어요.');
    final id = await ref
        .read(routineRepositoryProvider)
        .saveSession(
          recordDate: workout.recordDate,
          durationMinutes: workout.minutesAt(DateTime.now()),
          sets: workout.toSessionSets(),
          routineId: workout.routineId,
          routineDayId: workout.routineDayId,
          dayName: workout.dayName,
          startedAt: workout.startedAt,
          finishedAt: workout.live ? DateTime.now() : null,
        );
    await discard();
    return id;
  }

  Future<void> _persist(ActiveWorkout workout) async {
    final key = _key;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(workout.toJson()));
  }
}

final activeWorkoutProvider = AsyncNotifierProvider<ActiveWorkoutNotifier, ActiveWorkout?>(ActiveWorkoutNotifier.new);
