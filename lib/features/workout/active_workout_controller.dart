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
