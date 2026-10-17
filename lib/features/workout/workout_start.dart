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
import '../home/home_controller.dart';
import '../records/write/write_parts.dart';
import 'active_workout_controller.dart';
import 'workout_controller.dart';

/// 운동 기록하기: 날짜(어제·오늘)와 방식(루틴 / 일회성 운동)을 고르고 진행 화면을 연다.
/// 진행 중인 운동이 있으면 고르지 않고 바로 이어 한다.
Future<void> showWorkoutStartSheet(BuildContext context, WidgetRef ref) async {
  final current = await ref.read(activeWorkoutProvider.future);
  if (!context.mounted) return;
  if (current != null) {
    context.push('/workout/session');
    return;
  }
  final plan = await ref.read(todayPlanProvider.future);
  if (!context.mounted) return;
  final choice = await showModalBottomSheet<_StartChoice>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    builder: (context) => _StartSheet(plan: plan),
  );
  if (choice == null || !context.mounted) return;
  final recordDate = localDateString(choice.date);
  if (choice.rest) {
    try {
      await ref.read(recordRepositoryProvider).saveRestDay(recordDate);
      await afterRecordSaved(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('휴식 데이로 남겼어요. 루틴 순서는 그대로예요.')));
      }
    } catch (error) {
      if (context.mounted) showErrorSnack(context, error);
    }
    return;
  }
  final live = recordDate == localDateString();
  await _begin(context, ref, () async {
    final day = choice.day;
    if (day == null) return ActiveWorkout.free(recordDate: recordDate, live: live);
    final history = await ref.read(mySessionsProvider.future);
    final workout = ActiveWorkout.fromDay(
      routine: plan!.routine,
      day: day,
      recordDate: recordDate,
      live: live,
      history: history,
    );
    // 증량 제안은 헬스장에서 시작할 때만 묻는다. 어제 운동 채우기는 이미 한 값을 적는 것이다.
    final suggestions = live ? suggestProgressions(day, history) : const <ProgressionSuggestion>[];
    if (suggestions.isNotEmpty && context.mounted) {
      final accepted = await _askProgressions(context, suggestions);
      for (final suggestion in suggestions) {
        if (accepted.contains(suggestion.exerciseIndex)) suggestion.applyTo(workout);
      }
    }
    return workout;
  });
}

/// '오늘 올려 볼 종목'. 종목마다 받기/넘기기를 고르고 시작한다. 닫으면 모두 넘긴 것으로 본다.
Future<Set<int>> _askProgressions(BuildContext context, List<ProgressionSuggestion> suggestions) async {
  final accepted = await showModalBottomSheet<Set<int>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    builder: (context) => _ProgressionSheet(suggestions: suggestions),
  );
  return accepted ?? const {};
}

class _ProgressionSheet extends StatefulWidget {
  const _ProgressionSheet({required this.suggestions});

  final List<ProgressionSuggestion> suggestions;

  @override
  State<_ProgressionSheet> createState() => _ProgressionSheetState();
}

class _ProgressionSheetState extends State<_ProgressionSheet> {
  late final _accepted = {for (final suggestion in widget.suggestions) suggestion.exerciseIndex};

