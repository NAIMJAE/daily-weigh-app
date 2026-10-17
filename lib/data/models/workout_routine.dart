// 운동 루틴 모델 (docs/workout-routine-plan.md). DB 값은 supabase/patch-workout-routines.sql 과 같다.

enum BodyPart { chest, back, shoulder, legs, arms, core, cardio, other }

enum Equipment { barbell, dumbbell, machine, cable, bodyweight, other }

/// 기록 방식: kg×회, 회(맨몸), 시간, 시간+거리.
enum Measure { weightReps, reps, time, timeDistance }

/// 증량 방식: 무게, 더블 프로그레션(횟수 먼저 다음 무게), 횟수, 시간, 제안 안 함.
enum Progression { weight, doubleProgression, reps, time, none }

T? _byDb<T extends Enum>(List<T> values, String Function(T) db, Object? raw) {
  for (final value in values) {
    if (db(value) == raw) return value;
  }
  return null;
}

extension BodyPartX on BodyPart {
  String get dbValue => name;

  String get label => switch (this) {
    BodyPart.chest => '가슴',
    BodyPart.back => '등',
    BodyPart.shoulder => '어깨',
    BodyPart.legs => '하체',
    BodyPart.arms => '팔',
    BodyPart.core => '코어',
    BodyPart.cardio => '유산소',
    BodyPart.other => '그 밖의 운동',
  };
}

extension EquipmentX on Equipment {
  String get dbValue => name;

  String get label => switch (this) {
    Equipment.barbell => '바벨',
    Equipment.dumbbell => '덤벨',
    Equipment.machine => '머신',
    Equipment.cable => '케이블',
    Equipment.bodyweight => '맨몸',
    Equipment.other => '기구',
  };
}

extension MeasureX on Measure {
  String get dbValue => switch (this) {
    Measure.weightReps => 'weight_reps',
    Measure.reps => 'reps',
    Measure.time => 'time',
    Measure.timeDistance => 'time_distance',
  };

  String get label => switch (this) {
    Measure.weightReps => '무게 × 횟수',
    Measure.reps => '횟수',
    Measure.time => '시간',
    Measure.timeDistance => '시간 + 거리',
  };

  bool get usesWeight => this == Measure.weightReps;
  bool get usesReps => this == Measure.weightReps || this == Measure.reps;
  bool get usesTime => this == Measure.time || this == Measure.timeDistance;
  bool get usesDistance => this == Measure.timeDistance;
}

extension ProgressionX on Progression {
  String get dbValue => this == Progression.doubleProgression ? 'double' : name;

  String get label => switch (this) {
    Progression.weight => '무게 올리기',
    Progression.doubleProgression => '횟수 먼저, 다음 무게',
    Progression.reps => '횟수 올리기',
    Progression.time => '시간 올리기',
    Progression.none => '제안 안 함',
  };
}

BodyPart bodyPartFrom(Object? raw) => _byDb(BodyPart.values, (v) => v.dbValue, raw) ?? BodyPart.other;
Equipment? equipmentFrom(Object? raw) => _byDb(Equipment.values, (v) => v.dbValue, raw);
Measure measureFrom(Object? raw) => _byDb(Measure.values, (v) => v.dbValue, raw) ?? Measure.weightReps;
Progression? progressionFrom(Object? raw) => _byDb(Progression.values, (v) => v.dbValue, raw);

double? _double(Object? raw) => (raw as num?)?.toDouble();

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.measure,
    this.ownerId,
    this.equipment,
    this.progression = Progression.none,
    this.increment,
    this.restSeconds,
    this.sortOrder = 0,
  });

  final String id;

  /// 비어 있으면 앱이 주는 기본 종목.
  final String? ownerId;
  final String name;
  final BodyPart bodyPart;
  final Equipment? equipment;
  final Measure measure;
  final Progression progression;
  final double? increment;
  final int? restSeconds;
  final int sortOrder;

  bool get isBase => ownerId == null;

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String?,
      name: map['name'] as String,
      bodyPart: bodyPartFrom(map['body_part']),
      equipment: equipmentFrom(map['equipment']),
      measure: measureFrom(map['measure']),
      progression: progressionFrom(map['progression']) ?? Progression.none,
      increment: _double(map['increment']),
      restSeconds: map['rest_seconds'] as int?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}

