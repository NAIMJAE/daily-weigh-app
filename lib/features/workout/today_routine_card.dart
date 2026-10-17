import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/active_workout.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_title.dart';
import 'active_workout_controller.dart';
import 'workout_controller.dart';
import 'workout_start.dart';

/// 운동 기록 화면 위의 루틴 카드. 루틴이 없으면 만들기로, 있으면 오늘 할 날을 보여 준다.
class TodayRoutineCard extends ConsumerWidget {
  const TodayRoutineCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(todayPlanProvider);
    final active = ref.watch(activeWorkoutProvider).value;
    return plan.when(
      loading: () => const AppCard(child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))),
      error: (error, _) => const SizedBox.shrink(),
      data: (plan) {
        if (plan == null) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('운동 루틴', icon: Icons.event_repeat),
                const SizedBox(height: 8),
                const Text(
                  '루틴을 한 번만 만들어 두면, 매일 오늘 할 운동이 바로 나와요. 세트마다 체크만 하면 기록이 끝나요.',
                  style: AppText.label,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.push('/workout/routines/new'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('루틴 만들기'),
                ),
              ],
            ),
          );
        }
        final next = plan.next;
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                plan.routine.name,
                icon: Icons.event_repeat,
                trailing: TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: () => context.push('/workout/routines'),
                  child: const Text('루틴 관리'),
                ),
              ),
              const SizedBox(height: 10),
              if (next == null)
                const Text('이 루틴에 날이 없어요. 루틴 관리에서 날을 추가해 주세요.', style: AppText.label)
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('오늘은 ', style: AppText.label),
                    Text(next.name, style: AppText.headline.copyWith(color: AppColors.accent)),
                    const Spacer(),
                    Text(
                      plan.lastDay == null ? '첫 운동' : '지난 운동 ${plan.lastDay!.name}',
                      style: AppText.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (next.items.isEmpty) const Text('아직 종목이 없어요.', style: AppText.caption),
                      for (final item in next.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(child: Text(item.exercise.name, style: const TextStyle(fontSize: 13))),
                              NumText(
                                item.targetLabel,
                                style: AppText.number(size: 12, weight: FontWeight.w500, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (active != null)
                  ResumeWorkoutBox(workout: active)
                else ...[
                  FilledButton.icon(
                    onPressed: () => startWorkout(context, ref, routine: plan.routine, day: next),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text('${next.name} 시작'),
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final day = await pickRoutineDay(context, plan.routine, title: '어떤 날을 할까요?', highlight: next);
                            if (day != null && context.mounted) {
                              await startWorkout(context, ref, routine: plan.routine, day: day);
                            }
                          },
                          child: const Text('다른 날 하기'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.gap),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final day = await pickRoutineDay(context, plan.routine, title: '어제 한 날을 골라 주세요', highlight: next);
                            if (day != null && context.mounted) {
                              await startWorkout(context, ref, routine: plan.routine, day: day, yesterday: true);
                            }
                          },
                          child: const Text('어제 운동 채우기'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 진행 중인 운동이 있으면 시작 버튼 대신 이어 하기를 보여 준다. 앱이 꺼졌다 켜져도 남아 있다.
class ResumeWorkoutBox extends ConsumerWidget {
  const ResumeWorkoutBox({super.key, required this.workout});

  final ActiveWorkout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = localDateString();
    final started = workout.recordDate == today
        ? (workout.live ? '오늘 운동 중' : '오늘 기록 채우는 중')
        : '${workout.recordDate.substring(5).replaceAll('-', '.')} 기록 ${workout.live ? '운동 중' : '채우는 중'}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.chipFill),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.fitness_center, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '진행 중인 운동이 있어요 · ${workout.dayName ?? '운동'}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              NumText(
                '${workout.doneSets}/${workout.totalSets}세트',
                style: AppText.number(size: 12, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(started, style: AppText.caption),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.muted),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('운동을 버릴까요?'),
                        content: const Text('체크한 세트도 모두 사라져요.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                            child: const Text('버리기'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await ref.read(activeWorkoutProvider.notifier).discard();
                  },
                  child: const Text('버리기'),
                ),
              ),
              const SizedBox(width: AppSpacing.gap),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => context.push('/workout/session'),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('이어 하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
