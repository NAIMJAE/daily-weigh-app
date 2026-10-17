import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/active_workout.dart';
import '../../data/models/workout_routine.dart';
import '../../shared/widgets/app_card.dart';
import '../home/home_controller.dart';
import '../records/write/write_parts.dart';
import '../session/session_controller.dart';
import 'active_workout_controller.dart';
import 'exercise_picker_sheet.dart';
import 'workout_controller.dart';

/// 진행 화면. 헬스장에서는 세트마다 체크하고 쉬는 시간 타이머가 돈다. 어제 운동은 같은 표를 타이머 없이 채운다.
class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({super.key});

  @override
  ConsumerState<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  Timer? _ticker;
  DateTime? _restEndsAt;
  var _saving = false;

  ActiveWorkoutNotifier get _notifier => ref.read(activeWorkoutProvider.notifier);

  @override
  void initState() {
    super.initState();
    // 경과 시간과 쉬는 시간을 1초마다 다시 그린다.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    // 일회성 운동은 종목이 없이 시작하므로 바로 종목 고르기를 연다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final workout = ref.read(activeWorkoutProvider).value;
      if (mounted && workout != null && workout.exercises.isEmpty) _addExercise(workout);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final ends = _restEndsAt;
    if (ends != null && !DateTime.now().isBefore(ends)) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      setState(() => _restEndsAt = null);
      return;
    }
    if (ends != null || (ref.read(activeWorkoutProvider).value?.live ?? false)) setState(() {});
  }

  void _toggle(ActiveWorkout workout, ActiveExercise exercise, ActiveSet set) {
    set.done = !set.done;
    if (set.done) exercise.fillAfter(set);
    final rest = exercise.restSeconds ?? 0;
    setState(() {
      if (set.done && workout.live && rest > 0) {
        _restEndsAt = DateTime.now().add(Duration(seconds: rest));
      } else if (!set.done) {
        _restEndsAt = null;
      }
    });
    if (set.done) HapticFeedback.selectionClick();
    _notifier.changed();
  }

  Future<void> _addExercise(ActiveWorkout workout) async {
    final exercise = await pickExercise(context);
    if (exercise == null) return;
    final history = await ref.read(mySessionsProvider.future);
    workout.exercises.add(ActiveExercise.added(exercise, lastSetsFor(exercise.id, history)));
    await _notifier.changed();
  }

  Future<bool> _confirm(String title, String body, String action, {bool danger = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: danger ? TextButton.styleFrom(foregroundColor: AppColors.danger) : null,
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _discard() async {
    final ok = await _confirm('운동을 버릴까요?', '체크한 세트도 모두 사라져요.', '버리기', danger: true);
    if (!ok) return;
    await _notifier.discard();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _finish(ActiveWorkout workout) async {
    if (workout.doneSets == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('세트를 하나 이상 체크해 주세요.')));
      return;
    }
    if (!isEditableDay(parseLocalDate(workout.recordDate))) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('어제보다 지난 운동은 저장할 수 없어요. 메뉴에서 버려 주세요.')));
      return;
    }
    final undone = workout.totalSets - workout.doneSets;
    if (undone > 0) {
      final ok = await _confirm('운동을 마칠까요?', '체크하지 않은 세트 $undone개는 하지 않은 것으로 저장돼요.', '마치기');
      if (!ok) return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    // 저장 뒤 세션을 다시 읽으면 라우터가 새로 그려지므로, 화면을 먼저 닫고 나서 기록을 다시 읽는다.
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    final String sessionId;
    try {
      sessionId = await _notifier.finish();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnack(context, error);
      }
      return;
    }
    // 진행 화면 자리에 요약을 띄운다. 요약에서 확인을 누르면 운동을 시작한 화면으로 돌아간다.
    router.pushReplacement('/workout/summary/$sessionId');
    container.read(recordRevisionProvider.notifier).bump();
    container.invalidate(homeSnapshotProvider);
    container.invalidate(myRoutinesProvider);
    container.invalidate(todayPlanProvider);
    await container.read(sessionProvider.notifier).reload();
  }

  String _clock(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final hours = minutes ~/ 60;
    final mm = (minutes % 60).toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeWorkoutProvider);
    final workout = active.value;
    if (workout == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: active.isLoading
              ? const CircularProgressIndicator()
              : const Text('진행 중인 운동이 없어요.', style: AppText.label),
        ),
      );
    }
    final now = DateTime.now();
    final date = parseLocalDate(workout.recordDate);
    final subtitle = workout.live
        ? '경과 ${_clock(now.difference(workout.startedAt ?? now))}'
        : '${localDateString(date) == localDateString() ? '오늘' : '어제'} ${date.month}.${date.day.toString().padLeft(2, '0')} 기록';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workout.dayName ?? '운동'),
            NumText(subtitle, style: AppText.number(size: 12, weight: FontWeight.w500, color: AppColors.muted)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => _discard(),
            itemBuilder: (context) => const [PopupMenuItem(value: 'discard', child: Text('운동 버리기'))],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          if (!workout.live) ...[
            _DurationCard(
              minutes: workout.durationMinutes,
              onChanged: (minutes) {
                workout.durationMinutes = minutes;
                _notifier.changed();
              },
              onCheckAll: () {
                for (final exercise in workout.exercises) {
                  for (final set in exercise.sets) {
                    set.done = true;
                  }
                }
                _notifier.changed();
              },
            ),
            const SizedBox(height: AppSpacing.section),
          ],
          for (var i = 0; i < workout.exercises.length; i++) ...[
            _ExerciseCard(
              exercise: workout.exercises[i],
              onChanged: _notifier.changed,
              onToggle: (set) => _toggle(workout, workout.exercises[i], set),
              onRemove: () async {
                final ok = await _confirm('${workout.exercises[i].name}을(를) 뺄까요?', '이 종목의 세트가 빠져요.', '빼기', danger: true);
                if (!ok) return;
                workout.exercises.removeAt(i);
                await _notifier.changed();
              },
            ),
            const SizedBox(height: AppSpacing.section),
          ],
          if (workout.exercises.isEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('어떤 운동을 했나요?', style: AppText.title),
                  const SizedBox(height: 4),
                  const Text('종목을 골라 추가해 주세요. 목록에 없으면 이름을 적어 추가할 수 있어요.', style: AppText.label),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _addExercise(workout),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('종목 추가'),
                  ),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () => _addExercise(workout),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('종목 추가'),
            ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_restEndsAt != null)
            _RestBar(
              left: _restEndsAt!.difference(now),
              clock: _clock,
              onAdd: () => setState(() => _restEndsAt = _restEndsAt!.add(const Duration(seconds: 15))),
              onSkip: () => setState(() => _restEndsAt = null),
            ),
          SaveBar(
            label: '운동 완료 · ${workout.doneSets}/${workout.totalSets}세트',
            saving: _saving,
            onPressed: () => _finish(workout),
          ),
        ],
      ),
    );
  }
}

