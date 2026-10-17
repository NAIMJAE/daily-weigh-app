import 'package:daily_weigh/core/utils/local_date.dart';
import 'package:daily_weigh/core/utils/points.dart';
import 'package:daily_weigh/core/utils/storage_path.dart';
import 'package:daily_weigh/core/utils/streak.dart';
import 'package:daily_weigh/core/utils/weight.dart';
import 'package:daily_weigh/data/models/active_workout.dart';
import 'package:daily_weigh/data/models/daily_record.dart';
import 'package:daily_weigh/data/models/meal_entry.dart';
import 'package:daily_weigh/data/models/profile.dart';
import 'package:daily_weigh/data/models/routine_draft.dart';
import 'package:daily_weigh/data/models/workout_routine.dart';
import 'package:daily_weigh/features/records/write/meal_write_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('체중+눈바디+운동 올클리어 점수를 계산한다', () {
    expect(
      computePoints(
        const RecordScoreInput(
          hasWeight: true,
          hasBodyPhoto: true,
          hasMealPhoto: false,
          hasWorkout: true,
          isRestDay: false,
          workoutMinutes: 30,
          hasMemo: false,
        ),
      ),
      10 + 15 + 20 + 5 + 15,
    );
  });

  test('식단과 메모는 올클리어에 넣지 않는다', () {
    expect(
      computePoints(
        const RecordScoreInput(
          hasWeight: true,
          hasBodyPhoto: false,
          hasMealPhoto: true,
          hasWorkout: false,
          isRestDay: false,
          workoutMinutes: 0,
          hasMemo: true,
        ),
      ),
      10 + 15,
    );
  });

  test('휴식만 고르면 운동 점수는 있고 30분 보너스는 없다', () {
    expect(
      computePoints(
        const RecordScoreInput(
          hasWeight: true,
          hasBodyPhoto: true,
          hasMealPhoto: false,
          hasWorkout: true,
          isRestDay: true,
          workoutMinutes: 30,
          hasMemo: false,
        ),
      ),
      10 + 15 + 20 + 15,
    );
  });

  test('어제보다 오래 쉬면 스트릭은 0이다', () {
    expect(
      reconciledStreak(
        streakDays: 12,
        lastAttendDate: '2026-10-01',
        today: '2026-10-15',
        yesterday: '2026-10-14',
      ),
      0,
    );
  });

  test('서명된 사진 주소는 저장 경로로 되돌린다', () {
    expect(
      canonicalStoragePath(
        'https://example.supabase.co/storage/v1/object/sign/body-photos/user/2026-10-15.jpg?token=abc',
        'body-photos',
      ),
      'user/2026-10-15.jpg',
    );
    expect(canonicalStoragePath('user/2026-10-15.jpg', 'body-photos'), 'user/2026-10-15.jpg');
  });

  test('같은 날의 눈바디와 식단 사진은 이미지 캐시 키가 다르다', () {
    final record = DailyRecord.fromMap({
      'id': 'r1',
      'user_id': 'u1',
      'record_date': '2026-10-16',
      'body_photo_url': 'u1/2026-10-16.jpg',
      'meal_photo_url': 'u1/2026-10-16.jpg',
      'updated_at': '2026-10-16T05:00:00Z',
    });
    expect(record.bodyPhotoCacheKey, isNot(record.mealPhotoCacheKey));
  });

  test('다른 멤버가 볼 때도 끊긴 스트릭은 0으로 보이고 칭호가 없다', () {
    const stale = Profile(
      id: 'u1',
      username: 'yuna',
      nickname: '유나',
      streakDays: 12,
      lastAttendDate: '2026-01-01',
    );
    expect(stale.currentStreak, 0);
    expect(stale.title, '');
  });

  test('체중은 0.1kg 단위로 반올림한다', () {
    expect(roundWeight('70.14'), 70.1);
    expect(roundWeight('70.16'), 70.2);
  });

  test('식단 끼니는 지금 시각으로 고른다', () {
    expect(mealSlotForNow(DateTime(2026, 10, 18, 7)), MealSlot.breakfast);
    expect(mealSlotForNow(DateTime(2026, 10, 18, 10, 30)), MealSlot.lunch);
    expect(mealSlotForNow(DateTime(2026, 10, 18, 18)), MealSlot.dinner);
    expect(mealSlotForNow(DateTime(2026, 10, 18, 23)), MealSlot.snack);
  });

  test('기록은 오늘과 어제만 고칠 수 있다', () {
    final now = DateTime.now();
    expect(isEditableDay(now), isTrue);
    expect(isEditableDay(DateTime(now.year, now.month, now.day - 1)), isTrue);
    expect(isEditableDay(DateTime(now.year, now.month, now.day - 2)), isFalse);
    expect(isEditableDay(DateTime(now.year, now.month, now.day + 1)), isFalse);
  });

  test('하루 기록의 끼니 표시만 있어도 식단을 한 날로 본다', () {
    final record = DailyRecord.fromMap({'id': 'r', 'user_id': 'u', 'record_date': '2026-10-18', 'has_meal': true});
    expect(record.hasMealToday, isTrue);
    expect(record.isLogged, isTrue);
  });

  test('식단 태그는 알려진 값만 읽는다', () {
    expect(mealTagsFrom(['home', 'cheat', 'unknown']), {MealTag.home, MealTag.cheat});
  });

  test('휴대폰 날짜가 서버보다 늦어 마지막 출석이 내일로 보여도 스트릭은 이어진다', () {
    expect(
      reconciledStreak(streakDays: 5, lastAttendDate: '2026-10-18', today: '2026-10-17', yesterday: '2026-10-16'),
      5,
    );
  });

  test('루틴은 마지막으로 한 날의 다음 날을 추천하고, 끝이면 처음으로 돌아간다', () {
    const routine = Routine(
      id: 'r',
      name: '3분할',
      days: [
        RoutineDay(id: 'a', position: 1, name: 'A 밀기'),
        RoutineDay(id: 'b', position: 2, name: 'B 당기기'),
        RoutineDay(id: 'c', position: 3, name: 'C 하체'),
      ],
    );
    expect(routine.nextDay()?.id, 'a');
    expect(routine.nextDay(lastDayId: 'a')?.id, 'b');
    expect(routine.nextDay(lastDayId: 'c')?.id, 'a');
    expect(routine.nextDay(lastDayId: 'deleted')?.id, 'a');
  });

  test('루틴 종목은 비어 있는 설정에 종목 기본값을 쓰고 목표를 짧게 보여 준다', () {
    final item = RoutineItem.fromMap({
      'id': 'i',
      'position': 1,
      'target_sets': 3,
      'reps_min': 10,
      'reps_max': 12,
      'progression': null,
      'rest_seconds': 120,
      'exercises': {
        'id': 'e',
        'name': '랫풀다운',
        'body_part': 'back',
        'equipment': 'machine',
        'measure': 'weight_reps',
        'progression': 'double',
        'increment': 2.5,
        'rest_seconds': 90,
      },
    });
    expect(item.progression, Progression.doubleProgression);
    expect(item.increment, 2.5);
    expect(item.restSeconds, 120);
    expect(item.targetLabel, '3×10–12');
    expect(Progression.doubleProgression.dbValue, 'double');
  });

  test('운동 기록은 체크한 세트로 볼륨과 요약을 만든다', () {
    final session = WorkoutSession.fromMap({
      'id': 's',
      'user_id': 'u',
      'record_date': '2026-10-18',
      'day_name': 'B 당기기',
      'duration_minutes': 52,
      'session_sets': [
        {'exercise_name': '랫풀다운', 'item_position': 1, 'set_number': 2, 'weight_kg': 45, 'reps': 10},
        {'exercise_name': '랫풀다운', 'item_position': 1, 'set_number': 1, 'weight_kg': 45, 'reps': 10},
        {'exercise_name': '바벨 로우', 'item_position': 2, 'set_number': 1, 'weight_kg': 50, 'reps': 8, 'done': false},
      ],
    });
    expect(session.sets.first.setNumber, 1);
    expect(session.doneSets, 2);
    expect(session.volume, 900);
    expect(session.summary, 'B 당기기 · 2종목 · 52분');
  });

  test('루틴 운동을 완료한 날은 운동한 날이고 휴식만 한 날이 아니다', () {
    final record = DailyRecord.fromMap({
      'id': 'r',
      'user_id': 'u',
      'record_date': '2026-10-18',
      'has_session': true,
      'session_minutes': 52,
      'workout_kinds': ['rest'],
    });
    expect(record.hasWorkout, isTrue);
    expect(record.isRestOnly, isFalse);
  });

  test('새로 넣은 종목은 기록 방식에 맞는 목표로 시작한다', () {
    Exercise exercise(Measure measure, Progression progression) =>
        Exercise(id: 'e', name: '종목', bodyPart: BodyPart.chest, measure: measure, progression: progression);
    final machine = ItemDraft.fresh(exercise(Measure.weightReps, Progression.doubleProgression));
    expect((machine.sets, machine.repsMin, machine.repsMax), (3, 10, 12));
    final barbell = ItemDraft.fresh(exercise(Measure.weightReps, Progression.weight));
    expect((barbell.repsMin, barbell.repsMax), (10, 10));
    final plank = ItemDraft.fresh(exercise(Measure.time, Progression.time));
    expect((plank.sets, plank.seconds, plank.repsMin), (3, 60, null));
    final run = ItemDraft.fresh(exercise(Measure.timeDistance, Progression.none));
    expect(run.toItem(1).targetLabel, '1×20분');
  });

  test('쉬는 시간을 짧게 보여 준다', () {
    expect(restLabel(null), '없음');
    expect(restLabel(45), '45초');
    expect(restLabel(90), '1분 30초');
    expect(restLabel(180), '3분');
  });

  group('진행 중인 운동', () {
    const bench = Exercise(
      id: 'bench',
      name: '벤치프레스',
      bodyPart: BodyPart.chest,
      measure: Measure.weightReps,
      progression: Progression.weight,
      restSeconds: 150,
    );
    final day = RoutineDay(
      id: 'a',
      position: 1,
      name: 'A 밀기',
      items: [RoutineItem(id: 'i', position: 1, exercise: bench, targetSets: 3, repsMin: 8, repsMax: 8)],
    );
    final routine = Routine(id: 'r', name: '3분할', days: [day]);

    test('지난번 같은 번호 세트 값으로 채우고, 모자라면 마지막 세트 값을 쓴다', () {
      final history = [
        WorkoutSession.fromMap({
          'id': 's',
          'user_id': 'u',
          'record_date': '2026-10-16',
          'duration_minutes': 50,
          'session_sets': [
            {'exercise_id': 'bench', 'exercise_name': '벤치프레스', 'item_position': 1, 'set_number': 1, 'weight_kg': 60, 'reps': 8},
            {'exercise_id': 'bench', 'exercise_name': '벤치프레스', 'item_position': 1, 'set_number': 2, 'weight_kg': 62.5, 'reps': 6},
          ],
        }),
      ];
      final workout = ActiveWorkout.fromDay(
        routine: routine,
        day: day,
        recordDate: '2026-10-18',
        live: true,
        history: history,
      );
      final sets = workout.exercises.single.sets;
      expect([for (final set in sets) (set.weightKg, set.reps)], [(60.0, 8), (62.5, 6), (62.5, 6)]);
      expect(workout.exercises.single.lastSummary, '62.5kg × 6');
      expect(workout.exercises.single.restSeconds, 150);
    });

    test('처음 하는 종목은 루틴 목표로 채우고 무게는 비워 둔다', () {
      final workout = ActiveWorkout.fromDay(routine: routine, day: day, recordDate: '2026-10-18', live: true, history: const []);
      final set = workout.exercises.single.sets.first;
      expect((set.weightKg, set.reps, set.done), (null, 8, false));
      expect(workout.exercises.single.lastSummary, isNull);
    });

    test('휴대폰에 저장했다 다시 읽어도 같은 운동이다', () {
      final workout = ActiveWorkout.fromDay(
        routine: routine,
        day: day,
        recordDate: '2026-10-18',
        live: true,
        history: const [],
        now: DateTime(2026, 10, 18, 19),
      );
      workout.exercises.single.sets.first
        ..weightKg = 60
        ..done = true;
      final restored = ActiveWorkout.fromJson(workout.toJson());
      expect(restored.dayName, 'A 밀기');
      expect(restored.startedAt, DateTime(2026, 10, 18, 19));
      expect(restored.doneSets, 1);
      expect(restored.exercises.single.sets.first.weightKg, 60);
      expect(restored.minutesAt(DateTime(2026, 10, 18, 19, 52)), 52);
    });

    test('저장할 세트는 순서를 매기고 체크하지 않은 세트도 남긴다', () {
      final workout = ActiveWorkout.fromDay(routine: routine, day: day, recordDate: '2026-10-18', live: false, history: const []);
      workout.exercises.single.sets.first.done = true;
      final sets = workout.toSessionSets();
      expect([for (final set in sets) (set.setNumber, set.done)], [(1, true), (2, false), (3, false)]);
      expect(sets.first.targetReps, 8);
      expect(workout.minutesAt(DateTime(2026, 10, 18)), 60);
    });

    test('세트를 체크하면 뒤쪽 빈 세트에 무게를 채우고, 적어 둔 값은 그대로 둔다', () {
      final workout = ActiveWorkout.fromDay(routine: routine, day: day, recordDate: '2026-10-18', live: true, history: const []);
      final exercise = workout.exercises.single;
      exercise.sets[2].weightKg = 55;
      exercise.sets[0]
        ..weightKg = 60
        ..done = true;
      exercise.fillAfter(exercise.sets[0]);
      expect([for (final set in exercise.sets) set.weightKg], [60, 60, 55]);
      expect(exercise.sets[1].fills, 1);
      expect(exercise.sets[2].fills, 0);
    });

    test('일회성 운동은 종목 없이 시작하고 루틴에 묶이지 않는다', () {
      final workout = ActiveWorkout.free(recordDate: '2026-10-18', live: true, now: DateTime(2026, 10, 18, 7));
      expect(workout.exercises, isEmpty);
      expect((workout.routineId, workout.routineDayId), (null, null));
      expect(workout.dayName, '일회성 운동');
      workout.exercises.add(
        ActiveExercise.added(
          const Exercise(id: 'run', name: '러닝머신', bodyPart: BodyPart.cardio, measure: Measure.timeDistance),
          const [],
        ),
      );
      expect(workout.exercises.single.sets.single.seconds, 1200);
    });
  });

  group('운동 요약', () {
    WorkoutSession session(String id, String date, List<Map<String, dynamic>> sets) => WorkoutSession.fromMap({
      'id': id,
      'user_id': 'u',
      'record_date': date,
      'duration_minutes': 40,
      'session_sets': sets,
    });
    Map<String, dynamic> set(String exercise, int position, int number, {num? kg, int? reps, int? seconds, bool done = true}) => {
      'exercise_id': exercise,
      'exercise_name': exercise,
      'item_position': position,
      'set_number': number,
      'weight_kg': kg,
      'reps': reps,
      'seconds': seconds,
      'done': done,
    };

    test('지난 최고보다 무거우면 개인 최고 기록이고, 체크하지 않은 세트와 처음 하는 종목은 뺀다', () {
      final before = session('old', '2026-10-15', [set('벤치프레스', 1, 1, kg: 60, reps: 8), set('풀업', 2, 1, reps: 8)]);
      final now = session('new', '2026-10-18', [
        set('벤치프레스', 1, 1, kg: 62.5, reps: 6),
        set('벤치프레스', 1, 2, kg: 70, reps: 1, done: false),
        set('풀업', 2, 1, reps: 8),
        set('플랭크', 3, 1, seconds: 60),
      ]);
      final records = personalRecords(now, [before]);
      expect(records.length, 1);
      expect((records.single.exerciseName, records.single.previousLabel, records.single.label), ('벤치프레스', '60kg', '62.5kg'));
    });

    test('세트는 운동한 종목 순서로 묶고 한 칸씩 짧게 보여 준다', () {
      final now = session('s', '2026-10-18', [
        set('플랭크', 2, 1, seconds: 60),
        set('벤치프레스', 1, 2, kg: 60, reps: 8),
        set('벤치프레스', 1, 1, kg: 60, reps: 8),
      ]);
      final groups = setsByExercise(now);
      expect([for (final group in groups) group.$1], ['벤치프레스', '플랭크']);
      expect(groups.first.$2.first.label, '60kg × 8');
      expect(groups.last.$2.single.label, '1분');
    });
  });
}
