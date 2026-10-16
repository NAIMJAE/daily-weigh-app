import '../../core/utils/local_date.dart';
import '../../core/utils/streak.dart';
import '../../core/utils/virtual_email.dart';

class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.nickname,
    this.height,
    this.startWeight,
    this.targetWeight,
    this.walletPoints = 0,
    this.streakDays = 0,
    this.lastAttendDate,
  });

  final String id;
  final String username;
  final String nickname;
  final double? height;
  final double? startWeight;
  final double? targetWeight;
  final int walletPoints;
  final int streakDays;
  final String? lastAttendDate;

  bool get hasBodyInfo {
    return height != null && startWeight != null && targetWeight != null;
  }

  /// 화면에 보여 줄 스트릭. DB 값은 본인이 앱을 열 때만 0으로 정리되므로,
  /// 다른 멤버가 볼 때도 마지막 출석이 오늘·어제가 아니면 끊긴 것으로 본다.
  int get currentStreak {
    final now = DateTime.now();
    return reconciledStreak(
      streakDays: streakDays,
      lastAttendDate: lastAttendDate,
      today: localDateString(now),
      yesterday: localDateString(DateTime(now.year, now.month, now.day - 1)),
    );
  }

  String get title => titleForStreak(currentStreak);

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      username: map['username'] as String,
      nickname: map['nickname'] as String,
      height: (map['height'] as num?)?.toDouble(),
      startWeight: (map['start_weight'] as num?)?.toDouble(),
      targetWeight: (map['target_weight'] as num?)?.toDouble(),
      walletPoints: (map['wallet_points'] as int?) ?? 0,
      streakDays: (map['streak_days'] as int?) ?? 0,
      lastAttendDate: map['last_attend_date'] as String?,
    );
  }
}
