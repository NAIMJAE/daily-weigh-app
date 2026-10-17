import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../data/models/workout_routine.dart';
import '../records/records_controller.dart';
import '../records/write/write_parts.dart';
import 'workout_controller.dart';

/// 내 루틴 목록. 사용 중인 루틴을 바꾸고, 새 루틴을 만들고, 루틴을 열어 고친다.
class RoutineListScreen extends ConsumerWidget {
  const RoutineListScreen({super.key});

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
    final routines = ref.watch(myRoutinesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('내 루틴')),
      body: routines.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(friendlyError(error))),
        data: (list) => list.isEmpty
            ? const Center(child: Text('아직 만든 루틴이 없어요.', style: AppText.label))
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  for (final routine in list) ...[
                    _RoutineCard(
                      routine: routine,
                      onOpen: () => context.push('/workout/routines/${routine.id}'),
                      onActivate: routine.isActive ? null : () => _activate(context, ref, routine),
                    ),
                    const SizedBox(height: AppSpacing.section),
                  ],
                ],
              ),
      ),
      bottomNavigationBar: SaveBar(label: '새 루틴 만들기', onPressed: () => context.push('/workout/routines/new')),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.routine, required this.onOpen, this.onActivate});

  final Routine routine;
  final VoidCallback onOpen;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: routine.isActive ? AppColors.accent : AppColors.line, width: routine.isActive ? 1.5 : 1),
      ),
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
