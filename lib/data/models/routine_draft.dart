import '../../core/utils/random_id.dart';
import 'workout_routine.dart';

/// 루틴 편집 화면에서 고치는 중인 종목 하나. 저장할 때 routine_items 한 줄이 된다.
class ItemDraft {
  ItemDraft({
    required this.id,
    required this.exercise,
    required this.sets,
    this.repsMin,
    this.repsMax,
    this.seconds,
    this.distanceKm,
    this.weight,
    this.progression,
    this.increment,
    this.restSeconds,
  });

  /// 새로 넣은 종목의 목표 기본값. 기록 방식에 맞춘다.
  factory ItemDraft.fresh(Exercise exercise) {
    final (sets, reps, seconds) = switch (exercise.measure) {
      Measure.weightReps => (3, 10, null),
      Measure.reps => (3, 10, null),
      Measure.time => (3, null, 60),
      Measure.timeDistance => (1, null, 20 * 60),
    };
    return ItemDraft(
      id: randomUuid(),
      exercise: exercise,
      sets: sets,
      repsMin: reps,
      repsMax: reps == null ? null : (exercise.progression == Progression.doubleProgression ? reps + 2 : reps),
      seconds: seconds,
    );
  }

  factory ItemDraft.fromItem(RoutineItem item) {
    return ItemDraft(
      id: item.id,
      exercise: item.exercise,
      sets: item.targetSets,
      repsMin: item.repsMin,
      repsMax: item.repsMax,
      seconds: item.targetSeconds,
      distanceKm: item.targetDistanceKm,
      weight: item.targetWeight,
      progression: item.progressionOverride,
      increment: item.incrementOverride,
      restSeconds: item.restSecondsOverride,
    );
  }

  final String id;
  Exercise exercise;
  int sets;
  int? repsMin;
  int? repsMax;
  int? seconds;
  double? distanceKm;
  double? weight;

  /// 비어 있으면 종목 기본값.
  Progression? progression;
  double? increment;
  int? restSeconds;

  RoutineItem toItem(int position) => RoutineItem(
    id: id,
    position: position,
    exercise: exercise,
    targetSets: sets,
    repsMin: repsMin,
    repsMax: repsMax,
    targetSeconds: seconds,
    targetDistanceKm: distanceKm,
    targetWeight: weight,
    progressionOverride: progression,
    incrementOverride: increment,
    restSecondsOverride: restSeconds,
  );

  Map<String, dynamic> toRow({required String dayId, required int position}) => {
    'id': id,
    'day_id': dayId,
    'position': position,
    'exercise_id': exercise.id,
    'target_sets': sets,
    'reps_min': repsMin,
    'reps_max': repsMax,
    'target_seconds': seconds,
    'target_distance_km': distanceKm,
    'target_weight': weight,
    'progression': progression?.dbValue,
    'increment': increment,
    'rest_seconds': restSeconds,
  };
}

class DayDraft {
  DayDraft({required this.id, required this.name, List<ItemDraft>? items}) : items = items ?? [];

  factory DayDraft.fromDay(RoutineDay day) =>
      DayDraft(id: day.id, name: day.name, items: [for (final item in day.items) ItemDraft.fromItem(item)]);

  final String id;
  String name;
  final List<ItemDraft> items;
}

class RoutineDraft {
  RoutineDraft({required this.id, required this.name, required this.days});

  factory RoutineDraft.fromRoutine(Routine routine) => RoutineDraft(
    id: routine.id,
    name: routine.name,
    days: [for (final day in routine.days) DayDraft.fromDay(day)],
  );

  final String id;
  String name;
  final List<DayDraft> days;

  /// 새 날의 이름: 다음 알파벳 (A, B, C …).
  String nextDayName() {
    final letter = String.fromCharCode('A'.codeUnitAt(0) + days.length % 26);
    return '$letter 새 날';
  }
}
