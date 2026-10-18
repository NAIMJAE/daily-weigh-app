import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/daily_record.dart';
import '../../data/models/meal_entry.dart';
import '../../data/models/workout_routine.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_title.dart';

// ---------------------------------------------------------------------------
// 식사 종류 비율
// ---------------------------------------------------------------------------

extension MealCategoryColor on MealCategory {
  Color get color => switch (this) {
    MealCategory.home => AppColors.chartSeries[2],
    MealCategory.eatout => AppColors.chartSeries[0],
    MealCategory.delivery => AppColors.chartSeries[3],
    MealCategory.salad => AppColors.chartSeries[6],
    MealCategory.simple => AppColors.chartSeries[4],
    MealCategory.cheat => AppColors.chartSeries[1],
  };
}

/// 종류마다 끼니 수. 많은 종류가 앞에 오고, 같으면 종류 순서를 따른다. 종류 없는 끼니는 세지 않는다.
List<(MealCategory, int)> mealCategoryCounts(Iterable<MealEntry> entries) {
  final counts = <MealCategory, int>{};
  for (final entry in entries) {
    final category = entry.category;
    if (category != null) counts[category] = (counts[category] ?? 0) + 1;
  }
  return [
    for (final category in MealCategory.values)
      if (counts[category] != null) (category, counts[category]!),
  ]..sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.index.compareTo(b.$1.index));
}

class MealCategoryCard extends StatelessWidget {
  const MealCategoryCard({super.key, required this.entries});

  /// 기간 안의 끼니.
  final List<MealEntry> entries;

