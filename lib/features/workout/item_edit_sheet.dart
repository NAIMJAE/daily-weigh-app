import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/routine_draft.dart';
import '../../data/models/workout_routine.dart';

enum ItemAction { saved, moveUp, moveDown, remove }

/// 루틴 종목 하나의 목표, 쉬는 시간, 증량 방식을 고친다. 완료를 누르면 [item]에 반영한다.
Future<ItemAction?> editRoutineItem(
  BuildContext context,
  ItemDraft item, {
  required bool canMoveUp,
  required bool canMoveDown,
}) {
  return showModalBottomSheet<ItemAction>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    builder: (context) => _ItemEditor(item: item, canMoveUp: canMoveUp, canMoveDown: canMoveDown),
  );
}

class _ItemEditor extends StatefulWidget {
  const _ItemEditor({required this.item, required this.canMoveUp, required this.canMoveDown});

  final ItemDraft item;
  final bool canMoveUp;
  final bool canMoveDown;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late int _sets = widget.item.sets;
  late int? _repsMin = widget.item.repsMin;
  late int? _repsMax = widget.item.repsMax;
  late int? _seconds = widget.item.seconds;
  late final _weight = TextEditingController(text: _format(widget.item.weight));
  late final _distance = TextEditingController(text: _format(widget.item.distanceKm));
  late final _increment = TextEditingController(text: _format(widget.item.increment));
  late Progression? _progression = widget.item.progression;
  late int? _rest = widget.item.restSeconds;

  Exercise get _exercise => widget.item.exercise;
  Measure get _measure => _exercise.measure;
  Progression get _effectiveProgression => _progression ?? _exercise.progression;

  static String _format(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  }

  @override
  void dispose() {
    _weight.dispose();
    _distance.dispose();
    _increment.dispose();
    super.dispose();
  }

