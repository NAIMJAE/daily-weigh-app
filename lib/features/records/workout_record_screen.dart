import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/local_date.dart';
import '../workout/today_routine_card.dart';
import 'record_browser.dart';
import 'record_type.dart';
import 'records_controller.dart';

class WorkoutRecordScreen extends ConsumerWidget {
  const WorkoutRecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(myDailyRecordsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(RecordType.workout.title)),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(friendlyError(error))),
        data: (byDate) => ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const TodayRoutineCard(),
            const SizedBox(height: AppSpacing.section),
            RecordBrowser(
              emptyIcon: RecordType.workout.icon,
              countLabel: '운동한 날',
              dayOf: (date) {
                final record = byDate[localDateString(date)];
                final hasWorkout = record?.hasWorkout ?? false;
                final rest = record?.isRestOnly ?? false;
                final worked = hasWorkout && !rest;
                final minutes = record?.sessionMinutes ?? record?.workoutMinutes;
                return RecordDay(
                  mark: worked
                      ? DayMark.done
                      : rest
                      ? DayMark.rest
                      : (isPastDay(date) ? DayMark.missed : null),
                  lines: [
                    if (hasWorkout) record!.workoutSummary.isEmpty ? '루틴 운동' : record.workoutSummary,
                    if (worked && minutes != null) '$minutes분',
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
