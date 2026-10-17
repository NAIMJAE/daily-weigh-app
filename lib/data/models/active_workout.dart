import 'workout_routine.dart';

/// 진행 중인 운동. 서버에는 완료할 때 한 번에 저장하고, 그 전에는 휴대폰에 JSON으로 둔다.
/// [live]면 헬스장에서 세트마다 체크하고, 아니면 어제 운동을 표로 채운다(타이머 없음).
class ActiveWorkout {
  ActiveWorkout({
    required this.recordDate,
    required this.live,
    required this.exercises,
    this.routineId,
    this.routineDayId,
    this.dayName,
    this.startedAt,
    this.durationMinutes = 60,
  });

  /// 루틴 날 하나로 운동을 시작한다. 세트 값은 지난번 기록, 없으면 루틴 목표로 채운다.
  factory ActiveWorkout.fromDay({
    required Routine routine,
    required RoutineDay day,
    required String recordDate,
    required bool live,
    required List<WorkoutSession> history,
    DateTime? now,
  }) {
    return ActiveWorkout(
      recordDate: recordDate,
      live: live,
      routineId: routine.id,
      routineDayId: day.id,
      dayName: day.name,
      startedAt: live ? (now ?? DateTime.now()) : null,
      exercises: [for (final item in day.items) ActiveExercise.fromItem(item, lastSetsFor(item.exercise.id, history))],
    );
  }

  /// 루틴 없이 종목을 골라 하는 운동. 루틴 순서에는 들어가지 않는다.
  factory ActiveWorkout.free({required String recordDate, required bool live, DateTime? now}) {
    return ActiveWorkout(
      recordDate: recordDate,
      live: live,
      dayName: freeWorkoutName,
      startedAt: live ? (now ?? DateTime.now()) : null,
      exercises: [],
    );
  }

  static const freeWorkoutName = '일회성 운동';

  final String recordDate;
  final bool live;
  final String? routineId;
  final String? routineDayId;
  final String? dayName;
  final DateTime? startedAt;

  /// 표로 채울 때 적는 운동 시간. 헬스장 기록은 시작 시각에서 계산한다.
  int durationMinutes;
  final List<ActiveExercise> exercises;

  int get doneSets => exercises.fold(0, (sum, exercise) => sum + exercise.doneSets);
  int get totalSets => exercises.fold(0, (sum, exercise) => sum + exercise.sets.length);

  /// 저장할 운동 시간. 헬스장 기록은 시작부터 지금까지, 최소 1분.
  int minutesAt(DateTime now) {
    if (!live || startedAt == null) return durationMinutes;
    final minutes = now.difference(startedAt!).inMinutes;
    return minutes < 1 ? 1 : minutes;
  }

  /// 저장할 세트. 체크하지 않은 세트도 done=false 로 남겨 증량 제안이 그때 목표와 비교할 수 있게 한다.
  List<SessionSet> toSessionSets() => [
    for (var i = 0; i < exercises.length; i++)
      for (var j = 0; j < exercises[i].sets.length; j++)
        exercises[i].sets[j].toSessionSet(exercise: exercises[i], itemPosition: i + 1, setNumber: j + 1),
  ];

  Map<String, dynamic> toJson() => {
    'record_date': recordDate,
    'live': live,
    'routine_id': routineId,
    'routine_day_id': routineDayId,
    'day_name': dayName,
    'started_at': startedAt?.toIso8601String(),
    'duration_minutes': durationMinutes,
    'exercises': [for (final exercise in exercises) exercise.toJson()],
  };

  factory ActiveWorkout.fromJson(Map<String, dynamic> json) {
    return ActiveWorkout(
      recordDate: json['record_date'] as String,
      live: (json['live'] as bool?) ?? true,
      routineId: json['routine_id'] as String?,
      routineDayId: json['routine_day_id'] as String?,
      dayName: json['day_name'] as String?,
      startedAt: json['started_at'] == null ? null : DateTime.tryParse(json['started_at'] as String),
      durationMinutes: (json['duration_minutes'] as int?) ?? 60,
      exercises: [
        for (final exercise in (json['exercises'] as List?) ?? const [])
          ActiveExercise.fromJson(Map<String, dynamic>.from(exercise as Map)),
      ],
    );
  }
}

/// 이 종목을 가장 최근에 한 운동의 세트. 없으면 빈 목록.
List<SessionSet> lastSetsFor(String exerciseId, List<WorkoutSession> history) {
  final sessions = [...history]..sort((a, b) => b.recordDate.compareTo(a.recordDate));
  for (final session in sessions) {
    final sets = session.sets.where((set) => set.exerciseId == exerciseId).toList();
    if (sets.isNotEmpty) return sets;
  }
  return const [];
}

