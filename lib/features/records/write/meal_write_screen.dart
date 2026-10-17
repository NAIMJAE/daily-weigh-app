import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/local_date.dart';
import '../../../data/models/meal_entry.dart';
import '../../../shared/widgets/app_card.dart';
import '../../home/home_controller.dart';
import '../record_browser.dart';
import '../records_controller.dart';
import 'write_parts.dart';

/// 지금 시각에 맞는 끼니. 10:30 전 아침, 15시 전 점심, 21시 전 저녁, 그 뒤는 간식.
MealSlot mealSlotForNow([DateTime? at]) {
  final now = at ?? DateTime.now();
  final minutes = now.hour * 60 + now.minute;
  if (minutes < 10 * 60 + 30) return MealSlot.breakfast;
  if (minutes < 15 * 60) return MealSlot.lunch;
  if (minutes < 21 * 60) return MealSlot.dinner;
  return MealSlot.snack;
}

/// 식단 기록: 끼니마다 사진 한 장, 메뉴 한 줄, 빠른 태그. 오늘과 어제만 쓴다.
class MealWriteScreen extends ConsumerStatefulWidget {
  const MealWriteScreen({super.key, this.date, this.slot});

  /// 'YYYY-MM-DD'. 없거나 고칠 수 없는 날이면 오늘.
  final String? date;

  /// 끼니 값. 없으면 지금 시각으로 고른다.
  final String? slot;

  @override
  ConsumerState<MealWriteScreen> createState() => _MealWriteScreenState();
}

class _MealWriteScreenState extends ConsumerState<MealWriteScreen> {
  final _description = TextEditingController();
  late DateTime _date = editableDayFrom(widget.date);
  late MealSlot _slot = mealSlotFrom(widget.slot) ?? mealSlotForNow();
  Map<String, MealEntry> _entries = {};
  Set<MealTag> _tags = {};
  String? _pickedPath;
  var _removePhoto = false;
  var _loading = true;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  MealEntry? get _existing => _entries[mealKey(localDateString(_date), _slot)];

  Future<void> _load() async {
    try {
      final entries = await ref.read(myMealEntriesProvider.future);
      if (!mounted) return;
      _entries = entries;
      _fillDraft();
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(error);
      });
    }
  }

  /// 고른 날짜·끼니의 기록으로 입력 칸을 채운다.
  void _fillDraft() {
    final existing = _existing;
    _description.text = existing?.description ?? '';
    _tags = {...?existing?.tags};
    _pickedPath = null;
    _removePhoto = false;
    _error = null;
  }

  void _select({DateTime? date, MealSlot? slot}) {
    setState(() {
      _date = date ?? _date;
      _slot = slot ?? _slot;
      _fillDraft();
    });
  }

  bool get _hasPhoto => _pickedPath != null || (!_removePhoto && _existing?.photoUrl != null);
  bool get _canSave => !_loading && (_hasPhoto || _description.text.trim().isNotEmpty);

  /// 식단 점수는 하루 한 번이다. 그 날 다른 끼니가 이미 있으면 더 오르지 않는다.
  bool get _dayHasOtherMeal {
    final day = localDateString(_date);
    return MealSlot.values.any((slot) => slot != _slot && _entries.containsKey(mealKey(day, slot)));
  }

  Future<void> _pick() async {
    final path = await pickPhoto(context);
    if (path == null) return;
    setState(() => _pickedPath = path);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(recordRepositoryProvider).saveMeal(
        date: localDateString(_date),
        slot: _slot,
        description: _description.text,
        tags: _tags,
        newPhotoPath: _pickedPath,
        removePhoto: _removePhoto && _pickedPath == null,
      );
      await afterRecordSaved(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_slot.label} 식단을 저장했어요.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_slot.label} 식단을 지울까요?'),
        content: const Text('지운 기록은 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(recordRepositoryProvider).deleteMeal(date: localDateString(_date), slot: _slot);
      await afterRecordSaved(ref);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = localDateString(_date);
    final existing = _existing;
    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? '식단 기록하기' : '식단 기록 고치기'),
        actions: [
          if (existing != null)
            IconButton(
              tooltip: '이 끼니 지우기',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                DayChoice(value: _date, onChanged: (date) => _select(date: date)),
                const SizedBox(height: AppSpacing.gap),
                // 이미 기록한 끼니에는 체크가 붙는다.
                PillTabs<MealSlot>(
                  options: [
                    for (final slot in MealSlot.values)
                      (
                        slot,
                        slot.label,
                        _entries.containsKey(mealKey(day, slot)) ? Icons.check_circle : null,
                      ),
                  ],
                  value: _slot,
                  onChanged: (slot) => _select(slot: slot),
                ),
                const SizedBox(height: AppSpacing.section),
                AppCard(
                  child: WriteSection(
                    title: '${_slot.label} 사진',
                    child: PhotoField(
                      aspectRatio: 1,
                      emptyLabel: '음식 사진 추가',
                      pickedPath: _pickedPath,
                      url: _removePhoto ? null : existing?.photoUrl,
                      cacheKey: existing?.photoCacheKey,
                      onPick: _pick,
                      onRemove: () => setState(() {
                        _pickedPath = null;
                        _removePhoto = true;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                AppCard(
                  child: WriteSection(
                    title: '무엇을 먹었나요?',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _description,
                          maxLength: 40,
                          decoration: const InputDecoration(hintText: '예: 닭가슴살 샐러드', counterText: ''),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: AppSpacing.chip,
                          runSpacing: AppSpacing.chip,
                          children: [
                            for (final tag in MealTag.values)
                              FilterChip(
                                label: Text(tag.label),
                                selected: _tags.contains(tag),
                                onSelected: (selected) => setState(() {
                                  if (selected) {
                                    _tags.add(tag);
                                  } else {
                                    _tags.remove(tag);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
              ],
            ),
      bottomNavigationBar: SaveBar(
        note: _dayHasOtherMeal ? '식단 점수는 하루 한 번이라 이 끼니로는 더 오르지 않아요.' : null,
        label: !_canSave
            ? '사진이나 메뉴를 넣어 주세요'
            : _dayHasOtherMeal || existing != null
            ? '저장하기'
            : '저장하기 · +${PointRules.mealPhoto}P',
        saving: _saving,
        onPressed: _canSave ? _save : null,
      ),
    );
  }
}
