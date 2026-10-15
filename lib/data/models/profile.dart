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

  String get title => titleForStreak(streakDays);

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