class ActiveExercise {
  ActiveExercise({
    required this.name,
    required this.measure,
    required this.sets,
    this.exerciseId,
    this.restSeconds,
    this.repsMin,
    this.repsMax,
    this.targetSeconds,
    this.lastSummary,
  });

  factory ActiveExercise.fromItem(RoutineItem item, List<SessionSet> last) {
    final exercise = item.exercise;
    final targetReps = item.repsMin ?? item.repsMax;
    return ActiveExercise(
      exerciseId: exercise.id,
      name: exercise.name,
      measure: exercise.measure,
      restSeconds: item.restSeconds,
      repsMin: item.repsMin,
      repsMax: item.repsMax,
      targetSeconds: item.targetSeconds,
      lastSummary: summarizeSets(last, exercise.measure),
      sets: [
        for (var i = 0; i < item.targetSets; i++)
          ActiveSet.prefilled(
            last: last.isEmpty ? null : (i < last.length ? last[i] : last.last),
            targetWeight: item.targetWeight,
            targetReps: targetReps,
            targetSeconds: item.targetSeconds,
            targetDistanceKm: item.targetDistanceKm,
          ),
      ],
    );
  }

  /// 운동 중에 고른 종목. 지난번 기록이 있으면 그 값으로 3세트(유산소는 1세트)를 채운다.
  factory ActiveExercise.added(Exercise exercise, List<SessionSet> last) {
    final count = last.isNotEmpty ? last.length : (exercise.measure == Measure.timeDistance ? 1 : 3);
    final targetSeconds = switch (exercise.measure) {
      Measure.time => 60,
      Measure.timeDistance => 20 * 60,
      _ => null,
    };
    final targetReps = exercise.measure.usesReps ? 10 : null;
    return ActiveExercise(
      exerciseId: exercise.id,
      name: exercise.name,
      measure: exercise.measure,
      restSeconds: exercise.restSeconds,
      repsMin: targetReps,
      repsMax: targetReps,
      targetSeconds: targetSeconds,
      lastSummary: summarizeSets(last, exercise.measure),
      sets: [
        for (var i = 0; i < count; i++)
          ActiveSet.prefilled(
            last: last.isEmpty ? null : (i < last.length ? last[i] : last.last),
            targetReps: targetReps,
            targetSeconds: targetSeconds,
          ),
      ],
    );
  }

  final String? exerciseId;
  final String name;
  final Measure measure;
  final int? restSeconds;
  final int? repsMin;
  final int? repsMax;
  final int? targetSeconds;

  /// '지난번 45kg × 10' 같은 한 줄. 처음 하는 종목이면 비어 있다.
  final String? lastSummary;
  final List<ActiveSet> sets;

  int get doneSets => sets.where((set) => set.done).length;

  /// 목표 표시: '10–12회', '8회', '최대', '60초', '20분'.
  String get targetLabel {
    if (measure.usesTime) {
      final seconds = targetSeconds;
      if (seconds == null) return '';
      return seconds >= 60 && seconds % 60 == 0 ? '${seconds ~/ 60}분' : '$seconds초';
    }
    if (repsMin == null && repsMax == null) return '최대';
    if (repsMin != null && repsMax != null && repsMin != repsMax) return '$repsMin–$repsMax회';
    return '${repsMin ?? repsMax}회';
  }

  /// 세트를 체크하면 그 값을 뒤쪽의 아직 하지 않은 세트 중 빈 칸에 채운다.
  /// 처음 하는 종목에서 무게를 세트마다 다시 적지 않게 하려는 것이다.
  void fillAfter(ActiveSet source) {
    final start = sets.indexOf(source);
    if (start < 0) return;
    for (final set in sets.skip(start + 1)) {
      if (set.done) continue;
      var changed = false;
      if (set.weightKg == null && source.weightKg != null) {
        set.weightKg = source.weightKg;
        changed = true;
      }
      if (set.reps == null && source.reps != null && set.targetReps != null) {
        set.reps = source.reps;
        changed = true;
      }
      if (set.distanceKm == null && source.distanceKm != null) {
        set.distanceKm = source.distanceKm;
        changed = true;
      }
      if (changed) set.fills++;
    }
  }

  /// 새 세트는 마지막 세트 값을 그대로 가져온다.
  void addSet() {
    sets.add(sets.isEmpty ? ActiveSet(targetReps: repsMin ?? repsMax, targetSeconds: targetSeconds) : sets.last.copy());
  }

