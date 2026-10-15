import '../constants/app_constants.dart';

String virtualEmailFor(String username) {
  return '${username.trim().toLowerCase()}@${AppConstants.virtualEmailDomain}';
}

String titleForStreak(int streakDays) {
  if (streakDays >= 30) return '꾸준';
  if (streakDays >= 7) return '성실';
  return '';
}
