import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/local_date.dart';
import '../workout/active_workout_controller.dart';
import '../workout/routine_tab.dart';
import '../workout/today_routine_card.dart';
import '../workout/workout_start.dart';
import 'record_browser.dart';
import 'record_type.dart';
import 'records_controller.dart';

/// 운동 기록 화면: 위쪽 [기록 | 루틴] 탭. 아래 버튼으로 루틴이나 일회성 운동을 기록한다.
class WorkoutRecordScreen extends ConsumerWidget {
  const WorkoutRecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkoutProvider).value;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(RecordType.workout.title),
          bottom: const TabBar(
            labelColor: AppColors.ink,
            unselectedLabelColor: AppColors.faint,
            indicatorColor: AppColors.accent,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            tabs: [Tab(text: '기록'), Tab(text: '루틴')],
          ),
        ),
        body: const TabBarView(children: [_HistoryTab(), RoutineTab()]),
        bottomNavigationBar: AddRecordBar(
          label: active == null ? '운동 기록하기' : '진행 중인 운동 이어 하기',
          icon: active == null ? Icons.add : Icons.play_arrow,
          onPressed: () => showWorkoutStartSheet(context, ref),
        ),
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(myDailyRecordsProvider);
    final active = ref.watch(activeWorkoutProvider).value;
    return records.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(friendlyError(error))),
      data: (byDate) => ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          if (active != null) ...[
            ResumeWorkoutBox(workout: active),
            const SizedBox(height: AppSpacing.section),
          ],
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
                  if (hasWorkout) record!.workoutSummary.isEmpty ? '운동 완료' : record.workoutSummary,
                  if (worked && minutes != null) '$minutes분',
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
