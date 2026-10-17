int reconciledStreak({
  required int streakDays,
  required String? lastAttendDate,
  required String today,
  required String yesterday,
}) {
  if (lastAttendDate == null || lastAttendDate.isEmpty) return 0;
  // 휴대폰 날짜가 서버보다 늦으면 마지막 출석이 '내일'로 보일 수 있다. 어제 이후면 이어진 것으로 본다.
  if (lastAttendDate.compareTo(yesterday) >= 0) return streakDays;
  return 0;
}