/// 어제 운동을 표로 채울 때: 운동 시간과 모두 체크.
class _DurationCard extends StatelessWidget {
  const _DurationCard({required this.minutes, required this.onChanged, required this.onCheckAll});

  final int minutes;
  final ValueChanged<int> onChanged;
  final VoidCallback onCheckAll;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('이미 한 운동을 표로 채워요. 한 세트는 체크해 주세요.', style: AppText.label),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Text('운동 시간', style: AppText.title)),
              IconButton.outlined(
                tooltip: '5분 줄이기',
                onPressed: minutes > 5 ? () => onChanged(minutes - 5) : null,
                icon: const Icon(Icons.remove, size: 18),
              ),
              SizedBox(
                width: 72,
                child: NumText('$minutes분', textAlign: TextAlign.center, style: AppText.number(size: 16)),
              ),
              IconButton.outlined(
                tooltip: '5분 늘리기',
                onPressed: minutes < 300 ? () => onChanged(minutes + 5) : null,
                icon: const Icon(Icons.add, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: onCheckAll, icon: const Icon(Icons.done_all, size: 18), label: const Text('모두 체크')),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise, required this.onChanged, required this.onToggle, required this.onRemove});

  final ActiveExercise exercise;
  final VoidCallback onChanged;
  final ValueChanged<ActiveSet> onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final measure = exercise.measure;
    final allDone = exercise.sets.isNotEmpty && exercise.doneSets == exercise.sets.length;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.card, 10, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(exercise.name, style: AppText.headline)),
                        if (allDone) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle, size: 18, color: AppColors.success),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    NumText(
                      [
                        if (exercise.targetLabel.isNotEmpty) '목표 ${exercise.targetLabel}',
                        exercise.lastSummary == null ? '처음 하는 종목' : '지난번 ${exercise.lastSummary}',
                        if ((exercise.restSeconds ?? 0) > 0) '쉬기 ${restLabel(exercise.restSeconds)}',
                      ].join(' · '),
                      style: AppText.number(size: 11.5, weight: FontWeight.w500, color: AppColors.faint),
                    ),
                  ],
                ),
              ),
              NumText(
                '${exercise.doneSets}/${exercise.sets.length}',
                style: AppText.number(size: 13, color: allDone ? AppColors.success : AppColors.muted),
              ),
              PopupMenuButton<String>(
                onSelected: (_) => onRemove(),
                itemBuilder: (context) => const [PopupMenuItem(value: 'remove', child: Text('종목 빼기'))],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                const SizedBox(width: 30, child: Text('세트', style: AppText.caption)),
                if (measure.usesWeight) const Expanded(child: Text('kg', textAlign: TextAlign.center, style: AppText.caption)),
                if (measure.usesReps) const Expanded(child: Text('회', textAlign: TextAlign.center, style: AppText.caption)),
                if (measure == Measure.time) const Expanded(child: Text('초', textAlign: TextAlign.center, style: AppText.caption)),
                if (measure == Measure.timeDistance) ...[
                  const Expanded(child: Text('분', textAlign: TextAlign.center, style: AppText.caption)),
                  const Expanded(child: Text('km', textAlign: TextAlign.center, style: AppText.caption)),
                ],
                const SizedBox(width: 48),
              ],
            ),
          ),
          for (var i = 0; i < exercise.sets.length; i++)
            _SetRow(
              // 앱이 값을 채우면(fills) 입력 칸을 새로 만들어 채운 값이 보이게 한다.
              key: ValueKey((identityHashCode(exercise.sets[i]), exercise.sets[i].fills)),
              number: i + 1,
              set: exercise.sets[i],
              measure: measure,
              onChanged: onChanged,
              onToggle: () => onToggle(exercise.sets[i]),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    exercise.addSet();
                    onChanged();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('세트'),
                ),
                if (exercise.sets.length > 1)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                    onPressed: () {
                      exercise.sets.removeLast();
                      onChanged();
                    },
                    icon: const Icon(Icons.remove, size: 18),
                    label: const Text('세트'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    super.key,
    required this.number,
    required this.set,
    required this.measure,
    required this.onChanged,
    required this.onToggle,
  });

  final int number;
  final ActiveSet set;
  final Measure measure;
  final VoidCallback onChanged;
  final VoidCallback onToggle;

  static String _text(num? value) {
    if (value == null) return '';
    if (value is double && value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final done = set.done;
    return Container(
      margin: const EdgeInsets.only(top: 4, right: 12),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: done ? AppColors.successSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: NumText('$number', textAlign: TextAlign.center, style: AppText.number(size: 13, color: AppColors.muted)),
          ),
          if (measure.usesWeight)
            _Cell(
              initial: _text(set.weightKg),
              decimal: true,
              done: done,
              onChanged: (value) {
                set.weightKg = double.tryParse(value);
                onChanged();
              },
            ),
          if (measure.usesReps)
            _Cell(
              initial: _text(set.reps),
              hint: set.targetReps == null ? '최대' : null,
              done: done,
              onChanged: (value) {
                set.reps = int.tryParse(value);
                onChanged();
              },
            ),
          if (measure == Measure.time)
            _Cell(
              initial: _text(set.seconds),
              done: done,
              onChanged: (value) {
                set.seconds = int.tryParse(value);
                onChanged();
              },
            ),
          if (measure == Measure.timeDistance) ...[
            _Cell(
              initial: set.seconds == null ? '' : '${set.seconds! ~/ 60}',
              done: done,
              onChanged: (value) {
                final minutes = int.tryParse(value);
                set.seconds = minutes == null ? null : minutes * 60;
                onChanged();
              },
            ),
            _Cell(
              initial: _text(set.distanceKm),
              decimal: true,
              done: done,
              onChanged: (value) {
                set.distanceKm = double.tryParse(value);
                onChanged();
              },
            ),
          ],
          SizedBox(
            width: 48,
            child: IconButton(
              tooltip: done ? '체크 풀기' : '세트 완료',
              onPressed: onToggle,
              icon: Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? AppColors.success : AppColors.faint,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.initial, required this.onChanged, required this.done, this.decimal = false, this.hint});

  final String initial;
  final ValueChanged<String> onChanged;
  final bool done;
  final bool decimal;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextFormField(
          initialValue: initial,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          textAlign: TextAlign.center,
          style: AppText.number(size: 16, color: done ? AppColors.success : AppColors.ink),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: AppText.number(size: 13, weight: FontWeight.w500, color: AppColors.faint),
            fillColor: done ? AppColors.card : AppColors.canvas,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _RestBar extends StatelessWidget {
  const _RestBar({required this.left, required this.clock, required this.onAdd, required this.onSkip});

  final Duration left;
  final String Function(Duration) clock;
  final VoidCallback onAdd;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.ink,
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          const Text('쉬는 중', style: TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(width: 8),
          NumText(clock(left.isNegative ? Duration.zero : left), style: AppText.number(size: 18, color: Colors.white)),
          const Spacer(),
          TextButton(
            onPressed: onAdd,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('+15초'),
          ),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('건너뛰기'),
          ),
        ],
      ),
    );
  }
}