  @override
  Widget build(BuildContext context) {
    final counts = mealCategoryCounts(entries);
    final total = counts.fold(0, (sum, item) => sum + item.$2);
    final unsorted = entries.length - total;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('식사 종류 비율', icon: Icons.pie_chart_outline),
          const SizedBox(height: 12),
          if (total == 0)
            const SizedBox(
              height: 120,
              child: Center(child: Text('이 기간에 식사 종류를 고른 끼니가 없어요.', style: AppText.label)),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 132,
                  height: 132,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          startDegreeOffset: -90,
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                          pieTouchData: PieTouchData(enabled: false),
                          sections: [
                            for (final (category, count) in counts)
                              PieChartSectionData(
                                value: count.toDouble(),
                                color: category.color,
                                radius: 24,
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$total', style: AppText.number(size: 20)),
                          const Text('끼니', style: AppText.caption),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.card),
                Expanded(
                  child: Column(
                    children: [
                      for (final (category, count) in counts)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(color: category.color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(category.label, style: AppText.body)),
                              NumText(
                                '$count끼',
                                style: AppText.number(size: 12, weight: FontWeight.w500, color: AppColors.muted),
                              ),
                              SizedBox(
                                width: 44,
                                child: NumText(
                                  '${(count * 100 / total).round()}%',
                                  textAlign: TextAlign.end,
                                  style: AppText.number(size: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          if (unsorted > 0) ...[
            const SizedBox(height: 10),
            Text('종류를 고르지 않은 끼니 $unsorted개는 빼고 셌어요.', style: AppText.caption),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 기간과 칸
// ---------------------------------------------------------------------------

/// 그래프 한 칸이 묶는 길이. 주 보기는 하루, 월 보기는 한 주, 연 보기는 한 달이다.
enum StatsUnit { day, week, month }

/// 직접 고른 기간은 묶지 않고 하루마다 보여 준다. 그래프가 읽히도록 길이를 30일까지로 둔다.
const maxCustomDays = 30;

/// 30일보다 긴 기간은 시작일부터 30일로 자른다.
DateTimeRange clampCustomRange(DateTimeRange range) {
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(range.end.year, range.end.month, range.end.day);
  final limit = DateTime(start.year, start.month, start.day + maxCustomDays - 1);
  return DateTimeRange(start: start, end: end.isAfter(limit) ? limit : end);
}

DateTime bucketStart(DateTime date, StatsUnit unit) => switch (unit) {
  StatsUnit.day => DateTime(date.year, date.month, date.day),
  StatsUnit.week => startOfWeekMonday(date),
  StatsUnit.month => DateTime(date.year, date.month),
};

DateTime _nextBucket(DateTime start, StatsUnit unit) => switch (unit) {
  StatsUnit.day => DateTime(start.year, start.month, start.day + 1),
  StatsUnit.week => DateTime(start.year, start.month, start.day + 7),
  StatsUnit.month => DateTime(start.year, start.month + 1),
};

/// 칸 이름. 주 칸이 기간 시작보다 앞서 시작하면 기간 시작일로 적는다(달 보기의 첫 주는 1일부터).
String bucketLabel(DateTime start, StatsUnit unit, DateTimeRange range) {
  switch (unit) {
    case StatsUnit.day:
      return '${start.month}.${start.day}';
    case StatsUnit.week:
      final shown = start.isBefore(range.start) ? range.start : start;
      return '${shown.month}.${shown.day}';
    case StatsUnit.month:
      return range.start.year != range.end.year ? '${start.year % 100}.${start.month}' : '${start.month}월';
  }
}

String unitAverageLabel(StatsUnit unit) => switch (unit) {
  StatsUnit.day => '하루 기록',
  StatsUnit.week => '주별 평균',
  StatsUnit.month => '월별 평균',
};

/// 체중을 칸마다 사람별로 평균 낸다. 하루 칸이면 그대로 둔다.
/// 평균 기록의 날짜는 칸 시작일이다(주 칸은 기간 시작일보다 앞설 수 있다).
List<DailyRecord> averageWeights(List<DailyRecord> records, StatsUnit unit) {
  if (unit == StatsUnit.day) return records;
  final sums = <(String, String), (double, int)>{};
  for (final record in records) {
    final weight = record.weight;
    if (weight == null) continue;
    final key = (record.userId, localDateString(bucketStart(parseLocalDate(record.recordDate), unit)));
    final (sum, count) = sums[key] ?? (0.0, 0);
    sums[key] = (sum + weight, count + 1);
  }
  return [
    for (final MapEntry(key: (userId, date), value: (sum, count)) in sums.entries)
      DailyRecord.fromMap({
        'id': '$userId/$date',
        'user_id': userId,
        'record_date': date,
        'weight': (sum / count * 10).round() / 10,
      }),
  ]..sort((a, b) => a.recordDate.compareTo(b.recordDate));
}

// ---------------------------------------------------------------------------
// 볼륨 추이
// ---------------------------------------------------------------------------

class VolumeBucket {
  const VolumeBucket({required this.start, required this.label, required this.volume, this.sessions = 0});

  final DateTime start;
  final String label;
  final double volume;

  /// 볼륨이 있는 운동 수. 칸마다 운동 횟수가 달라도 비교하려고 한 번 평균을 낸다.
  final int sessions;

  double get perSession => sessions == 0 ? 0 : volume / sessions;
}

/// 운동 볼륨(무게×횟수)을 [range] 안의 날·주·달 칸으로 나눠 더한다. 운동 없는 칸은 0이다.
List<VolumeBucket> volumeBuckets(
  List<WorkoutSession> sessions, {
  required StatsUnit unit,
  required DateTimeRange range,
}) {
  final byStart = <DateTime, double>{};
  final counts = <DateTime, int>{};
  for (final session in sessions) {
    final key = bucketStart(parseLocalDate(session.recordDate), unit);
    byStart[key] = (byStart[key] ?? 0) + session.volume;
    if (session.volume > 0) counts[key] = (counts[key] ?? 0) + 1;
  }
  final last = bucketStart(range.end, unit);
  return [
    for (var start = bucketStart(range.start, unit); !start.isAfter(last); start = _nextBucket(start, unit))
      VolumeBucket(
        start: start,
        label: bucketLabel(start, unit, range),
        volume: byStart[start] ?? 0,
        sessions: counts[start] ?? 0,
      ),
  ];
}

String formatKg(double value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${buffer}kg';
}

String _axisKg(double value) {
  if (value >= 1000) {
    final tons = value / 1000;
    return '${tons == tons.roundToDouble() ? tons.toStringAsFixed(0) : tons.toStringAsFixed(1)}t';
  }
  return value.toStringAsFixed(0);
}

class VolumeTrendCard extends StatelessWidget {
  const VolumeTrendCard({super.key, required this.sessions, required this.buckets});

  /// 기간 안의 운동.
  final List<WorkoutSession> sessions;
  final List<VolumeBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final total = sessions.fold(0.0, (sum, session) => sum + session.volume);
    final counted = sessions.where((session) => session.volume > 0).length;
    final peak = buckets.fold(0.0, (top, bucket) => max(top, bucket.volume));
    // 축 눈금은 1, 2, 5 단위로 4칸쯤 나온다.
    final rough = peak <= 0 ? 1000.0 : peak / 4;
    final magnitude = pow(10, (log(rough) / ln10).floor()).toDouble();
    final step = [1, 2, 5, 10].map((m) => m * magnitude).firstWhere((s) => s >= rough);
    final maxY = max(step, (peak / step).ceil() * step);
    final labelEvery = max(1, (buckets.length / 7).ceil());

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('볼륨 추이', icon: Icons.bar_chart),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              NumText(formatKg(total), style: AppText.number(size: 22, color: AppColors.accent)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: NumText('운동 $counted번', style: AppText.label),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('세트마다 무게×횟수를 더했어요. 무게 없는 세트(맨몸·유산소)는 빠져요.', style: AppText.caption),
          const SizedBox(height: 16),
          if (total <= 0)
            const SizedBox(
              height: 160,
              child: Center(child: Text('이 기간에 무게를 기록한 운동이 없어요.', style: AppText.label)),
            )
          else
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: step,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: AppColors.line, strokeWidth: 1, dashArray: [3, 3]),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: step,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _axisKg(value),
                            style: AppText.number(size: 9.5, weight: FontWeight.w500, color: AppColors.faint),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          final i = value.round();
                          if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
                          if (i % labelEvery != 0 && i != buckets.length - 1) return const SizedBox.shrink();
                          if (i != buckets.length - 1 && buckets.length - 1 - i < labelEvery) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              buckets[i].label,
                              style: AppText.number(size: 9.5, weight: FontWeight.w500, color: AppColors.faint),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    // 막대를 정확히 누르지 않아도 그 칸의 위아래 어디든 대면 값이 보인다.
                    touchExtraThreshold: const EdgeInsets.fromLTRB(8, 400, 8, 24),
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.ink,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                        '${buckets[group.x].label}  ${formatKg(rod.toY)}',
                        const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < buckets.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: buckets[i].volume,
                            width: buckets.length > 20 ? 6 : (buckets.length > 8 ? 12 : 20),
                            color: AppColors.accent,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
