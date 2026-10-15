enum WorkoutKind { gym, cardio, home, swim, ball, pilates, walk, rest }

WorkoutKind? workoutKindFrom(String? value) {
  return switch (value) {
    'gym' => WorkoutKind.gym,
    'cardio' => WorkoutKind.cardio,
    'home' => WorkoutKind.home,
    'swim' => WorkoutKind.swim,
    'ball' => WorkoutKind.ball,
    'pilates' => WorkoutKind.pilates,
    'walk' => WorkoutKind.walk,
    'rest' => WorkoutKind.rest,
    _ => null,
  };
}

extension WorkoutKindX on WorkoutKind {
  String get dbValue => name;

  String get label => switch (this) {
    WorkoutKind.gym => '헬스/웨이트',
    WorkoutKind.cardio => '러닝/유산소',
    WorkoutKind.home => '홈트레이닝',
    WorkoutKind.swim => '수영',
    WorkoutKind.ball => '구기운동',
    WorkoutKind.pilates => '필라테스/요가',
    WorkoutKind.walk => '가벼운 산책',
    WorkoutKind.rest => '휴식 데이',
  };
}

Set<WorkoutKind> workoutKindsFrom(Object? raw) {
  if (raw is! List) return {};
  return {
    for (final item in raw)
      if (workoutKindFrom('$item') != null) workoutKindFrom('$item')!,
  };
}

bool isRestOnly(Set<WorkoutKind> kinds) {
  return kinds.length == 1 && kinds.contains(WorkoutKind.rest);
}

String workoutLabel(Set<WorkoutKind> kinds) {
  return [
    for (final kind in WorkoutKind.values)
      if (kinds.contains(kind)) kind.label,
  ].join(', ');
}
