import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/daily_record.dart';
import '../../data/models/profile.dart';

const weightLineColors = [
  AppColors.accent,
  Color(0xFF2563EB),
  Color(0xFF059669),
  Color(0xFF7C3AED),
  Color(0xFFDB2777),
  Color(0xFFCA8A04),
  Color(0xFF0F766E),
  Color(0xFF111111),
];

class WeightChart extends StatelessWidget {
  const WeightChart({
    super.key,
    required this.records,
    required this.allRecords,
    required this.profiles,
    required this.absolute,
  });

  final List<DailyRecord> records;
  final List<DailyRecord> allRecords;
  final Map<String, Profile> profiles;
  final bool absolute;

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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text('체중 기록이 없습니다.')),
      );
    }
    final index = {for (var i = 0; i < dates.length; i++) dates[i]: i.toDouble()};
    final userIds = weighed.map((record) => record.userId).toSet().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (!absolute) HorizontalLine(y: 0, color: AppColors.line, strokeWidth: 1),
                ],
              ),
              lineBarsData: [
                for (var i = 0; i < userIds.length; i++)
                  LineChartBarData(
                    spots: [
                      for (final record in weighed.where((item) => item.userId == userIds[i]))
                        FlSpot(
                          index[record.recordDate]!,
                          absolute ? record.weight! : record.weight! - _baseline(userIds[i]),
                        ),
                    ],
                    color: weightLineColors[i % weightLineColors.length],
                    isCurved: true,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            for (var i = 0; i < userIds.length; i++)
              Text(
                profiles[userIds[i]]?.nickname ?? '멤버',
                style: TextStyle(
                  color: weightLineColors[i % weightLineColors.length],
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
