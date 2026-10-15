import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/local_date.dart';
import '../../core/utils/points.dart';
import '../../data/models/workout.dart';
import '../../data/repositories/record_repository.dart';
import '../home/home_controller.dart';
import '../session/session_controller.dart';

Future<void> showRecordSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const RecordSheet(),
  );
}

class RecordSheet extends ConsumerStatefulWidget {
  const RecordSheet({super.key});

  @override
  ConsumerState<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends ConsumerState<RecordSheet> {
  final _weight = TextEditingController();
  final _memo = TextEditingController();
  RecordDraft _draft = RecordDraft();
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
    _weight.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider).value;
    if (session?.userId == null) {
      setState(() => _loading = false);
      return;
    }
    final record = await ref.read(recordRepositoryProvider).fetchForUserOn(
      session!.userId!,
      localDateString(),
    );
    _draft = RecordDraft.fromRecord(record);
    _weight.text = _draft.weight;
    _memo.text = _draft.memo;
    setState(() => _loading = false);
  }

  RecordScoreInput get _scoreInput {
    return RecordScoreInput(
      hasWeight: double.tryParse(_weight.text.trim()) != null,
      hasBodyPhoto: _draft.bodyPhotoPath != null || (_draft.existingBodyPath?.isNotEmpty ?? false),
      hasMealPhoto: _draft.mealPhotoPath != null || (_draft.existingMealPath?.isNotEmpty ?? false),
      hasWorkout: _draft.kinds.isNotEmpty,
      isRestDay: isRestOnly(_draft.kinds),
      workoutMinutes: _draft.workoutMinutes,
      hasMemo: _memo.text.trim().isNotEmpty,
    );
  }

  Future<void> _pick(bool body) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('카메라'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              title: const Text('갤러리'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final path = await pickImagePath(source);
    if (path == null) return;
    setState(() {
      if (body) {
        _draft.bodyPhotoPath = path;
      } else {
        _draft.mealPhotoPath = path;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    _draft.weight = _weight.text;
    _draft.memo = _memo.text;
    try {
      await ref.read(recordRepositoryProvider).saveToday(_draft);
      ref.read(recordRevisionProvider.notifier).bump();
      ref.invalidate(homeSnapshotProvider);
      await ref.read(sessionProvider.notifier).reload();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + keyboard + safeBottom),
      child: _loading
          ? const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('오늘 기록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    '하나만 있어도 출석입니다. 예상 점수 ${computePoints(_scoreInput)}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '체중 (kg)', hintText: '0.1 단위'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: Text(
                          _draft.bodyPhotoPath != null || _draft.existingBodyPath != null
                              ? '눈바디 있음'
                              : '눈바디 사진',
                        ),
                        onPressed: () => _pick(true),
                      ),
                      ActionChip(
                        label: Text(
                          _draft.mealPhotoPath != null || _draft.existingMealPath != null
                              ? '식단 있음'
                              : '식단 사진',
                        ),
                        onPressed: () => _pick(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('운동', style: TextStyle(fontWeight: FontWeight.w700)),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final kind in WorkoutKind.values)
                        FilterChip(
                          label: Text(kind.label),
                          selected: _draft.kinds.contains(kind),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _draft.kinds.add(kind);
                            } else {
                              _draft.kinds.remove(kind);
                            }
                          }),
                        ),
                    ],
                  ),
                  if (_draft.kinds.isNotEmpty && !isRestOnly(_draft.kinds)) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final minutes in [15, 30, 45, 60, 90])
                          ChoiceChip(
                            label: Text('$minutes분'),
                            selected: _draft.workoutMinutes == minutes,
                            onSelected: (_) => setState(() => _draft.workoutMinutes = minutes),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _memo,
                    decoration: const InputDecoration(labelText: '메모', hintText: '한 줄'),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '저장 중...' : '저장'),
                  ),
                ],
              ),
            ),
    );
  }
}
