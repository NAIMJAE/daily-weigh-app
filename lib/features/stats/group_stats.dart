import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/meal_entry.dart';
import '../../data/models/workout_routine.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/hover_detail.dart';
import '../../shared/widgets/section_title.dart';
import '../../shared/widgets/ui_parts.dart';
import 'record_stats.dart';

/// 통계에서 비교하는 그룹 멤버 한 명. 색은 체중 그래프와 같은 순서(나 먼저)로 정한다.
class StatsMember {
  const StatsMember({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final Color color;
}

// ---------------------------------------------------------------------------
// 멤버별 식사 종류
// ---------------------------------------------------------------------------

class MemberMealCategoryCard extends StatelessWidget {
  const MemberMealCategoryCard({super.key, required this.members, required this.entries});

  final List<StatsMember> members;

  /// 기간 안의 모든 멤버 끼니.
  final List<MealEntry> entries;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('멤버별 식사 종류', icon: Icons.pie_chart_outline),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              for (final category in MealCategory.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: category.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(category.label, style: AppText.caption),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          for (final member in members) ...[
            _MemberMealRow(
              member: member,
              entries: [for (final entry in entries) if (entry.userId == member.id) entry],
            ),
            const SizedBox(height: 12),
          ],
          const Text('끼니 수가 달라도 비교되도록 각자의 비율로 그렸어요. 막대에 손가락을 대면 내역이 보여요.', style: AppText.caption),
        ],
      ),
    );
  }
}

class _MemberMealRow extends StatelessWidget {
  const _MemberMealRow({required this.member, required this.entries});

  final StatsMember member;

  /// 이 멤버의 기간 안 끼니.
  final List<MealEntry> entries;

  @override
  Widget build(BuildContext context) {
    final counts = mealCategoryCounts(entries);
    final total = counts.fold(0, (sum, item) => sum + item.$2);
    final top = counts.isEmpty ? null : counts.first;
    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: total == 0 ? AppColors.line : member.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            if (top != null)
              NumText(
                '${top.$1.label} ${(top.$2 * 100 / total).round()}% · $total끼',
                style: AppText.number(size: 11.5, weight: FontWeight.w500, color: AppColors.muted),
              )
            else
              const Text('기록 없음', style: AppText.caption),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 14,
            child: total == 0
                ? const ColoredBox(color: AppColors.mutedBg)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (category, count) in counts)
                        Expanded(flex: count, child: ColoredBox(color: category.color)),
                    ],
                  ),
          ),
        ),
      ],
    );
    if (total == 0) return row;
    return HoverDetail(
      detail: _MealDetail(member: member, entries: entries, counts: counts, total: total),
      child: row,
    );
  }
}

/// 멤버 막대 위에 뜨는 식단 내역. 종류별 끼니 수와 최근 끼니 몇 개.
class _MealDetail extends StatelessWidget {
  const _MealDetail({required this.member, required this.entries, required this.counts, required this.total});

  final StatsMember member;
  final List<MealEntry> entries;
  final List<(MealCategory, int)> counts;
  final int total;