  Map<String, dynamic> toJson() => {
    'exercise_id': exerciseId,
    'name': name,
    'measure': measure.dbValue,
    'rest_seconds': restSeconds,
    'reps_min': repsMin,
    'reps_max': repsMax,
    'target_seconds': targetSeconds,
    'last_summary': lastSummary,
    'sets': [for (final set in sets) set.toJson()],
  };

  factory ActiveExercise.fromJson(Map<String, dynamic> json) {
    return ActiveExercise(
      exerciseId: json['exercise_id'] as String?,
      name: json['name'] as String,
      measure: measureFrom(json['measure']),
      restSeconds: json['rest_seconds'] as int?,
      repsMin: json['reps_min'] as int?,
      repsMax: json['reps_max'] as int?,
      targetSeconds: json['target_seconds'] as int?,
      lastSummary: json['last_summary'] as String?,
      sets: [for (final set in (json['sets'] as List?) ?? const []) ActiveSet.fromJson(Map<String, dynamic>.from(set as Map))],
    );
  }
}

class ActiveSet {
  ActiveSet({
    this.weightKg,
    this.reps,
    this.seconds,
    this.distanceKm,
    this.targetReps,
    this.targetSeconds,
    this.done = false,
  });

  /// 지난번 같은 번호 세트의 값으로 채운다. 지난번이 없으면 루틴 목표로 채운다.
  factory ActiveSet.prefilled({
    SessionSet? last,
    double? targetWeight,
    int? targetReps,
    int? targetSeconds,
    double? targetDistanceKm,
  }) {
    return ActiveSet(
      weightKg: last?.weightKg ?? targetWeight,
      reps: last?.reps ?? targetReps,
      seconds: last?.seconds ?? targetSeconds,
      distanceKm: last?.distanceKm ?? targetDistanceKm,
      targetReps: targetReps,
      targetSeconds: targetSeconds,
    );
  }

  double? weightKg;
  int? reps;
  int? seconds;
  double? distanceKm;
  final int? targetReps;
  final int? targetSeconds;
  bool done;

  /// 앱이 값을 대신 채운 횟수. 입력 칸이 이 값으로 새로 그려진다. 휴대폰에는 저장하지 않는다.
  int fills = 0;

  ActiveSet copy() => ActiveSet(
    weightKg: weightKg,
    reps: reps,
    seconds: seconds,
    distanceKm: distanceKm,
    targetReps: targetReps,
    targetSeconds: targetSeconds,
  );

  SessionSet toSessionSet({required ActiveExercise exercise, required int itemPosition, required int setNumber}) {
    final measure = exercise.measure;
    return SessionSet(
      exerciseId: exercise.exerciseId,
      exerciseName: exercise.name,
      itemPosition: itemPosition,
      setNumber: setNumber,
      weightKg: measure.usesWeight ? weightKg : null,
      reps: measure.usesReps ? reps : null,
      seconds: measure.usesTime ? seconds : null,
      distanceKm: measure.usesDistance ? distanceKm : null,
      targetReps: targetReps,
      targetSeconds: targetSeconds,
      done: done,
    );
  }

  Map<String, dynamic> toJson() => {
    'weight_kg': weightKg,
    'reps': reps,
    'seconds': seconds,
    'distance_km': distanceKm,
    'target_reps': targetReps,
    'target_seconds': targetSeconds,
    'done': done,
  };

  factory ActiveSet.fromJson(Map<String, dynamic> json) {
    return ActiveSet(
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      reps: json['reps'] as int?,
      seconds: json['seconds'] as int?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      targetReps: json['target_reps'] as int?,
      targetSeconds: json['target_seconds'] as int?,
      done: (json['done'] as bool?) ?? false,
    );
  }
}

