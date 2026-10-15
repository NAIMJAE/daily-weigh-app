import 'package:daily_weigh/core/utils/points.dart';
import 'package:daily_weigh/core/utils/storage_path.dart';
import 'package:daily_weigh/core/utils/streak.dart';
import 'package:daily_weigh/core/utils/weight.dart';
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

  test('체중은 0.1kg 단위로 반올림한다', () {
    expect(roundWeight('70.14'), 70.1);
    expect(roundWeight('70.16'), 70.2);
  });
}