  @override
  Widget build(BuildContext context) {
    final all = _accepted.length == widget.suggestions.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, AppSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('오늘 올려 볼 종목', style: AppText.headline),
            const SizedBox(height: 4),
            const Text('지난번에 목표를 모두 채운 종목이에요. 받으면 세트 값이 바뀌어요.', style: AppText.label),
            const SizedBox(height: AppSpacing.section),
            for (final suggestion in widget.suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.gap),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(suggestion.exerciseName, style: AppText.title),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              NumText(
                                suggestion.from,
                                style: AppText.number(size: 12, weight: FontWeight.w500, color: AppColors.faint),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.arrow_forward, size: 12, color: AppColors.faint),
                              ),
                              NumText(suggestion.to, style: AppText.number(size: 13, color: AppColors.accent)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                      segments: const [
                        ButtonSegment(value: true, label: Text('받기')),
                        ButtonSegment(value: false, label: Text('넘기기')),
                      ],
                      selected: {_accepted.contains(suggestion.exerciseIndex)},
                      onSelectionChanged: (value) => setState(() {
                        if (value.first) {
                          _accepted.add(suggestion.exerciseIndex);
                        } else {
                          _accepted.remove(suggestion.exerciseIndex);
                        }
                      }),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.gap),
            FilledButton(
              onPressed: () => Navigator.pop(context, _accepted),
              child: Text(
                all
                    ? '모두 받고 시작'
                    : _accepted.isEmpty
                    ? '그대로 시작'
                    : '${_accepted.length}개 받고 시작',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 진행 중인 운동이 있으면 버리고 새로 시작할지 묻고, 새 운동을 휴대폰에 저장한 뒤 진행 화면을 연다.
Future<void> _begin(BuildContext context, WidgetRef ref, Future<ActiveWorkout> Function() build) async {
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
    final workout = await build();
    await ref.read(activeWorkoutProvider.notifier).start(workout);
    if (context.mounted) context.push('/workout/session');
  } catch (error) {
    if (context.mounted) showErrorSnack(context, error);
  }
}

/// 시트에서 고른 것. [rest]면 휴식 데이, 아니고 [day]가 없으면 일회성 운동이다.
class _StartChoice {
  const _StartChoice({required this.date, this.day, this.rest = false});

  final DateTime date;
  final RoutineDay? day;
  final bool rest;
}

class _StartSheet extends StatefulWidget {
  const _StartSheet({required this.plan});

  final TodayPlan? plan;

  @override
  State<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<_StartSheet> {
  var _date = today();
  RoutineDay? _day;

  @override
  void initState() {
    super.initState();
    _day = widget.plan?.next;
  }

  Future<void> _pickDay() async {
    final plan = widget.plan!;
    final day = await showModalBottomSheet<RoutineDay>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 8),
              child: Text('어떤 날을 할까요?', style: AppText.headline),
            ),
            for (final day in plan.routine.days)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                title: Text(day.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  day.items.map((item) => item.exercise.name).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
                trailing: day.id == plan.next?.id
                    ? const Text('오늘 추천', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent))
                    : null,
                onTap: () => Navigator.pop(context, day),
              ),
            const SizedBox(height: AppSpacing.gap),
          ],
        ),
      ),
    );
    if (day != null) setState(() => _day = day);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final day = _day;
    final isToday = localDateString(_date) == localDateString();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, AppSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('운동 기록하기', style: AppText.headline),
            const SizedBox(height: 12),
            DayChoice(value: _date, onChanged: (date) => setState(() => _date = date)),
            const SizedBox(height: 6),
            Text(
              isToday ? '세트마다 체크하고 쉬는 시간 타이머가 돌아요.' : '이미 한 운동을 표로 채워요. 타이머는 없어요.',
              style: AppText.caption,
            ),
            const SizedBox(height: AppSpacing.section),
            _OptionCard(
              icon: Icons.event_repeat,
              title: plan == null
                  ? '루틴으로 기록'
                  : day == null
                  ? '${plan.routine.name} · 날이 없어요'
                  : '${day.name}로 기록',
              subtitle: plan == null
                  ? '루틴이 없어요. 루틴 탭에서 만들 수 있어요.'
                  : day == null
                  ? '루틴 탭에서 날을 추가해 주세요.'
                  : [
                      if (day.id == plan.next?.id) '오늘 추천',
                      day.items.map((item) => item.exercise.name).join(', '),
                    ].join(' · '),
              trailing: plan != null && plan.routine.days.length > 1
                  ? TextButton(onPressed: _pickDay, child: const Text('다른 날'))
                  : null,
              onTap: day == null ? null : () => Navigator.pop(context, _StartChoice(date: _date, day: day)),
            ),
            const SizedBox(height: AppSpacing.gap),
            _OptionCard(
              icon: Icons.bolt_outlined,
              title: '일회성 운동',
              subtitle: '루틴에 없는 운동을 종목을 골라 기록해요. 루틴 순서는 그대로예요.',
              onTap: () => Navigator.pop(context, _StartChoice(date: _date)),
            ),
            const SizedBox(height: AppSpacing.gap),
            _OptionCard(
              icon: Icons.hotel_outlined,
              title: isToday ? '오늘은 쉬어요' : '어제는 쉬었어요',
              subtitle: '휴식 데이로 남겨요. 달력에 휴로 보이고, 루틴 순서는 그대로예요.',
              onTap: () => Navigator.pop(context, _StartChoice(date: _date, rest: true)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.icon, required this.title, required this.subtitle, this.trailing, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.card, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: AppColors.chipFill, shape: BoxShape.circle),
                  child: Icon(icon, color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.title),
                      const SizedBox(height: 2),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption),
                    ],
                  ),
                ),
                ?trailing,
                if (trailing == null && enabled) const Icon(Icons.chevron_right, color: AppColors.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