String _number(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

/// 세트 값 한 줄: '45kg × 10', '12회', '60초', '20분 · 3.2km'. 세트마다 다르면 가장 무거운(또는 많은) 세트로 쓴다.
String? summarizeSets(List<SessionSet> sets, Measure measure) {
  final done = sets.where((set) => set.done).toList();
  if (done.isEmpty) return null;
  switch (measure) {
    case Measure.weightReps:
      final best = done.reduce((a, b) => (b.weightKg ?? 0) > (a.weightKg ?? 0) ? b : a);
      if (best.weightKg == null) return best.reps == null ? null : '${best.reps}회';
      return '${_number(best.weightKg!)}kg × ${best.reps ?? '-'}';
    case Measure.reps:
      final best = done.reduce((a, b) => (b.reps ?? 0) > (a.reps ?? 0) ? b : a);
      return best.reps == null ? null : '${best.reps}회';
    case Measure.time:
      final best = done.reduce((a, b) => (b.seconds ?? 0) > (a.seconds ?? 0) ? b : a);
      return best.seconds == null ? null : '${best.seconds}초';
    case Measure.timeDistance:
      final best = done.reduce((a, b) => (b.seconds ?? 0) > (a.seconds ?? 0) ? b : a);
      if (best.seconds == null) return null;
      return [
        '${best.seconds! ~/ 60}분',
        if (best.distanceKm != null) '${_number(best.distanceKm!)}km',
      ].join(' · ');
  }
}

/// 오늘 올려 볼 종목 하나. 받으면 그 종목의 아직 하지 않은 세트 값이 바뀐다.
class ProgressionSuggestion {
  const ProgressionSuggestion({
    required this.exerciseIndex,
    required this.exerciseName,
    required this.from,
    required this.to,
    this.weightKg,
    this.reps,
    this.seconds,
  });

  /// 진행 중인 운동의 종목 순서.
  final int exerciseIndex;
  final String exerciseName;

  /// '60kg × 8' → '62.5kg × 8' 처럼 보여 줄 두 값.
  final String from;
  final String to;
  final double? weightKg;
  final int? reps;
  final int? seconds;

  void applyTo(ActiveWorkout workout) {
    final exercise = workout.exercises[exerciseIndex];
    for (final set in exercise.sets) {
      if (set.done) continue;
      if (weightKg != null) set.weightKg = weightKg;
      if (reps != null) set.reps = reps;
      if (seconds != null) set.seconds = seconds;
      set.fills++;
    }
  }
}

/// 루틴 종목마다 증량 방식대로, 지난번 그 종목의 모든 세트가 목표를 채웠으면 올려 볼 값을 제안한다.
/// 지난번 세트를 하나라도 못 채웠거나 처음 하는 종목이면 제안하지 않는다 (docs/workout-routine-plan.md 6장).
List<ProgressionSuggestion> suggestProgressions(RoutineDay day, List<WorkoutSession> history) {
  final suggestions = <ProgressionSuggestion>[];
  for (var i = 0; i < day.items.length; i++) {
    final suggestion = suggestFor(day.items[i], lastSetsFor(day.items[i].exercise.id, history), i);
    if (suggestion != null) suggestions.add(suggestion);
  }
  return suggestions;
}

ProgressionSuggestion? suggestFor(RoutineItem item, List<SessionSet> last, int index) {
  if (last.isEmpty || last.any((set) => !set.done)) return null;
  final step = item.increment;
  if (step == null || step <= 0) return null;
  String kg(double value) => _number(value);
  final name = item.exercise.name;

  switch (item.progression) {
    case Progression.weight:
      final target = item.repsMin ?? item.repsMax;
      final weight = _maxWeight(last);
      if (target == null || weight == null || last.any((set) => (set.reps ?? 0) < target)) return null;
      final next = weight + step;
      return ProgressionSuggestion(
        exerciseIndex: index,
        exerciseName: name,
        from: '${kg(weight)}kg × $target',
        to: '${kg(next)}kg × $target',
        weightKg: next,
        reps: target,
      );
    case Progression.doubleProgression:
      final low = item.repsMin;
      final high = item.repsMax;
      final weight = _maxWeight(last);
      if (low == null || high == null || weight == null || last.any((set) => (set.reps ?? 0) < high)) return null;
      final next = weight + step;
      return ProgressionSuggestion(
        exerciseIndex: index,
        exerciseName: name,
        from: '${kg(weight)}kg × $high',
        to: '${kg(next)}kg × $low',
        weightKg: next,
        reps: low,
      );
    case Progression.reps:
      final reps = [for (final set in last) set.reps ?? 0];
      final lowest = reps.reduce((a, b) => a < b ? a : b);
      final target = item.repsMin ?? item.repsMax;
      // 지난번 가장 적게 한 세트가 목표 이상이면, 그 횟수에서 올린다. 목표가 '최대'면 비교 없이 올린다.
      if (lowest <= 0 || (target != null && lowest < target)) return null;
      final next = lowest + step.round();
      return ProgressionSuggestion(exerciseIndex: index, exerciseName: name, from: '$lowest회', to: '$next회', reps: next);
    case Progression.time:
      final target = item.targetSeconds;
      final times = [for (final set in last) set.seconds ?? 0];
      final shortest = times.reduce((a, b) => a < b ? a : b);
      if (target == null || shortest < target) return null;
      final next = shortest + step.round();
      return ProgressionSuggestion(
        exerciseIndex: index,
        exerciseName: name,
        from: '$shortest초',
        to: '$next초',
        seconds: next,
      );
    case Progression.none:
      return null;
  }
}

double? _maxWeight(List<SessionSet> sets) {
  double? top;
  for (final set in sets) {
    final weight = set.weightKg;
    if (weight != null && (top == null || weight > top)) top = weight;
  }
  return top;
}
