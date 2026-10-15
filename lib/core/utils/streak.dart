int reconciledStreak({
  required int streakDays,
  required String? lastAttendDate,
  required String today,
  required String yesterday,
}) {
  if (lastAttendDate == null || lastAttendDate.isEmpty) return 0;
  if (lastAttendDate == today || lastAttendDate == yesterday) return streakDays;
  return 0;
}
