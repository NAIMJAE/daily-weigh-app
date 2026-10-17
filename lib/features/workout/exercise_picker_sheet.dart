import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../data/models/workout_routine.dart';
import '../records/records_controller.dart';
import 'workout_controller.dart';

/// 종목 하나를 고른다. 목록에 없으면 이름을 적어 내 종목으로 추가한다.
Future<Exercise?> pickExercise(BuildContext context) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    builder: (context) => const _ExercisePicker(),
  );
}

class _ExercisePicker extends ConsumerStatefulWidget {
  const _ExercisePicker();

  @override
  ConsumerState<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<_ExercisePicker> {
  final _search = TextEditingController();
  BodyPart? _part;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addCustom() async {
    final created = await showDialog<Exercise>(
      context: context,
      builder: (context) => _CustomExerciseDialog(initialName: _search.text.trim(), initialPart: _part),
    );
    if (created == null || !mounted) return;
    ref.invalidate(exercisesProvider);
    Navigator.pop(context, created);
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider);
    final query = _search.text.trim();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, 4, 8),
            child: Row(
              children: [
                const Expanded(child: Text('종목 고르기', style: AppText.headline)),
                IconButton(tooltip: '닫기', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(hintText: '종목 이름 검색', prefixIcon: Icon(Icons.search, size: 20)),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: AppSpacing.gap),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              children: [
                for (final part in <BodyPart?>[null, ...BodyPart.values]) ...[
                  ChoiceChip(
                    label: Text(part?.label ?? '전체'),
                    selected: _part == part,
                    onSelected: (_) => setState(() => _part = part),
                  ),
                  const SizedBox(width: AppSpacing.chip),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gap),
          const Divider(height: 1),
          Expanded(
            child: exercises.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(friendlyError(error))),
              data: (list) {
                final matches = [
                  for (final exercise in list)
                    if ((_part == null || exercise.bodyPart == _part) && (query.isEmpty || exercise.name.contains(query)))
                      exercise,
                ];
                final exact = list.any((exercise) => exercise.name == query);
                return ListView(
                  children: [
                    for (final part in BodyPart.values)
                      if (matches.any((exercise) => exercise.bodyPart == part)) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, AppSpacing.page, 4),
                          child: Text(part.label, style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        for (final exercise in matches.where((exercise) => exercise.bodyPart == part))
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                            title: Text(exercise.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              [if (exercise.equipment != null) exercise.equipment!.label, exercise.measure.label].join(' · '),
                              style: AppText.caption,
                            ),
                            trailing: exercise.isBase
                                ? null
                                : const Text('내 종목', style: TextStyle(fontSize: 11, color: AppColors.accent)),
                            onTap: () => Navigator.pop(context, exercise),
                          ),
                      ],
                    if (matches.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.page),
                        child: Text('찾는 종목이 없어요.', textAlign: TextAlign.center, style: AppText.label),
                      ),
                    if (!exact)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.page),
                        child: OutlinedButton.icon(
                          onPressed: _addCustom,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(query.isEmpty ? '목록에 없는 종목 추가' : "'$query' 직접 추가"),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomExerciseDialog extends ConsumerStatefulWidget {
  const _CustomExerciseDialog({required this.initialName, this.initialPart});

  final String initialName;
  final BodyPart? initialPart;

  @override
  ConsumerState<_CustomExerciseDialog> createState() => _CustomExerciseDialogState();
}

class _CustomExerciseDialogState extends ConsumerState<_CustomExerciseDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  late BodyPart _part = widget.initialPart ?? BodyPart.chest;
  var _measure = Measure.weightReps;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(routineRepositoryProvider)
          .addExercise(name: _name.text, bodyPart: _part, measure: _measure);
      if (mounted) Navigator.pop(context, created);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('종목 추가'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              maxLength: 30,
              decoration: const InputDecoration(hintText: '예: 스미스 머신 스쿼트', counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            const Text('부위', style: AppText.label),
            const SizedBox(height: 6),
            Wrap(
              spacing: AppSpacing.chip,
              runSpacing: AppSpacing.chip,
              children: [
                for (final part in BodyPart.values)
                  ChoiceChip(label: Text(part.label), selected: _part == part, onSelected: (_) => setState(() => _part = part)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('기록 방식', style: AppText.label),
            const SizedBox(height: 6),
            Wrap(
              spacing: AppSpacing.chip,
              runSpacing: AppSpacing.chip,
              children: [
                for (final measure in Measure.values)
                  ChoiceChip(
                    label: Text(measure.label),
                    selected: _measure == measure,
                    onSelected: (_) => setState(() => _measure = measure),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(
          onPressed: _saving || _name.text.trim().isEmpty ? null : _save,
          child: Text(_saving ? '추가 중...' : '추가'),
        ),
      ],
    );
  }
}
