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

/// 루틴 탭 맨 위의 카드. 루틴이 없으면 만들기로, 있으면 사용 중인 루틴과 오늘 할 날을 보여 준다.
class TodayRoutineCard extends ConsumerWidget {
  const TodayRoutineCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(todayPlanProvider);
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
                  onPressed: () => context.push('/workout/routines/${plan.routine.id}'),
                  child: const Text('편집'),
                ),
              ),
              const SizedBox(height: 10),
              if (next == null)
                const Text('이 루틴에 날이 없어요. 편집에서 날을 추가해 주세요.', style: AppText.label)
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
              ],
              const SizedBox(height: 10),
              // 순서대로 도는 날을 한눈에 보여 준다. 오늘 할 날이 강조된다.
              Wrap(
                spacing: AppSpacing.chip,
                runSpacing: AppSpacing.chip,
                children: [
                  for (final day in plan.routine.days)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: day.id == next?.id ? AppColors.chipFill : AppColors.mutedBg,
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      child: Text(
                        day.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: day.id == next?.id ? AppColors.accent : AppColors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 끝내지 않은 운동이 있으면 하단 탭 바로 위에 붙는 시트. 어느 탭에서든 눌러서 이어 한다.
/// 앱이 꺼졌다 켜져도 남아 있다.
class ResumeWorkoutBar extends ConsumerWidget {
  const ResumeWorkoutBar({super.key, required this.workout});

  final ActiveWorkout workout;

  String get _status {
    final doing = workout.live ? '운동 중' : '기록 채우는 중';
    if (workout.recordDate == localDateString()) return '오늘 $doing';
    return '${workout.recordDate.substring(5).replaceAll('-', '.')} $doing';
  }

  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref) async {
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = workout.totalSets;
    return Material(
      color: AppColors.card,
      elevation: 8,
      shadowColor: Colors.black26,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        side: BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/workout/session'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 체크한 세트만큼 위쪽 가장자리가 채워진다.
            LinearProgressIndicator(
              value: total == 0 ? 0 : workout.doneSets / total,
              minHeight: 3,
              backgroundColor: AppColors.chipFill,
              color: AppColors.accent,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: AppColors.chipFill, shape: BoxShape.circle),
                    child: const Icon(Icons.fitness_center, size: 18, color: AppColors.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${workout.dayName ?? '운동'} 진행 중',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        NumText('${workout.doneSets}/$total세트 · $_status', style: AppText.caption),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () => context.push('/workout/session'),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('이어 하기'),
                  ),
                  IconButton(
                    tooltip: '운동 버리기',
                    onPressed: () => _confirmDiscard(context, ref),
                    icon: const Icon(Icons.close, size: 20, color: AppColors.faint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
