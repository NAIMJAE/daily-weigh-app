import 'package:daily_weigh/core/utils/local_date.dart';
import 'package:daily_weigh/core/utils/points.dart';
import 'package:daily_weigh/core/utils/storage_path.dart';
import 'package:daily_weigh/core/utils/streak.dart';
import 'package:daily_weigh/core/utils/weight.dart';
import 'package:daily_weigh/data/models/daily_record.dart';
import 'package:daily_weigh/data/models/meal_entry.dart';
import 'package:daily_weigh/data/models/profile.dart';
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
}
