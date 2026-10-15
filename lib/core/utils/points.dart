import '../constants/app_constants.dart';

class RecordScoreInput {
  const RecordScoreInput({
    required this.hasWeight,
    required this.hasBodyPhoto,
    required this.hasMealPhoto,
    required this.hasWorkout,
    required this.isRestDay,
    required this.workoutMinutes,
    required this.hasMemo,
  });

  final bool hasWeight;
  final bool hasBodyPhoto;
  final bool hasMealPhoto;
  final bool hasWorkout;
  final bool isRestDay;
  final int workoutMinutes;
  final bool hasMemo;

  bool get isAttendance {
    return hasWeight || hasBodyPhoto || hasMealPhoto || hasWorkout || hasMemo;
  }
}

int computePoints(RecordScoreInput input) {
  if (!input.isAttendance) return 0;
  var points = 0;
  if (input.hasWeight) points += PointRules.weight;
  if (input.hasBodyPhoto) points += PointRules.bodyPhoto;
  if (input.hasMealPhoto) points += PointRules.mealPhoto;
  if (input.hasWorkout) {
    points += PointRules.workout;
    if (!input.isRestDay &&
        input.workoutMinutes >= PointRules.longWorkoutMinutes) {
      points += PointRules.longWorkoutBonus;
    }
  }
  final allClear = input.hasWeight && input.hasBodyPhoto && input.hasWorkout;
  if (allClear) points += PointRules.allClear;
  return points;
}
