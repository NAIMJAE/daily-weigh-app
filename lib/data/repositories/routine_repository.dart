import '../models/routine_draft.dart';
import '../models/workout_routine.dart';
import '../supabase/app_supabase.dart';

/// 루틴을 날과 종목까지 한 번에 읽는 select.
const _routineTree = '*, routine_days(*, routine_items(*, exercises(*)))';

class RoutineRepository {
  String _requireUserId() {
    final userId = requireSupabase().auth.currentUser?.id;
    if (userId == null) throw StateError('로그인이 필요합니다.');
    return userId;
  }

  /// 기본 종목과 내가 추가한 종목. 같은 그룹 친구가 추가한 종목은 빼고 읽는다.
  Future<List<Exercise>> fetchExercises() async {
    final client = requireSupabase();
    final userId = _requireUserId();
    final rows = await client
        .from('exercises')
        .select()
        .or('owner_id.is.null,owner_id.eq.$userId')
        .order('sort_order', ascending: true)
        .order('name', ascending: true);
    return [for (final row in rows as List) Exercise.fromMap(Map<String, dynamic>.from(row as Map))];
  }

  /// 이름을 적어 종목을 추가한다. 증량 방식과 쉬는 시간은 기록 방식에 맞는 기본값을 쓴다.
  Future<Exercise> addExercise({
    required String name,
    required BodyPart bodyPart,
    required Measure measure,
    Equipment? equipment,
  }) async {
    final client = requireSupabase();
    final userId = _requireUserId();
    final (progression, increment, rest) = switch (measure) {
      Measure.weightReps => (Progression.doubleProgression, 2.5, 90),
      Measure.reps => (Progression.reps, 1.0, 90),
      Measure.time => (Progression.time, 10.0, 60),
      Measure.timeDistance => (Progression.none, null, null),
    };
    final row = await client
        .from('exercises')
        .insert({
          'owner_id': userId,
          'name': name.trim(),
          'body_part': bodyPart.dbValue,
          'equipment': equipment?.dbValue,
          'measure': measure.dbValue,
          'progression': progression.dbValue,
          'increment': increment,
          'rest_seconds': rest,
          'sort_order': 900,
        })
        .select()
        .single();
    return Exercise.fromMap(row);
  }

  Future<List<Routine>> fetchTemplates() async {
    final client = requireSupabase();
    final rows = await client.from('routines').select(_routineTree).not('template_key', 'is', null).order('sort_order', ascending: true);
    return [for (final row in rows as List) Routine.fromMap(Map<String, dynamic>.from(row as Map))];
  }

  /// 내 루틴. 사용 중인 루틴이 맨 앞이다.
  Future<List<Routine>> fetchMyRoutines() async {
    final client = requireSupabase();
    final userId = _requireUserId();
    final rows = await client
        .from('routines')
        .select(_routineTree)
        .eq('owner_id', userId)
        .order('is_active', ascending: false)
        .order('created_at', ascending: true);
    return [for (final row in rows as List) Routine.fromMap(Map<String, dynamic>.from(row as Map))];
  }

  /// 템플릿이나 친구 루틴을 내 루틴으로 복사하고 새 루틴의 id 를 돌려준다.
  Future<String> copyRoutine(String sourceId, {bool withCardio = false}) async {
    final client = requireSupabase();
    final id = await client.rpc('copy_routine', params: {'p_source': sourceId, 'p_with_cardio': withCardio});
    return id as String;
  }

  /// 편집한 루틴을 저장한다. 빠진 날과 종목은 지우고, 남은 것과 새것은 순서대로 넣는다.
  Future<void> saveRoutine(RoutineDraft draft, {required Routine original}) async {
    final client = requireSupabase();
    _requireUserId();
    final keptDays = {for (final day in draft.days) day.id};
    final keptItems = {
      for (final day in draft.days)
        for (final item in day.items) item.id,
    };
    final removedDays = [
      for (final day in original.days)
        if (!keptDays.contains(day.id)) day.id,
    ];
    final removedItems = [
      for (final day in original.days)
        for (final item in day.items)
          if (!keptItems.contains(item.id)) item.id,
    ];

    await client
        .from('routines')
        .update({'name': draft.name.trim(), 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', draft.id);
    if (removedItems.isNotEmpty) {
      await client.from('routine_items').delete().inFilter('id', removedItems);
    }
    if (removedDays.isNotEmpty) {
      await client.from('routine_days').delete().inFilter('id', removedDays);
    }
    if (draft.days.isNotEmpty) {
      await client.from('routine_days').upsert([
        for (var i = 0; i < draft.days.length; i++)
          {'id': draft.days[i].id, 'routine_id': draft.id, 'position': i + 1, 'name': draft.days[i].name.trim()},
      ]);
    }
    final items = [
      for (final day in draft.days)
        for (var i = 0; i < day.items.length; i++) day.items[i].toRow(dayId: day.id, position: i + 1),
    ];
    if (items.isNotEmpty) {
      await client.from('routine_items').upsert(items);
    }
  }

  Future<void> deleteRoutine(String routineId) async {
    await requireSupabase().from('routines').delete().eq('id', routineId);
  }

  Future<void> setActiveRoutine(String? routineId) async {
    await requireSupabase().rpc('set_active_routine', params: {'p_routine': routineId});
  }

  /// 이 루틴으로 마지막에 한 날. 다음 추천 날을 정하는 데 쓴다.
  Future<String?> lastDayId(String routineId) async {
    final client = requireSupabase();
    final userId = _requireUserId();
    final row = await client
        .from('workout_sessions')
        .select('routine_day_id')
        .eq('user_id', userId)
        .eq('routine_id', routineId)
        .not('routine_day_id', 'is', null)
        .order('record_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row?['routine_day_id'] as String?;
  }

  /// 운동 하나를 세트까지 한 번에 저장한다. 하루 기록의 운동 표시와 점수는 서버 트리거가 맞춘다.
  Future<String> saveSession({
    required String recordDate,
    required int durationMinutes,
    required List<SessionSet> sets,
    String? routineId,
    String? routineDayId,
    String? dayName,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? note,
  }) async {
    final client = requireSupabase();
    _requireUserId();
    final id = await client.rpc(
      'save_workout_session',
      params: {
        'p_session': {
          'record_date': recordDate,
          'routine_id': routineId,
          'routine_day_id': routineDayId,
          'day_name': dayName,
          'started_at': startedAt?.toUtc().toIso8601String(),
          'finished_at': finishedAt?.toUtc().toIso8601String(),
          'duration_minutes': durationMinutes,
          'note': note,
        },
        'p_sets': [for (final set in sets) set.toMap()],
      },
    );
    return id as String;
  }

  Future<List<WorkoutSession>> fetchSessions(String userId) async {
    final client = requireSupabase();
    final rows = await client
        .from('workout_sessions')
        .select('*, session_sets(*)')
        .eq('user_id', userId)
        .order('record_date', ascending: false)
        .order('created_at', ascending: false);
    return [for (final row in rows as List) WorkoutSession.fromMap(Map<String, dynamic>.from(row as Map))];
  }

  Future<void> deleteSession(String sessionId) async {
    await requireSupabase().from('workout_sessions').delete().eq('id', sessionId);
  }
}
