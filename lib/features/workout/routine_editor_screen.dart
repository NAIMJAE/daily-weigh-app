import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/random_id.dart';
import '../../data/models/routine_draft.dart';
import '../../data/models/workout_routine.dart';
import '../../shared/widgets/app_card.dart';
import '../records/records_controller.dart';
import '../records/write/write_parts.dart';
import 'exercise_picker_sheet.dart';
import 'item_edit_sheet.dart';
import 'workout_controller.dart';

/// 루틴 편집: 이름, 날(순서·이름·추가·삭제), 날의 종목(추가·목표·순서·빼기). 저장을 눌러야 반영된다.
class RoutineEditorScreen extends ConsumerStatefulWidget {
  const RoutineEditorScreen({super.key, required this.routineId, this.fresh = false});

  final String routineId;

  /// 템플릿에서 막 만든 루틴. 시작 무게를 넣으라는 안내를 보여 주고 빈 무게 칸을 강조한다.
  final bool fresh;

  @override
  ConsumerState<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends ConsumerState<RoutineEditorScreen> {
  final _name = TextEditingController();
  // 종목 줄의 kg 칸. 편집 시트에서 무게를 고치면 이 값도 맞춘다.
  final _weights = <String, TextEditingController>{};
  Routine? _original;
  RoutineDraft? _draft;
  var _dirty = false;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    for (final controller in _weights.values) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _kg(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  }

  TextEditingController _weightFor(ItemDraft item) =>
      _weights.putIfAbsent(item.id, () => TextEditingController(text: _kg(item.weight)));

  void _change(VoidCallback update) {
    setState(() {
      update();
      _dirty = true;
    });
  }

  bool get _valid {
    final draft = _draft;
    if (draft == null || _name.text.trim().isEmpty || draft.days.isEmpty) return false;
    return draft.days.every((day) => day.name.trim().isNotEmpty);
  }

  Future<String?> _askName({required String title, required String initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '예: A 밀기', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('확인')),
        ],
      ),
    );
  }

  Future<void> _renameDay(DayDraft day) async {
    final name = await _askName(title: '날 이름', initial: day.name);
    if (name == null || name.isEmpty) return;
    _change(() => day.name = name);
  }

  Future<void> _addDay() async {
    final draft = _draft!;
    final name = await _askName(title: '날 추가', initial: draft.nextDayName());
    if (name == null || name.isEmpty) return;
    _change(() => draft.days.add(DayDraft(id: randomUuid(), name: name)));
  }

  Future<void> _removeDay(DayDraft day) async {
    final ok = await _confirm('${day.name}을(를) 지울까요?', '이 날의 종목도 함께 빠져요.');
    if (ok) _change(() => _draft!.days.remove(day));
  }

  void _moveDay(int index, int delta) {
    final days = _draft!.days;
    _change(() => days.insert(index + delta, days.removeAt(index)));
  }

  Future<void> _addItem(DayDraft day) async {
    final exercise = await pickExercise(context);
    if (exercise == null) return;
    _change(() => day.items.add(ItemDraft.fresh(exercise)));
  }

  Future<void> _editItem(DayDraft day, int index) async {
    final item = day.items[index];
    final action = await editRoutineItem(
      context,
      item,
      canMoveUp: index > 0,
      canMoveDown: index < day.items.length - 1,
    );
    switch (action) {
      case ItemAction.saved:
        _change(() => _weightFor(item).text = _kg(item.weight));
      case ItemAction.moveUp:
        _change(() => day.items.insert(index - 1, day.items.removeAt(index)));
      case ItemAction.moveDown:
        _change(() => day.items.insert(index + 1, day.items.removeAt(index)));
      case ItemAction.remove:
        _change(() => day.items.removeAt(index));
      case null:
        break;
    }
  }

  Future<bool> _confirm(String title, String body, {String action = '지우기'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _save() async {
    final draft = _draft!..name = _name.text;
    setState(() => _saving = true);
    try {
      await ref.read(routineRepositoryProvider).saveRoutine(draft, original: _original!);
      refreshRoutines(ref);
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('루틴을 저장했어요.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _menu(String value) async {
    final repo = ref.read(routineRepositoryProvider);
    try {
      if (value == 'activate') {
        await repo.setActiveRoutine(widget.routineId);
        refreshRoutines(ref);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이 루틴을 사용해요.')));
      } else if (value == 'delete') {
        final ok = await _confirm('루틴을 지울까요?', '지난 운동 기록은 그대로 남아요.');
        if (!ok) return;
        await repo.deleteRoutine(widget.routineId);
        refreshRoutines(ref);
        if (mounted) Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routines = ref.watch(myRoutinesProvider);
    final routine = routines.value?.where((r) => r.id == widget.routineId).firstOrNull;
    if (_draft == null && routine != null) {
      _original = routine;
      _draft = RoutineDraft.fromRoutine(routine);
      _name.text = routine.name;
    }
    final draft = _draft;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirm('저장하지 않고 나갈까요?', '고친 내용이 사라져요.', action: '나가기');
        if (leave && context.mounted) {
          setState(() => _dirty = false);
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('루틴 편집'),
          actions: [
            PopupMenuButton<String>(
              onSelected: _menu,
              itemBuilder: (context) => [
                if (routine != null && !routine.isActive) const PopupMenuItem(value: 'activate', child: Text('이 루틴 사용하기')),
                const PopupMenuItem(value: 'delete', child: Text('루틴 지우기')),
              ],
            ),
          ],
        ),
        body: draft == null
            ? Center(
                child: routines.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('루틴을 찾지 못했어요.', style: AppText.label),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  AppCard(
                    child: WriteSection(
                      title: '루틴 이름',
                      trailing: routine?.isActive ?? false
                          ? const Text(
                              '사용 중',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent),
                            )
                          : null,
                      child: TextField(
                        controller: _name,
                        maxLength: 20,
                        decoration: const InputDecoration(counterText: ''),
                        onChanged: (_) => _change(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  if (widget.fresh) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                        border: Border.all(color: AppColors.chipFill),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.scale_outlined, size: 18, color: AppColors.accent),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '종목마다 kg 칸에 지금 드는 무게를 넣어 두면 첫 운동부터 세트에 채워져요. 비워 두면 첫 운동에서 적은 무게를 다음부터 써요.',
                              style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),
                  ],
                  Text(
                    draft.days.isEmpty
                        ? '날을 하나 이상 추가해 주세요.'
                        : '${draft.days.map((day) => day.name.split(' ').first).join(' → ')} 순서로 돌아요. 쉰 날이 있어도 순서는 밀리지 않아요.',
                    style: AppText.label,
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  for (var i = 0; i < draft.days.length; i++) ...[
                    _DayCard(
                      day: draft.days[i],
                      index: i,
                      count: draft.days.length,
                      onRename: () => _renameDay(draft.days[i]),
                      onMove: (delta) => _moveDay(i, delta),
                      onRemove: () => _removeDay(draft.days[i]),
                      onAddItem: () => _addItem(draft.days[i]),
                      onEditItem: (index) => _editItem(draft.days[i], index),
                      weightFor: _weightFor,
                      onWeightChanged: (item, value) => _change(() => item.weight = double.tryParse(value.trim())),
                      highlightEmpty: widget.fresh,
                    ),
                    const SizedBox(height: AppSpacing.section),
                  ],
                  OutlinedButton.icon(onPressed: _addDay, icon: const Icon(Icons.add, size: 18), label: const Text('날 추가')),
                ],
              ),
        bottomNavigationBar: draft == null
            ? null
            : SaveBar(
                label: _valid ? '저장하기' : '이름과 날을 채워 주세요',
                saving: _saving,
                onPressed: _valid && _dirty ? _save : null,
              ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.index,
    required this.count,
    required this.onRename,
    required this.onMove,
    required this.onRemove,
    required this.onAddItem,
    required this.onEditItem,
    required this.weightFor,
    required this.onWeightChanged,
    required this.highlightEmpty,
  });

  final DayDraft day;
  final int index;
  final int count;
  final VoidCallback onRename;
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;
  final VoidCallback onAddItem;
  final ValueChanged<int> onEditItem;
  final TextEditingController Function(ItemDraft item) weightFor;
  final void Function(ItemDraft item, String value) onWeightChanged;
  final bool highlightEmpty;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.card, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: Text(
                  '${index + 1}',
                  style: AppText.number(size: 12, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: onRename,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(day.name, style: AppText.headline),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => switch (value) {
                  'rename' => onRename(),
                  'up' => onMove(-1),
                  'down' => onMove(1),
                  _ => onRemove(),
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'rename', child: Text('이름 바꾸기')),
                  if (index > 0) const PopupMenuItem(value: 'up', child: Text('앞으로')),
                  if (index < count - 1) const PopupMenuItem(value: 'down', child: Text('뒤로')),
                  const PopupMenuItem(value: 'remove', child: Text('날 지우기')),
                ],
              ),
            ],
          ),
          if (day.items.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 4, 12, 4),
              child: Text('아직 종목이 없어요.', style: AppText.caption),
            ),
          for (var i = 0; i < day.items.length; i++)
            _ItemRow(
              item: day.items[i],
              index: i,
              onTap: () => onEditItem(i),
              weight: weightFor(day.items[i]),
              onWeightChanged: (value) => onWeightChanged(day.items[i], value),
              highlightEmpty: highlightEmpty,
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddItem,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('종목 추가'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.index,
    required this.onTap,
    required this.weight,
    required this.onWeightChanged,
    required this.highlightEmpty,
  });

  final ItemDraft item;
  final int index;
  final VoidCallback onTap;
  final TextEditingController weight;
  final ValueChanged<String> onWeightChanged;

  /// 무게를 아직 넣지 않은 kg 칸을 강조한다 (템플릿에서 막 만든 루틴).
  final bool highlightEmpty;

  @override
  Widget build(BuildContext context) {
    final shown = item.toItem(index + 1);
    final rest = shown.restSeconds;
    final empty = item.weight == null;
    final detail = [
      if (rest != null && rest > 0) '쉬기 ${restLabel(rest)}',
      if (shown.progression != Progression.none) shown.progression.label,
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.tile),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: NumText('${index + 1}', style: AppText.number(size: 12, weight: FontWeight.w500, color: AppColors.faint)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.exercise.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  if (detail.isNotEmpty) Text(detail, style: AppText.caption),
                ],
              ),
            ),
            // 무게를 쓰는 종목은 시트를 열지 않고 바로 kg 을 적는다.
            if (item.exercise.measure.usesWeight) ...[
              SizedBox(
                width: 84,
                child: TextField(
                  controller: weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: AppText.number(size: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '0',
                    hintStyle: AppText.number(size: 14, weight: FontWeight.w500, color: AppColors.line),
                    suffixText: 'kg',
                    suffixStyle: AppText.caption,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                    fillColor: highlightEmpty && empty ? AppColors.accentSoft : AppColors.canvas,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      borderSide: BorderSide(color: highlightEmpty && empty ? AppColors.accent : AppColors.line),
                    ),
                  ),
                  onChanged: onWeightChanged,
                ),
              ),
              const SizedBox(width: 10),
            ],
            NumText(shown.targetLabel, style: AppText.number(size: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}
