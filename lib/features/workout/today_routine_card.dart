import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_title.dart';
import 'workout_controller.dart';

/// 운동 기록 화면 위의 루틴 카드. 루틴이 없으면 만들기로, 있으면 오늘 할 날을 보여 준다.
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
                // 진행 화면은 다음 단계에서 붙인다.
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('운동 시작 (준비 중)'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