  @override
  Widget build(BuildContext context) {
    final recent = [for (final entry in entries) if (entry.description?.trim().isNotEmpty ?? false) entry]
      ..sort((a, b) => b.recordDate != a.recordDate
          ? b.recordDate.compareTo(a.recordDate)
          : b.slot.index.compareTo(a.slot.index));
    const dim = TextStyle(color: Color(0xFFBBBBBB), fontSize: 11);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${member.name} · $total끼', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 6),
        for (final (category, count) in counts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: category.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                SizedBox(width: 48, child: Text(category.label)),
                SizedBox(width: 36, child: Text('$count끼', textAlign: TextAlign.end)),
                SizedBox(
                  width: 40,
                  child: Text('${(count * 100 / total).round()}%', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('최근 끼니', style: dim),
          const SizedBox(height: 2),
          for (final entry in recent.take(3))
            Text(
              '${entry.recordDate.substring(5).replaceAll('-', '.')} ${entry.slot.label} · ${entry.description!.trim()}'
              '${entry.category == null ? '' : ' (${entry.category!.label})'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 멤버별 볼륨
// ---------------------------------------------------------------------------

/// 볼륨이 있는 칸만 점으로 남긴다.
/// [growth]면 칸마다 운동 한 번 평균 볼륨을 내고, 첫 운동 칸을 0%로 두고 몇 % 늘었는지로 바꾼다.
/// 총 볼륨으로 비교하면 운동 횟수가 적은 칸(달 보기의 짧은 첫 주 등)이 증가율을 부풀린다.
List<FlSpot> volumeSpots(List<VolumeBucket> buckets, {required bool growth}) {
  double? base;
  return [
    for (var i = 0; i < buckets.length; i++)
      if (buckets[i].volume > 0)
        FlSpot(
          i.toDouble(),
          growth ? ((buckets[i].perSession / (base ??= buckets[i].perSession)) - 1) * 100 : buckets[i].volume,
        ),
  ];
}

class MemberVolumeCard extends StatefulWidget {
  const MemberVolumeCard({
    super.key,
    required this.members,
    required this.sessions,
    required this.unit,
    required this.range,
  });

  final List<StatsMember> members;

  /// 기간 안의 모든 멤버 운동.
  final List<WorkoutSession> sessions;
  final StatsUnit unit;
  final DateTimeRange range;

  @override
  State<MemberVolumeCard> createState() => _MemberVolumeCardState();
}

class _MemberVolumeCardState extends State<MemberVolumeCard> {
  var _growth = false;

  @override
  Widget build(BuildContext context) {
    final byMember = {
      for (final member in widget.members)
        member.id: widget.sessions.where((session) => session.userId == member.id).toList(),
    };
    final buckets = {
      for (final member in widget.members)
        member.id: volumeBuckets(byMember[member.id]!, unit: widget.unit, range: widget.range),
    };
    final labels = volumeBuckets(const [], unit: widget.unit, range: widget.range);
    final lines = [
      for (final member in widget.members)
        (member, volumeSpots(buckets[member.id]!, growth: _growth)),
    ];
    final drawn = [for (final line in lines) if (line.$2.isNotEmpty) line];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            '멤버별 볼륨',
            icon: Icons.stacked_line_chart,
            trailing: SegmentedToggle<bool>(
              options: const [(false, '볼륨'), (true, '증가율')],
              value: _growth,
              onChanged: (value) => setState(() => _growth = value),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _growth
                ? '운동 한 번 평균 볼륨이 각자 이 기간 첫 운동 칸보다 몇 % 늘었는지 봐요. 몸무게나 운동 횟수가 달라도 비교돼요.'
                : '세트마다 무게×횟수를 더했어요. 무게 없는 세트(맨몸·유산소)는 빠져요.',
            style: AppText.caption,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (member, spots) in lines)
                LegendChip(
                  color: spots.isEmpty ? AppColors.line : member.color,
                  label: spots.isEmpty ? '${member.name} · 기록 없음' : member.name,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (drawn.isEmpty)
            const SizedBox(
              height: 160,
              child: Center(child: Text('이 기간에 무게를 기록한 운동이 없어요.', style: AppText.label)),
            )
          else
            SizedBox(height: 200, child: _chart(drawn, labels)),
          const SizedBox(height: 14),
          for (final member in widget.members)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: byMember[member.id]!.isEmpty ? AppColors.line : member.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(member.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body),
                  ),
                  if (byMember[member.id]!.isEmpty)
                    const Text('기록 없음', style: AppText.caption)
                  else ...[
                    NumText(
                      '운동 ${byMember[member.id]!.length}번',
                      style: AppText.number(size: 11.5, weight: FontWeight.w500, color: AppColors.muted),
                    ),
                    const SizedBox(width: AppSpacing.gap),
                    SizedBox(
                      width: 88,
                      child: NumText(
                        formatKg(byMember[member.id]!.fold(0.0, (sum, session) => sum + session.volume)),
                        textAlign: TextAlign.end,
                        style: AppText.number(size: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chart(List<(StatsMember, List<FlSpot>)> drawn, List<VolumeBucket> labels) {
    final ys = [for (final (_, spots) in drawn) for (final spot in spots) spot.y];
    var lo = _growth ? min(0.0, ys.reduce(min)) : 0.0;
    var hi = max(ys.reduce(max), _growth ? 0.0 : 1.0);
    final rough = max((hi - lo) / 4, _growth ? 5.0 : 100.0);
    final magnitude = pow(10, (log(rough) / ln10).floor()).toDouble();
    final step = [1, 2, 5, 10].map((m) => m * magnitude).firstWhere((s) => s >= rough);
    lo = (lo / step).floor() * step;
    hi = max((hi / step).ceil() * step, lo + step);
    final labelEvery = max(1, (labels.length / 6).ceil());

    String axis(double value) {
      if (_growth) return '${value > 0 ? '+' : ''}${value.round()}%';
      if (value >= 1000) {
        final tons = value / 1000;
        return '${tons == tons.roundToDouble() ? tons.toStringAsFixed(0) : tons.toStringAsFixed(1)}t';
      }
      return value.toStringAsFixed(0);
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: max(1, labels.length - 1).toDouble(),
        minY: lo,
        maxY: hi,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (value) => FlLine(
            color: _growth && value == 0 ? AppColors.faint.withValues(alpha: 0.6) : AppColors.line,
            strokeWidth: 1,
            dashArray: _growth && value == 0 ? null : const [3, 3],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: step,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  axis(value),
                  style: AppText.number(size: 9.5, weight: FontWeight.w500, color: AppColors.faint),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if ((value - i).abs() > 1e-6 || i < 0 || i >= labels.length) return const SizedBox.shrink();
                final last = i == labels.length - 1;
                if (i % labelEvery != 0 && !last) return const SizedBox.shrink();
                if (!last && labels.length - 1 - i < labelEvery) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    labels[i].label,
                    style: AppText.number(size: 9.5, weight: FontWeight.w500, color: AppColors.faint),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          // 손가락이나 마우스가 가까운 칸 위에 있으면 그 칸 값을 보여 준다(세로 위치는 상관없다).
          touchSpotThreshold: 40,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.ink,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${drawn[spot.barIndex].$1.name} ${_growth ? axis(spot.y) : formatKg(spot.y)}',
                  TextStyle(color: drawn[spot.barIndex].$1.color, fontSize: 11, fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),
        lineBarsData: [
          for (final (member, spots) in drawn)
            LineChartBarData(
              spots: spots,
              color: member.color,
              barWidth: 1.6,
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              dotData: FlDotData(
                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                  radius: 2.6,
                  color: Colors.white,
                  strokeWidth: 1.4,
                  strokeColor: bar.color ?? AppColors.ink,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
