import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../data/models/workout_routine.dart';
import '../records/records_controller.dart';
import 'today_routine_card.dart';
import 'workout_controller.dart';

/// 운동 기록 화면의 루틴 탭: 사용 중인 루틴과 오늘 할 날, 다른 루틴, 새 루틴 만들기.
class RoutineTab extends ConsumerWidget {
  const RoutineTab({super.key});

  Future<void> _activate(BuildContext context, WidgetRef ref, Routine routine) async {
    try {
      await ref.read(routineRepositoryProvider).setActiveRoutine(routine.id);
      refreshRoutines(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${routine.name}을(를) 사용해요.')));
      }
    } catch (error) {
      if (context.mounted) showErrorSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(myRoutinesProvider).value ?? const <Routine>[];
    final others = routines.where((routine) => !routine.isActive).toList();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        const TodayRoutineCard(),
        if (others.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('다른 루틴', style: AppText.label),
          ),
          const SizedBox(height: AppSpacing.gap),
          for (final routine in others) ...[
            RoutineSummaryCard(
              routine: routine,
              onOpen: () => context.push('/workout/routines/${routine.id}'),
              onActivate: () => _activate(context, ref, routine),
            ),
            const SizedBox(height: AppSpacing.section),
          ],
        ],
        if (routines.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          OutlinedButton.icon(
            onPressed: () => context.push('/workout/routines/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('새 루틴 만들기'),
          ),
        ],
      ],
    );
  }
}

/// 루틴 한 줄 요약 카드: 이름, 날마다 종목. 사용 중이 아니면 사용하기 버튼이 있다.
class RoutineSummaryCard extends StatelessWidget {
  const RoutineSummaryCard({super.key, required this.routine, required this.onOpen, this.onActivate});

  final Routine routine;
  final VoidCallback onOpen;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(routine.name, style: AppText.headline)),
                  if (routine.isActive)
                    const Text(
                      '사용 중',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent),
                    )
                  else
                    TextButton(onPressed: onActivate, child: const Text('사용하기')),
                ],
              ),
              const SizedBox(height: 6),
              for (final day in routine.days)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${day.name} · ${day.items.map((item) => item.exercise.name).join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