/// 루틴 날의 종목 하나와 목표. 증량 방식·단위·쉬는 시간이 비어 있으면 종목의 기본값을 쓴다.
class RoutineItem {
  const RoutineItem({
    required this.id,
    required this.position,
    required this.exercise,
    required this.targetSets,
    this.repsMin,
    this.repsMax,
    this.targetSeconds,
    this.targetDistanceKm,
    this.targetWeight,
    this.progressionOverride,
    this.incrementOverride,
    this.restSecondsOverride,
  });

  final String id;
  final int position;
  final Exercise exercise;
  final int targetSets;
  final int? repsMin;
  final int? repsMax;
  final int? targetSeconds;
  final double? targetDistanceKm;
  final double? targetWeight;
  final Progression? progressionOverride;
  final double? incrementOverride;
  final int? restSecondsOverride;

  Progression get progression => progressionOverride ?? exercise.progression;
  double? get increment => incrementOverride ?? exercise.increment;
  int? get restSeconds => restSecondsOverride ?? exercise.restSeconds;

  /// 목표 표시: '4×8', '3×10–12', '3×최대', '3×60초', '1×20분'.
  String get targetLabel {
    final String each;
    if (exercise.measure.usesTime) {
      final seconds = targetSeconds;
      if (seconds == null) {
        each = '시간';
      } else if (seconds >= 60 && seconds % 60 == 0) {
        each = '${seconds ~/ 60}분';
      } else {
        each = '$seconds초';
      }
    } else if (repsMin == null && repsMax == null) {
      each = '최대';
    } else if (repsMin != null && repsMax != null && repsMin != repsMax) {
      each = '$repsMin–$repsMax';
    } else {
      each = '${repsMin ?? repsMax}';
    }
    return '$targetSets×$each';
  }

  factory RoutineItem.fromMap(Map<String, dynamic> map) {
    return RoutineItem(
      id: map['id'] as String,
      position: map['position'] as int,
      exercise: Exercise.fromMap(Map<String, dynamic>.from(map['exercises'] as Map)),
      targetSets: (map['target_sets'] as int?) ?? 3,
      repsMin: map['reps_min'] as int?,
      repsMax: map['reps_max'] as int?,
      targetSeconds: map['target_seconds'] as int?,
      targetDistanceKm: _double(map['target_distance_km']),
      targetWeight: _double(map['target_weight']),
      progressionOverride: progressionFrom(map['progression']),
      incrementOverride: _double(map['increment']),
      restSecondsOverride: map['rest_seconds'] as int?,
    );
  }
}

class RoutineDay {
  const RoutineDay({required this.id, required this.position, required this.name, this.items = const []});

  final String id;
  final int position;
  final String name;
  final List<RoutineItem> items;

  factory RoutineDay.fromMap(Map<String, dynamic> map) {
    final items = [
      for (final item in (map['routine_items'] as List?) ?? const [])
        RoutineItem.fromMap(Map<String, dynamic>.from(item as Map)),
    ]..sort((a, b) => a.position.compareTo(b.position));
    return RoutineDay(id: map['id'] as String, position: map['position'] as int, name: map['name'] as String, items: items);
  }
}

class Routine {
  const Routine({
    required this.id,
    required this.name,
    this.ownerId,
    this.templateKey,
    this.description,
    this.isActive = false,
    this.days = const [],
  });

  final String id;

  /// 비어 있으면 템플릿.
  final String? ownerId;
  final String? templateKey;
  final String name;
  final String? description;
  final bool isActive;
  final List<RoutineDay> days;

  bool get isTemplate => ownerId == null;

  /// 순환 분할에서 다음에 할 날. 마지막으로 완료한 날의 다음이고, 끝이면 처음으로 돌아간다.
  RoutineDay? nextDay({String? lastDayId}) {
    if (days.isEmpty) return null;
    final index = days.indexWhere((day) => day.id == lastDayId);
    if (index < 0) return days.first;
    return days[(index + 1) % days.length];
  }

