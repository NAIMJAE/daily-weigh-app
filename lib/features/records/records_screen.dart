import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/daily_record.dart';
import '../../data/models/meal_entry.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/section_title.dart';
import '../../shared/widgets/status_chip.dart';
import 'record_type.dart';
import 'records_controller.dart';

/// 기록 탭 첫 화면: 눈바디, 식단, 운동 중 하나를 고른다. 카드마다 이번 달 기록과 최근 모습을 보여 준다.
class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(myDailyRecordsProvider).value ?? const <String, DailyRecord>{};
    final meals = ref.watch(myMealEntriesProvider).value ?? const <String, MealEntry>{};
    final month = localDateString(startOfMonth(DateTime.now())).substring(0, 7);
    final thisMonth = [
      for (final record in records.values)
        if (record.recordDate.startsWith(month)) record,
    ];
    final newestFirst = records.values.toList()..sort((a, b) => b.recordDate.compareTo(a.recordDate));
    final mealsNewestFirst = meals.values.toList()..sort((a, b) => b.recordDate.compareTo(a.recordDate));

    final bodyPhotos = [
      for (final record in newestFirst)
        if (record.bodyPhotoUrl != null) (record.bodyPhotoUrl!, record.bodyPhotoCacheKey),
    ];
    final mealPhotos = [
      for (final entry in mealsNewestFirst)
        if (entry.photoUrl != null) (entry.photoUrl!, entry.photoCacheKey),
    ];
    final mealDays = {
      for (final entry in meals.values)
        if (entry.recordDate.startsWith(month)) entry.recordDate,
    };

    return Scaffold(
      appBar: const AppTopBar(title: '기록', icon: Icons.edit_calendar_outlined, showGroup: false),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          const Text('어떤 기록을 볼까요?', style: AppText.label),
          const SizedBox(height: AppSpacing.gap),
          _TypeCard(
            type: RecordType.body,
            stat: '이번 달 ${thisMonth.where((r) => r.hasBodyPhoto).length}장',
            preview: _PhotoStrip(photos: bodyPhotos.take(4).toList(), emptyIcon: RecordType.body.icon),
          ),
          const SizedBox(height: AppSpacing.section),
          _TypeCard(
            type: RecordType.meal,
            stat: '이번 달 ${mealDays.length}일',
            preview: _PhotoStrip(photos: mealPhotos.take(4).toList(), emptyIcon: RecordType.meal.icon),
          ),
          const SizedBox(height: AppSpacing.section),
          _TypeCard(
            type: RecordType.workout,
            stat: '이번 달 ${thisMonth.where((r) => r.hasWorkout && !r.isRestOnly).length}일',
            preview: _WorkoutWeek(records: records),
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.type, required this.stat, required this.preview});

  final RecordType type;
  final String stat;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(type.path),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconBadge(type.icon, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type.title, style: AppText.title),
                        const SizedBox(height: 2),
                        Text(type.description, style: AppText.label),
                      ],
                    ),
                  ),
                  StatusChip(stat, mono: true),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppColors.faint),
                ],
              ),
              const SizedBox(height: 12),
              preview,
            ],
          ),
        ),
      ),
    );
  }
}

/// 최근 사진 네 장. 모자란 칸은 빈 칸으로 채운다.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos, required this.emptyIcon});

  final List<(String, String?)> photos;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.tile);
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: i < photos.length
                  ? ClipRRect(
                      borderRadius: radius,
                      child: CachedNetworkImage(imageUrl: photos[i].$1, cacheKey: photos[i].$2, fit: BoxFit.cover),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: AppColors.canvas,
                        borderRadius: radius,
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Icon(emptyIcon, size: 18, color: AppColors.line),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 이번 주 월~일 운동 O/X.
class _WorkoutWeek extends StatelessWidget {
  const _WorkoutWeek({required this.records});

  final Map<String, DailyRecord> records;

  static const _labels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final start = startOfWeekMonday(DateTime.now());
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(
              builder: (context) {
                final date = DateTime(start.year, start.month, start.day + i);
                final record = records[localDateString(date)];
                final worked = record != null && record.hasWorkout && !record.isRestOnly;
                final rest = record?.isRestOnly ?? false;
                final past = isPastDay(date);
                return Column(
                  children: [
                    Text(_labels[i], style: AppText.caption),
                    const SizedBox(height: 4),
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: worked
                            ? AppColors.chipFill
                            : rest
                            ? AppColors.mutedBg
                            : AppColors.canvas,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: worked
                              ? AppColors.chipFill
                              : rest
                              ? AppColors.mutedBg
                              : AppColors.line,
                        ),
                      ),
                      child: worked
                          ? const Icon(Icons.circle_outlined, size: 16, color: AppColors.accent)
                          : rest
                          ? const Text(
                              '휴',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted),
                            )
                          : past
                          ? const Icon(Icons.close, size: 14, color: AppColors.faint)
                          : null,
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
