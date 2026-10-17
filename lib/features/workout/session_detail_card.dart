import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/workout_routine.dart';
import '../../shared/widgets/app_card.dart';

String _number(double value) {
  final rounded = value.round();
  if (rounded >= 1000) {
    final text = rounded.toString();
    return '${text.substring(0, text.length - 3)},${text.substring(text.length - 3)}';
  }
  return rounded.toString();
}

String _time(DateTime time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// 운동 하나의 시간·세트·볼륨 묶음. 요약 화면과 운동 기록 일 보기가 같이 쓴다.
class SessionStats extends StatelessWidget {
  const SessionStats({super.key, required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final volume = session.volume;
    return Row(
      children: [
        Expanded(child: _Stat(label: '운동 시간', value: '${session.durationMinutes}분')),
        const SizedBox(width: AppSpacing.gap),
        Expanded(child: _Stat(label: '세트', value: '${session.doneSets}')),
        const SizedBox(width: AppSpacing.gap),
        Expanded(child: _Stat(label: '종목', value: '${session.exerciseCount}')),
        if (volume > 0) ...[
          const SizedBox(width: AppSpacing.gap),
          Expanded(child: _Stat(label: '볼륨', value: '${_number(volume)}kg')),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Text(label, style: AppText.caption),
          const SizedBox(height: 4),
          NumText(value, maxLines: 1, style: AppText.number(size: 15)),
        ],
      ),
    );
  }
}

/// 종목마다 세트를 한 줄씩. 체크하지 않은 세트는 흐리게 줄을 그어 보여 준다.
class SessionSetTable extends StatelessWidget {
  const SessionSetTable({super.key, required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final groups = setsByExercise(session);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const Divider(height: 20),
          Row(
            children: [
              Expanded(child: Text(groups[i].$1, style: AppText.title)),
              NumText(
                '${groups[i].$2.where((set) => set.done).length}/${groups[i].$2.length}세트',
                style: AppText.number(size: 12, weight: FontWeight.w500, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.chip,
            runSpacing: AppSpacing.chip,
            children: [
              for (final set in groups[i].$2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: set.done ? AppColors.successSoft : AppColors.mutedBg,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(
                    set.label,
                    style: AppText.number(
                      size: 12,
                      weight: FontWeight.w600,
                      color: set.done ? AppColors.success : AppColors.faint,
                    ).copyWith(decoration: set.done ? null : TextDecoration.lineThrough),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 운동 기록 일 보기 아래에 붙는 운동 카드. [onDelete]가 있으면 지우기 메뉴가 보인다.
class SessionDetailCard extends StatelessWidget {
  const SessionDetailCard({super.key, required this.session, this.onDelete});

  final WorkoutSession session;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final started = session.startedAt;
    final finished = session.finishedAt;
    final when = started != null && finished != null ? '${_time(started)}–${_time(finished)}' : '표로 채운 기록';
    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.card, 8, 4, AppSpacing.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.dayName ?? '운동', style: AppText.headline),
                    NumText(when, style: AppText.number(size: 12, weight: FontWeight.w500, color: AppColors.faint)),
                  ],
                ),
              ),
              if (onDelete != null)
                PopupMenuButton<String>(
                  onSelected: (_) => onDelete!(),
                  itemBuilder: (context) => const [PopupMenuItem(value: 'delete', child: Text('이 운동 지우기'))],
                )
              else
                const SizedBox(height: 48),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SessionStats(session: session),
                const SizedBox(height: 14),
                SessionSetTable(session: session),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
