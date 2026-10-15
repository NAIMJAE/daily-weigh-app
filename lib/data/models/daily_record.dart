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
  final int pointsEarned;
  final DateTime? updatedAt;

  bool get hasMealToday => _present(mealPhotoPath) || _present(mealPhotoUrl);
  bool get hasBodyPhoto => _present(bodyPhotoPath) || _present(bodyPhotoUrl);
  bool get hasWorkout => workoutKinds.isNotEmpty;
  bool get isRestOnly => isRestOnlyKinds(workoutKinds);
  bool get isLogged =>
      weight != null ||
      hasBodyPhoto ||
      hasMealToday ||
      hasWorkout ||
      (memo != null && memo!.trim().isNotEmpty);

  String get workoutSummary => workoutLabel(workoutKinds);

  DailyRecord copyWith({
    String? bodyPhotoUrl,
    String? mealPhotoUrl,
  }) {
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
      pointsEarned: (map['points_earned'] as int?) ?? 0,
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.tryParse(map['updated_at'] as String),
    );
  }
}

bool isRestOnlyKinds(Set<WorkoutKind> kinds) => isRestOnly(kinds);

bool _present(String? value) => value != null && value.isNotEmpty;
