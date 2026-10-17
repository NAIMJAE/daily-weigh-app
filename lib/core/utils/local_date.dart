String localDateString([DateTime? date]) {
  final value = date ?? DateTime.now();
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime parseLocalDate(String value) {
  final parts = value.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

DateTime startOfWeekMonday(DateTime date) {
  return DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - DateTime.monday));
}

DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month, 1);

DateTime startOfYear(DateTime date) => DateTime(date.year, 1, 1);

/// 기록은 오늘과 어제만 쓰고 고칠 수 있다.
bool isEditableDay(DateTime date) {
  final now = DateTime.now();
  final key = localDateString(date);
  return key == localDateString(now) || key == localDateString(DateTime(now.year, now.month, now.day - 1));
}
