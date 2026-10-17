import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/local_date.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_title.dart';
import '../records/write/write_parts.dart';
import 'active_workout_controller.dart';
import 'session_detail_card.dart';

/// 운동을 마친 뒤 보는 요약: 시간·세트·볼륨, 개인 최고 기록, 종목별 세트.
class WorkoutSummaryScreen extends ConsumerWidget {
  const WorkoutSummaryScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(workoutSummaryProvider(sessionId));
    return Scaffold(
      appBar: AppBar(title: const Text('운동 완료'), automaticallyImplyLeading: false),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(friendlyError(error))),
        data: (summary) {
          if (summary == null) return const Center(child: Text('운동 기록을 찾지 못했어요.', style: AppText.label));
          final session = summary.session;
          final date = parseLocalDate(session.recordDate);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: Icon(Icons.check_circle, size: 48, color: AppColors.success)),
                    const SizedBox(height: 8),
                    Text(session.dayName ?? '운동', textAlign: TextAlign.center, style: AppText.headline),
                    const SizedBox(height: 2),
                    NumText(
                      '${date.month}.${date.day.toString().padLeft(2, '0')} 운동한 날로 기록했어요',
                      textAlign: TextAlign.center,
                      style: AppText.number(size: 12, weight: FontWeight.w500, color: AppColors.muted),
                    ),
                    const SizedBox(height: 14),
                    SessionStats(session: session),
                  ],
                ),
              ),
              if (summary.records.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.section),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionTitle('개인 최고 기록 ${summary.records.length}개', icon: Icons.emoji_events_outlined),
                      const SizedBox(height: 10),
                      for (final record in summary.records)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(record.exerciseName, style: AppText.title)),
                              NumText(
                                record.previousLabel,
                                style: AppText.number(size: 12, weight: FontWeight.w500, color: AppColors.faint),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(Icons.arrow_forward, size: 14, color: AppColors.faint),
                              ),
                              NumText(record.label, style: AppText.number(size: 15, color: AppColors.accent)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.section),
              AppCard(child: SessionSetTable(session: session)),
            ],
          );
        },
      ),
      bottomNavigationBar: SaveBar(label: '확인', onPressed: () => Navigator.pop(context)),
    );
  }
}
