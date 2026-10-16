import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/daily_record.dart';
import '../../data/models/profile.dart';
import 'ui_parts.dart';

/// 멤버별 체중 선 그래프 (웹 '체중 변화 그래프'와 같은 구성: 범례 칩, 축, 점선 격자, 0kg 기준선).
class WeightChart extends StatelessWidget {
  const WeightChart({
    super.key,
    required this.records,
    required this.allRecords,
    required this.profiles,
    required this.absolute,
    this.myId,
    this.height = 200,
  });

  final List<DailyRecord> records;
  final List<DailyRecord> allRecords;
  final Map<String, Profile> profiles;
  final bool absolute;
  final String? myId;
  final double height;

  /// 변화량의 0점: 프로필의 시작 체중, 없으면 가장 오래된 체중.
  double _baseline(String userId) {
    final profile = profiles[userId];
    if (profile?.startWeight != null) return profile!.startWeight!;
    final history = allRecords.where((record) => record.userId == userId && record.weight != null).toList()
      ..sort((a, b) => a.recordDate.compareTo(b.recordDate));
    return history.isEmpty ? 0 : history.first.weight!;
  }

  @override
  Widget build(BuildContext context) {
    final weighed = records.where((record) => record.weight != null).toList();
    final dates = weighed.map((record) => record.recordDate).toSet().toList()..sort();
    if (dates.isEmpty) {
      return SizedBox(
        height: height * 0.6,
        child: const Center(child: Text('이 기간에 체중 기록이 없습니다.', style: AppText.label)),
      );
    }
    final index = {for (var i = 0; i < dates.length; i++) dates[i]: i.toDouble()};
    // 내 선을 첫 번째 색으로.
    final userIds = weighed.map((record) => record.userId).toSet().toList()
      ..sort((a, b) => (b == myId ? 1 : 0) - (a == myId ? 1 : 0));
    Color colorOf(int i) => AppColors.chartSeries[i % AppColors.chartSeries.length];

    final bars = <LineChartBarData>[];
    var minY = double.infinity;
    var maxY = -double.infinity;
    for (var i = 0; i < userIds.length; i++) {
      final base = _baseline(userIds[i]);
      final spots = [
        for (final record in weighed.where((item) => item.userId == userIds[i]))
          FlSpot(index[record.recordDate]!, absolute ? record.weight! : record.weight! - base),
      ]..sort((a, b) => a.x.compareTo(b.x));
      for (final s in spots) {
        minY = min(minY, s.y);
        maxY = max(maxY, s.y);
      }
      bars.add(
        LineChartBarData(
          spots: spots,
          color: colorOf(i),
          isCurved: true,
          curveSmoothness: 0.25,
          preventCurveOverShooting: true,
          barWidth: 1.6,
          dotData: FlDotData(
            show: dates.length <= 40,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 2.4,
              color: Colors.white,
              strokeWidth: 1.4,
              strokeColor: bar.color ?? AppColors.ink,
            ),
          ),
        ),
      );
    }
    if (!absolute) {
      minY = min(minY, 0);
      maxY = max(maxY, 0);
    }
    final step = _niceStep((maxY - minY) / 4);
    final lo = (minY / step).floor() * step;
    final hi = (maxY / step).ceil() * step;
    final labelEvery = max(1, (dates.length / 6).ceil());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < userIds.length; i++)
              LegendChip(color: colorOf(i), label: profiles[userIds[i]]?.nickname ?? '멤버'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: lo == hi ? lo - step : lo,
              maxY: lo == hi ? hi + step : hi,
              minX: 0,
              maxX: max(1, dates.length - 1).toDouble(),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                horizontalInterval: step,
                verticalInterval: labelEvery.toDouble(),
                getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.line, strokeWidth: 1, dashArray: [3, 3]),
                getDrawingVerticalLine: (_) => const FlLine(color: AppColors.line, strokeWidth: 1, dashArray: [3, 3]),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: step,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min || value == meta.max) {
                        if ((value - lo).abs() > 1e-6 && (value - hi).abs() > 1e-6) return const SizedBox.shrink();
                      }
                      final text = absolute
                          ? value.toStringAsFixed(step < 1 ? 1 : 0)
                          : '${value > 0 ? '+' : ''}${value.toStringAsFixed(step < 1 ? 1 : 0)}';
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          text,
                          style: AppText.number(size: 9.5, weight: FontWeight.w500, color: AppColors.faint),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if ((value - i).abs() > 1e-6 || i < 0 || i >= dates.length) return const SizedBox.shrink();
                      final last = i == dates.length - 1;
                      if (i % labelEvery != 0 && !last) return const SizedBox.shrink();
                      if (!last && dates.length - 1 - i < labelEvery / 2) return const SizedBox.shrink();
                      final d = parseLocalDate(dates[i]);
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          '${d.month}.${d.day}',
                          style: AppText.number(size: 9.5, weight: FontWeight.w500, color: AppColors.faint),
                        ),
                      );
                    },
                  ),
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (!absolute)
                    HorizontalLine(
                      y: 0,
                      color: AppColors.faint.withValues(alpha: 0.6),
                      strokeWidth: 1,
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: const TextStyle(fontSize: 10, color: AppColors.faint),
                        labelResolver: (_) => '0kg 기준',
                      ),
                    ),
                ],
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.ink,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        '${profiles[userIds[s.barIndex]]?.nickname ?? '멤버'} '
                        '${absolute ? '${s.y.toStringAsFixed(1)}kg' : '${s.y >= 0 ? '+' : ''}${s.y.toStringAsFixed(1)}kg'}',
                        TextStyle(color: colorOf(s.barIndex), fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
              lineBarsData: bars,
            ),
          ),
        ),
      ],
    );
  }

  static double _niceStep(double raw) {
    if (raw <= 0 || raw.isNaN) return 0.5;
    final exp = pow(10, (log(raw) / ln10).floor()).toDouble();
    final f = raw / exp;
    final nice = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 2.5 ? 2.5 : (f <= 5 ? 5 : 10)));
    return nice * exp;
  }
}
