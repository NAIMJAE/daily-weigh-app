import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/daily_record.dart';

class PhotoCalendar extends StatelessWidget {
  const PhotoCalendar({
    super.key,
    required this.month,
    required this.records,
    required this.onPrev,
    required this.onNext,
    required this.onDayTap,
  });

  final DateTime month;
  final List<DailyRecord> records;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final void Function(DateTime date, DailyRecord? record) onDayTap;

  static const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    // 주는 월요일에 시작한다 (통계의 주간과 같은 기준).
    final leading = first.weekday - DateTime.monday;
    final today = localDateString();
    final byDate = {
      for (final record in records)
        if (record.bodyPhotoUrl != null) record.recordDate: record,
    };
    return Column(
      children: [
        Row(
          children: [
            IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Text(
                '${month.year}.${month.month.toString().padLeft(2, '0')}',
                textAlign: TextAlign.center,
                style: AppText.number(size: 15),
              ),
            ),
            IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
          ],
        ),
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(label, textAlign: TextAlign.center, style: AppText.caption),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leading + days,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();
            final date = DateTime(month.year, month.month, index - leading + 1);
            final key = localDateString(date);
            final record = byDate[key];
            final isToday = key == today;
            return InkWell(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              onTap: () => onDayTap(date, record),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: isToday ? AppColors.accent : AppColors.line, width: isToday ? 1.5 : 1),
                ),
                child: record?.bodyPhotoUrl == null
                    ? Center(
                        child: Text(
                          '${date.day}',
                          style: AppText.number(
                            size: 11,
                            weight: isToday ? FontWeight.w800 : FontWeight.w500,
                            color: isToday ? AppColors.accent : AppColors.muted,
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.chip - 1),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: record!.bodyPhotoUrl!,
                              cacheKey: record.bodyPhotoCacheKey,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              left: 3,
                              top: 2,
                              child: Text(
                                '${date.day}',
                                style: AppText.number(
                                  size: 9,
                                  color: Colors.white,
                                ).copyWith(shadows: const [Shadow(color: Colors.black54, blurRadius: 3)]),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            );
          },
        ),
      ],
    );
  }
}

Future<void> showBodyPhoto(BuildContext context, DailyRecord record) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (record.bodyPhotoUrl != null)
            CachedNetworkImage(imageUrl: record.bodyPhotoUrl!, cacheKey: record.bodyPhotoCacheKey),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text([record.recordDate, if (record.weight != null) '${record.weight}kg'].join(' · ')),
          ),
        ],
      ),
    ),
  );
}
