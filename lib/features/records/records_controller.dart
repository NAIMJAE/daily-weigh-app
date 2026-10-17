import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/local_date.dart';
import '../../data/models/daily_record.dart';
import '../../data/models/meal_entry.dart';
import '../home/home_controller.dart';
import '../session/session_controller.dart';

/// 내 하루 기록 (눈바디·운동 화면). 날짜 문자열로 찾는다.
final myDailyRecordsProvider = FutureProvider<Map<String, DailyRecord>>((ref) async {
  ref.watch(recordRevisionProvider);
  final userId = (await ref.watch(sessionProvider.future)).userId;
  if (userId == null) return {};
  final records = await ref.read(recordRepositoryProvider).fetchForUser(userId);
  return {for (final record in records) record.recordDate: record};
});

/// 내 끼니별 식단 기록. 키는 '날짜/끼니'.
final myMealEntriesProvider = FutureProvider<Map<String, MealEntry>>((ref) async {
  ref.watch(recordRevisionProvider);
  final userId = (await ref.watch(sessionProvider.future)).userId;
  if (userId == null) return {};
  final entries = await ref.read(recordRepositoryProvider).fetchMealEntries(userId);
  return {for (final entry in entries) mealKey(entry.recordDate, entry.slot): entry};
});

String mealKey(String date, MealSlot slot) => '$date/${slot.dbValue}';

bool isPastDay(DateTime date) => localDateString(date).compareTo(localDateString()) < 0;
