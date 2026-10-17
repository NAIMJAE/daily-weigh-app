import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/workout_routine.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_title.dart';
import '../home/home_controller.dart';
import '../records/records_controller.dart';
import 'session_detail_card.dart';
import 'workout_controller.dart';

/// 친구의 루틴. 같은 그룹이 아니면 권한에 막혀 비어 있다.
final memberRoutinesProvider = FutureProvider.family<List<Routine>, String>((ref, userId) async {
  return ref.read(routineRepositoryProvider).fetchRoutinesOf(userId);
});

/// 친구의 최근 운동 몇 개.
final memberSessionsProvider = FutureProvider.family<List<WorkoutSession>, String>((ref, userId) async {
  ref.watch(recordRevisionProvider);
  return ref.read(routineRepositoryProvider).fetchSessions(userId, limit: 3);
});

/// 멤버 방의 운동 카드: 친구가 쓰는 루틴(내 루틴으로 가져가기)과 최근 운동(종목·무게까지).
class MemberWorkoutCard extends ConsumerWidget {
  const MemberWorkoutCard({super.key, required this.userId, required this.nickname});

  final String userId;
  final String nickname;

  Future<void> _copy(BuildContext context, WidgetRef ref, Routine routine) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${routine.name}을(를) 가져올까요?'),
        content: Text('$nickname님의 루틴을 내 루틴으로 복사해요. 가져온 뒤에는 내 루틴만 바뀌고, $nickname님의 루틴은 그대로예요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('가져오기')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final id = await ref.read(routineRepositoryProvider).copyRoutine(routine.id);
      refreshRoutines(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${routine.name}을(를) 내 루틴에 추가했어요.'),
          action: SnackBarAction(label: '편집', onPressed: () => context.push('/workout/routines/$id')),
        ),
      );
    } catch (error) {
      if (context.mounted) showErrorSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(memberRoutinesProvider(userId)).value ?? const <Routine>[];
    final sessions = ref.watch(memberSessionsProvider(userId)).value ?? const <WorkoutSession>[];
    if (routines.isEmpty && sessions.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('운동', icon: Icons.fitness_center_outlined),
          for (final routine in routines) ...[
            const SizedBox(height: 10),
            _RoutineRow(routine: routine, onCopy: () => _copy(context, ref, routine)),
          ],
          if (sessions.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('최근 운동', style: AppText.label),
            for (final session in sessions) _SessionTile(session: session),
          ],
        ],
      ),
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.routine, required this.onCopy});

  final Routine routine;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(routine.name, style: AppText.title)),
                    if (routine.isActive) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '사용 중',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  routine.days.map((day) => day.name).join(' → '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('가져가기'),
          ),
        ],
      ),
    );
  }
}

/// 최근 운동 한 줄. 누르면 종목별 세트가 펼쳐진다.
class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final date = parseLocalDate(session.recordDate);
    return Theme(
      // ExpansionTile 의 위아래 구분선을 없앤다.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        title: Text(session.summary, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: NumText(
          '${date.month}.${date.day.toString().padLeft(2, '0')}',
          style: AppText.number(size: 11, weight: FontWeight.w500, color: AppColors.faint),
        ),
        children: [SessionSetTable(session: session)],
      ),
    );
  }
}