  void _done() {
    final item = widget.item
      ..sets = _sets
      ..repsMin = _measure.usesReps ? _repsMin : null
      ..repsMax = _measure.usesReps ? _repsMax : null
      ..seconds = _measure.usesTime ? _seconds : null
      ..weight = _measure.usesWeight ? double.tryParse(_weight.text.trim()) : null
      ..distanceKm = _measure.usesDistance ? double.tryParse(_distance.text.trim()) : null
      ..progression = _progression
      ..restSeconds = _rest;
    // 증량 단위가 종목 기본값과 같으면 비워 둔다. 그래야 종목 기본값을 따라간다.
    final increment = double.tryParse(_increment.text.trim());
    item.increment = increment == null || increment == _exercise.increment ? null : increment;
    Navigator.pop(context, ItemAction.saved);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final ranged = _effectiveProgression == Progression.doubleProgression;
    final maxReps = _measure == Measure.reps && _repsMin == null && _repsMax == null;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_exercise.name, style: AppText.headline),
                        const SizedBox(height: 2),
                        Text(
                          [_exercise.bodyPart.label, if (_exercise.equipment != null) _exercise.equipment!.label].join(' · '),
                          style: AppText.label,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '위로',
                    onPressed: widget.canMoveUp ? () => Navigator.pop(context, ItemAction.moveUp) : null,
                    icon: const Icon(Icons.arrow_upward, size: 20),
                  ),
                  IconButton(
                    tooltip: '아래로',
                    onPressed: widget.canMoveDown ? () => Navigator.pop(context, ItemAction.moveDown) : null,
                    icon: const Icon(Icons.arrow_downward, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  _Stepper(
                    label: '세트',
                    value: _sets,
                    min: 1,
                    max: 20,
                    format: (v) => '$v세트',
                    onChanged: (v) => setState(() => _sets = v),
                  ),
                  if (_measure.usesReps) ...[
                    const SizedBox(height: 12),
                    if (_measure == Measure.reps)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('횟수는 최대로', style: AppText.title),
                        subtitle: const Text('할 수 있는 만큼 하고 그때 횟수를 적어요.', style: AppText.label),
                        value: maxReps,
                        onChanged: (value) => setState(() {
                          _repsMin = value ? null : 10;
                          _repsMax = value ? null : 10;
                        }),
                      ),
                    if (!maxReps && ranged) ...[
                      _Stepper(
                        label: '횟수 범위 (아래)',
                        value: _repsMin ?? 8,
                        min: 1,
                        max: _repsMax ?? 50,
                        format: (v) => '$v회',
                        onChanged: (v) => setState(() => _repsMin = v),
                      ),
                      const SizedBox(height: 8),
                      _Stepper(
                        label: '횟수 범위 (위)',
                        value: _repsMax ?? 12,
                        min: _repsMin ?? 1,
                        max: 50,
                        format: (v) => '$v회',
                        onChanged: (v) => setState(() => _repsMax = v),
                      ),
                      const SizedBox(height: 4),
                      const Text('위 횟수를 모든 세트에서 채우면 무게를 올리자고 제안해요.', style: AppText.caption),
                    ] else if (!maxReps)
                      _Stepper(
                        label: '횟수',
                        value: _repsMin ?? _repsMax ?? 10,
                        min: 1,
                        max: 50,
                        format: (v) => '$v회',
                        onChanged: (v) => setState(() {
                          _repsMin = v;
                          _repsMax = v;
                        }),
                      ),
                  ],
                  if (_measure == Measure.time) ...[
                    const SizedBox(height: 12),
                    _Stepper(
                      label: '세트마다 시간',
                      value: _seconds ?? 60,
                      min: 10,
                      max: 600,
                      step: 10,
                      format: (v) => '$v초',
                      onChanged: (v) => setState(() => _seconds = v),
                    ),
                  ],
                  if (_measure == Measure.timeDistance) ...[
                    const SizedBox(height: 12),
                    _Stepper(
                      label: '시간',
                      value: (_seconds ?? 1200) ~/ 60,
                      min: 5,
                      max: 300,
                      step: 5,
                      format: (v) => '$v분',
                      onChanged: (v) => setState(() => _seconds = v * 60),
                    ),
                    const SizedBox(height: 12),
                    _NumberField(controller: _distance, label: '목표 거리 (선택)', suffix: 'km'),
                  ],
                  if (_measure.usesWeight) ...[
                    const SizedBox(height: 12),
                    _NumberField(
                      controller: _weight,
                      label: '무게 (선택)',
                      suffix: 'kg',
                      hint: '비우면 지난번 운동 무게를 써요',
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text('쉬는 시간', style: AppText.title),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: AppSpacing.chip,
                    runSpacing: AppSpacing.chip,
                    children: [
                      ChoiceChip(
                        label: Text('기본 ${restLabel(_exercise.restSeconds)}'),
                        selected: _rest == null,
                        onSelected: (_) => setState(() => _rest = null),
                      ),
                      for (final seconds in const [0, 60, 90, 120, 150, 180])
                        if (seconds != _exercise.restSeconds)
                          ChoiceChip(
                            label: Text(restLabel(seconds)),
                            selected: _rest == seconds,
                            onSelected: (_) => setState(() => _rest = seconds),
                          ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('증량 제안', style: AppText.title),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: AppSpacing.chip,
                    runSpacing: AppSpacing.chip,
                    children: [
                      ChoiceChip(
                        label: Text('기본 · ${_exercise.progression.label}'),
                        selected: _progression == null,
                        onSelected: (_) => setState(() => _progression = null),
                      ),
                      for (final progression in _choicesFor(_measure))
                        if (progression != _exercise.progression)
                          ChoiceChip(
                            label: Text(progression.label),
                            selected: _progression == progression,
                            onSelected: (_) => setState(() => _progression = progression),
                          ),
                    ],
                  ),
                  if (_effectiveProgression != Progression.none) ...[
                    const SizedBox(height: 12),
                    _NumberField(
                      controller: _increment,
                      label: '한 번에 올리는 양',
                      suffix: switch (_effectiveProgression) {
                        Progression.reps => '회',
                        Progression.time => '초',
                        _ => 'kg',
                      },
                      hint: _exercise.increment == null ? null : '기본 ${_format(_exercise.increment)}',
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () => Navigator.pop(context, ItemAction.remove),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('이 날에서 빼기'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 10),
                child: FilledButton(onPressed: _done, child: const Text('완료')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 기록 방식에 맞는 증량 방식만 고르게 한다.
  static List<Progression> _choicesFor(Measure measure) => switch (measure) {
    Measure.weightReps => const [Progression.weight, Progression.doubleProgression, Progression.reps, Progression.none],
    Measure.reps => const [Progression.reps, Progression.none],
    Measure.time => const [Progression.time, Progression.none],
    Measure.timeDistance => const [Progression.none],
  };
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String Function(int value) format;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppText.title)),
        IconButton.outlined(
          tooltip: '줄이기',
          onPressed: value - step >= min ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove, size: 18),
        ),
        SizedBox(
          width: 72,
          child: NumText(format(value), textAlign: TextAlign.center, style: AppText.number(size: 16)),
        ),
        IconButton.outlined(
          tooltip: '늘리기',
          onPressed: value + step <= max ? () => onChanged(value + step) : null,
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label, required this.suffix, this.hint});

  final TextEditingController controller;
  final String label;
  final String suffix;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.title),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: hint, suffixText: suffix, suffixStyle: AppText.label),
        ),
      ],
    );
  }
}
