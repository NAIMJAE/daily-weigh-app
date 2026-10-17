import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/active_workout.dart';
import '../../data/models/workout_routine.dart';
import '../records/write/write_parts.dart' as write;
import 'active_workout_controller.dart';

// startWorkout 의 yesterday 인자와 이름이 겹쳐 별칭으로 부른다.
DateTime previousDay() => write.yesterday();

/// 루틴 날 하나로 운동을 시작하고 진행 화면을 연다. [yesterday]면 어제 운동을 표로 채운다.
/// 진행 중인 운동이 있으면 버리고 새로 시작할지 먼저 묻는다.
Future<void> startWorkout(
  BuildContext context,
  WidgetRef ref, {
  required Routine routine,
  required RoutineDay day,
  bool yesterday = false,
}) async {
  final current = await ref.read(activeWorkoutProvider.future);
  if (!context.mounted) return;
  if (current != null) {
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('진행 중인 운동이 있어요'),
        content: Text('${current.dayName ?? '운동'}을(를) 버리고 새로 시작할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('버리고 시작'),
          ),
        ],
      ),
    );
    if (replace != true || !context.mounted) return;
  }
  try {
    final history = await ref.read(mySessionsProvider.future);
    final workout = ActiveWorkout.fromDay(
      routine: routine,
      day: day,
      recordDate: localDateString(yesterday ? previousDay() : DateTime.now()),
      live: !yesterday,
      history: history,
    );
    await ref.read(activeWorkoutProvider.notifier).start(workout);
    if (context.mounted) context.push('/workout/session');
  } catch (error) {
    if (context.mounted) showErrorSnack(context, error);
  }
}

/// 루틴의 날 하나를 고른다. [highlight]는 오늘 추천 날.
Future<RoutineDay?> pickRoutineDay(BuildContext context, Routine routine, {required String title, RoutineDay? highlight}) {
  return showModalBottomSheet<RoutineDay>(
    context: context,
    useRootNavigator: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 8),
            child: Text(title, style: AppText.headline),
          ),
          for (final day in routine.days)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              title: Text(day.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              subtitle: Text(
                day.items.map((item) => item.exercise.name).join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption,
              ),
              trailing: day.id == highlight?.id
                  ? const Text('오늘 추천', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent))
                  : null,
              onTap: () => Navigator.pop(context, day),
            ),
          const SizedBox(height: AppSpacing.gap),
        ],
      ),
    ),
  );
}
