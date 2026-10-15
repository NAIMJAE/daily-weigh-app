import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
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
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            final date = first.add(Duration(days: index));
            final key = localDateString(date);
            final record = byDate[key];
            return InkWell(
              onTap: () => onDayTap(date, record),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: record == null ? Colors.white : const Color(0xFFFFE8DE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                ),
                child: record?.bodyPhotoUrl == null
                    ? Center(child: Text('${date.day}', style: const TextStyle(fontSize: 12)))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(imageUrl: record!.bodyPhotoUrl!, fit: BoxFit.cover),
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
            CachedNetworkImage(imageUrl: record.bodyPhotoUrl!),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              [
                record.recordDate,
                if (record.weight != null) '${record.weight}kg',
              ].join(' · '),
            ),
          ),
        ],
      ),
    ),
  );
}
