import '../../core/utils/storage_path.dart';
import 'workout.dart';

class DailyRecord {
  const DailyRecord({
    required this.id,
    required this.userId,
    required this.recordDate,
    this.weight,
    this.bodyPhotoPath,
    this.mealPhotoPath,
    this.bodyPhotoUrl,
    this.mealPhotoUrl,
    this.workoutMinutes,
    this.workoutKinds = const {},
    this.memo,
    this.hasMeal = false,
    this.hasSession = false,
    this.sessionMinutes,
    this.pointsEarned = 0,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String recordDate;
  final double? weight;
  final String? bodyPhotoPath;
  final String? mealPhotoPath;
  final String? bodyPhotoUrl;
  final String? mealPhotoUrl;
  final int? workoutMinutes;
  final Set<WorkoutKind> workoutKinds;
  final String? memo;

  /// 끼니별 식단(meal_entries)이 하나라도 있는 날. 서버 트리거가 맞춘다.
  final bool hasMeal;

  /// 루틴 운동(workout_sessions)을 완료한 날과 그 날 운동 시간 합. 서버 트리거가 맞춘다.
  final bool hasSession;
  final int? sessionMinutes;
  final int pointsEarned;
  final DateTime? updatedAt;

  bool get hasMealToday => hasMeal || _present(mealPhotoPath) || _present(mealPhotoUrl);
  bool get hasBodyPhoto => _present(bodyPhotoPath) || _present(bodyPhotoUrl);
  bool get hasWorkout => hasSession || workoutKinds.isNotEmpty;
  bool get isRestOnly => !hasSession && isRestOnlyKinds(workoutKinds);
  bool get isLogged =>
      weight != null || hasBodyPhoto || hasMealToday || hasWorkout || (memo != null && memo!.trim().isNotEmpty);

  String get workoutSummary => workoutLabel(workoutKinds);

  // 서명 URL은 받을 때마다 바뀌므로 이미지 캐시는 저장 경로와 수정 시각으로 찾는다.
  // 눈바디와 식단은 버킷만 다르고 경로(사용자/날짜.jpg)가 같으므로 버킷 이름을 키에 넣는다.
  String? get bodyPhotoCacheKey => _cacheKey('body-photos', bodyPhotoPath);
  String? get mealPhotoCacheKey => _cacheKey('meal-photos', mealPhotoPath);

  String? _cacheKey(String bucket, String? path) {
    if (!_present(path)) return null;
    return '$bucket/$path#${updatedAt?.millisecondsSinceEpoch ?? 0}';
  }

  DailyRecord copyWith({String? bodyPhotoUrl, String? mealPhotoUrl}) {
    return DailyRecord(
      id: id,
      userId: userId,
      recordDate: recordDate,
      weight: weight,
      bodyPhotoPath: bodyPhotoPath,
      mealPhotoPath: mealPhotoPath,
      bodyPhotoUrl: bodyPhotoUrl ?? this.bodyPhotoUrl,
      mealPhotoUrl: mealPhotoUrl ?? this.mealPhotoUrl,
      workoutMinutes: workoutMinutes,
      workoutKinds: workoutKinds,
      memo: memo,
      hasMeal: hasMeal,
      hasSession: hasSession,
      sessionMinutes: sessionMinutes,
      pointsEarned: pointsEarned,
      updatedAt: updatedAt,
    );
  }

  factory DailyRecord.fromMap(Map<String, dynamic> map) {
    return DailyRecord(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      recordDate: map['record_date'] as String,
      weight: (map['weight'] as num?)?.toDouble(),
      bodyPhotoPath: canonicalStoragePath(map['body_photo_url'] as String?, 'body-photos'),
      mealPhotoPath: canonicalStoragePath(map['meal_photo_url'] as String?, 'meal-photos'),
      workoutMinutes: map['workout_minutes'] as int?,
      workoutKinds: workoutKindsFrom(map['workout_kinds']),
      memo: map['memo'] as String?,
      hasMeal: (map['has_meal'] as bool?) ?? false,
      hasSession: (map['has_session'] as bool?) ?? false,
      sessionMinutes: map['session_minutes'] as int?,
      pointsEarned: (map['points_earned'] as int?) ?? 0,
      updatedAt: map['updated_at'] == null ? null : DateTime.tryParse(map['updated_at'] as String),
    );
  }
}

bool isRestOnlyKinds(Set<WorkoutKind> kinds) => isRestOnly(kinds);

bool _present(String? value) => value != null && value.isNotEmpty;