  factory Routine.fromMap(Map<String, dynamic> map) {
    final days = [
      for (final day in (map['routine_days'] as List?) ?? const [])
        RoutineDay.fromMap(Map<String, dynamic>.from(day as Map)),
    ]..sort((a, b) => a.position.compareTo(b.position));
    return Routine(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String?,
      templateKey: map['template_key'] as String?,
      name: map['name'] as String,
      description: map['description'] as String?,
      isActive: (map['is_active'] as bool?) ?? false,
      days: days,
    );
  }
}

class SessionSet {
  const SessionSet({
    required this.exerciseName,
    required this.itemPosition,
    required this.setNumber,
    this.exerciseId,
    this.weightKg,
    this.reps,
    this.seconds,
    this.distanceKm,
    this.targetReps,
    this.targetSeconds,
    this.done = true,
  });

  final String? exerciseId;
  final String exerciseName;
  final int itemPosition;
  final int setNumber;
  final double? weightKg;
  final int? reps;
  final int? seconds;
  final double? distanceKm;
  final int? targetReps;
  final int? targetSeconds;
  final bool done;

  /// 볼륨에 들어가는 kg × 회.
  double get volume => done && weightKg != null && reps != null ? weightKg! * reps! : 0;

  Map<String, dynamic> toMap() => {
    'exercise_id': exerciseId,
    'exercise_name': exerciseName,
    'item_position': itemPosition,
    'set_number': setNumber,
    'weight_kg': weightKg,
    'reps': reps,
    'seconds': seconds,
    'distance_km': distanceKm,
    'target_reps': targetReps,
    'target_seconds': targetSeconds,
    'done': done,
  };

  factory SessionSet.fromMap(Map<String, dynamic> map) {
    return SessionSet(
      exerciseId: map['exercise_id'] as String?,
      exerciseName: map['exercise_name'] as String,
      itemPosition: map['item_position'] as int,
      setNumber: map['set_number'] as int,
      weightKg: _double(map['weight_kg']),
      reps: map['reps'] as int?,
      seconds: map['seconds'] as int?,
      distanceKm: _double(map['distance_km']),
      targetReps: map['target_reps'] as int?,
      targetSeconds: map['target_seconds'] as int?,
      done: (map['done'] as bool?) ?? true,
    );
  }
}

/// 완료한 운동 하나.
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.userId,
    required this.recordDate,
    required this.durationMinutes,
    this.routineId,
    this.routineDayId,
    this.dayName,
    this.startedAt,
    this.finishedAt,
    this.note,
    this.sets = const [],
  });

  final String id;
  final String userId;
  final String recordDate;
  final String? routineId;
  final String? routineDayId;
  final String? dayName;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int durationMinutes;
  final String? note;
  final List<SessionSet> sets;

  int get doneSets => sets.where((set) => set.done).length;
  int get exerciseCount => {for (final set in sets) set.itemPosition}.length;
  double get volume => sets.fold(0, (sum, set) => sum + set.volume);

  /// 주 카드 설명: 'B 당기기 · 5종목 · 52분'.
  String get summary => [
    if (dayName != null && dayName!.isNotEmpty) dayName!,
    '$exerciseCount종목',
    '$durationMinutes분',
  ].join(' · ');

  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    final sets = [
      for (final set in (map['session_sets'] as List?) ?? const []) SessionSet.fromMap(Map<String, dynamic>.from(set as Map)),
    ]..sort((a, b) {
      final byItem = a.itemPosition.compareTo(b.itemPosition);
      return byItem != 0 ? byItem : a.setNumber.compareTo(b.setNumber);
    });
    DateTime? time(Object? raw) => raw == null ? null : DateTime.tryParse(raw as String)?.toLocal();
    return WorkoutSession(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      recordDate: map['record_date'] as String,
      routineId: map['routine_id'] as String?,
      routineDayId: map['routine_day_id'] as String?,
      dayName: map['day_name'] as String?,
      startedAt: time(map['started_at']),
      finishedAt: time(map['finished_at']),
      durationMinutes: (map['duration_minutes'] as int?) ?? 0,
      note: map['note'] as String?,
      sets: sets,
    );
  }
}

/// 쉬는 시간 표시: '없음', '1분 30초', '2분'.
String restLabel(int? seconds) {
  if (seconds == null || seconds <= 0) return '없음';
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  if (minutes == 0) return '$rest초';
  return rest == 0 ? '$minutes분' : '$minutes분 $rest초';
}
