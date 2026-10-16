import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/local_date.dart';
import '../../core/utils/points.dart';
import '../../core/utils/weight.dart';
import '../../data/models/workout.dart';
import '../../data/repositories/record_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_title.dart';
import '../../shared/widgets/status_chip.dart';
import '../home/home_controller.dart';
import '../session/session_controller.dart';

Future<void> showRecordSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // 탭 화면에서 열어도 하단 탭을 덮고, 길어져도 상태 표시줄 아래에서 멈춘다.
    useRootNavigator: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    builder: (context) => const RecordSheet(),
  );
}

/// 웹 '오늘의 기록' 창과 같은 구성. 체중, 눈바디, 식단, 운동, 메모 중 하나만 있어도 출석.
class RecordSheet extends ConsumerStatefulWidget {
  const RecordSheet({super.key});

  @override
  ConsumerState<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends ConsumerState<RecordSheet> {
  final _weight = TextEditingController();
  final _memo = TextEditingController();
  RecordDraft _draft = RecordDraft();
  double? _lastWeight;
  var _loading = true;
  var _saving = false;
  var _loadFailed = false;
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
    final session = await currentSession(ref);
    if (!mounted) return;
    if (session.userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final repo = ref.read(recordRepositoryProvider);
      final today = localDateString();
      final record = await repo.fetchForUserOn(session.userId!, today);
      final previous = await repo.previousWeightBefore(userId: session.userId!, date: today);
      if (!mounted) return;
      _draft = RecordDraft.fromRecord(record);
      _lastWeight = previous?.weight ?? session.profile?.startWeight;
      _weight.text = _draft.weight;
      _memo.text = _draft.memo;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      // 오늘 기록을 못 읽은 채 저장하면 기존 값을 빈 값으로 덮으므로 저장을 막는다.
      setState(() {
        _loading = false;
        _loadFailed = true;
        _error = friendlyError(error);
      });
    }
  }

  RecordScoreInput get _scoreInput {
    return RecordScoreInput(
      hasWeight: double.tryParse(_weight.text.trim()) != null,
      hasBodyPhoto: _draft.hasBody,
      hasMealPhoto: _draft.hasMeal,
      hasWorkout: _draft.kinds.isNotEmpty,
      isRestDay: isRestOnly(_draft.kinds),
      workoutMinutes: _draft.workoutMinutes,
      hasMemo: _memo.text.trim().isNotEmpty,
    );
  }

  void _nudge(double delta) {
    final base = double.tryParse(_weight.text.trim()) ?? _lastWeight;
    if (base == null) return;
    final next = roundWeight((base + delta).toString());
    if (next == null) return;
    setState(() => _weight.text = next.toStringAsFixed(1));
  }

  Future<void> _pick(bool body) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      // 화면 폭 시트이므로 글자를 페이지 여백 안에 둔다.
      builder: (context) => ListTileTheme.merge(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('카메라'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('갤러리'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
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

  void _removePhoto(bool body) {
    setState(() {
      if (body) {
        _draft.bodyPhotoPath = null;
        _draft.removeBody = true;
      } else {
        _draft.mealPhotoPath = null;
        _draft.removeMeal = true;
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
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final input = _scoreInput;
    final points = computePoints(input);
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onClose: () => Navigator.pop(context)),
            const Divider(height: 1),
            if (_loading)
              const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
            else
              Flexible(
                child: Container(
                  color: AppColors.canvas,
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(AppSpacing.page),
                    children: [
                      _SharedNotice(),
                      const SizedBox(height: AppSpacing.gap),
                      _ProgressCard(points: points, input: input),
                      const SizedBox(height: AppSpacing.section),
                      _weightCard(),
                      const SizedBox(height: AppSpacing.section),
                      _photoCard(body: true),
                      const SizedBox(height: AppSpacing.section),
                      _photoCard(body: false),
                      const SizedBox(height: AppSpacing.section),
                      _workoutCard(),
                      const SizedBox(height: AppSpacing.section),
                      const Text('한 줄 메모 / 친구들에게 남기는 변명 (선택)', style: AppText.title),
                      const SizedBox(height: AppSpacing.gap),
                      TextField(
                        controller: _memo,
                        maxLength: 60,
                        decoration: const InputDecoration(hintText: '예: 오늘 야식의 유혹을 참아냄! / 점심에 치팅함', counterText: ''),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 10),
                child: FilledButton(
                  onPressed: _loading || _saving || _loadFailed || !input.isAttendance ? null : _save,
                  child: Text(_saving ? '저장 중...' : (input.isAttendance ? '저장하고 출석하기 · +${points}P' : '하나 이상 입력하세요')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weightCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            '오늘의 체중 (선택)',
            icon: Icons.scale_outlined,
            trailing: Text('+${PointRules.weight}P', style: AppText.caption),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppText.number(size: 20),
            decoration: InputDecoration(
              hintText: _lastWeight == null ? '0.0' : _lastWeight!.toStringAsFixed(1),
              hintStyle: AppText.number(size: 20, weight: FontWeight.w500, color: AppColors.faint),
              fillColor: AppColors.canvas,
              suffixText: 'kg',
              suffixStyle: AppText.label,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('퀵 조정:', style: AppText.caption.copyWith(color: AppColors.muted)),
              const SizedBox(width: 6),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final d in const [-0.5, -0.2, -0.1, 0.1, 0.2, 0.5])
                      _NudgeButton(label: '${d > 0 ? '+' : ''}$d', onTap: () => _nudge(d)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photoCard({required bool body}) {
    final picked = body ? _draft.bodyPhotoPath : _draft.mealPhotoPath;
    final removed = body ? _draft.removeBody : _draft.removeMeal;
    final url = removed ? null : (body ? _draft.existingBodyUrl : _draft.existingMealUrl);
    final cacheKey = body ? _draft.existingBodyCacheKey : _draft.existingMealCacheKey;
    final hasPhoto = picked != null || url != null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            body ? '오늘의 눈바디 사진 (선택)' : '오늘의 식단 사진 (선택)',
            icon: body ? Icons.photo_camera_outlined : Icons.restaurant_outlined,
            trailing: Text(
              body ? '+${PointRules.bodyPhoto}P · 겹쳐보기에 활용' : '+${PointRules.mealPhoto}P · 칼로리 계산 없음',
              style: AppText.caption,
            ),
          ),
          const SizedBox(height: 10),
          if (hasPhoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              child: AspectRatio(
                aspectRatio: body ? 4 / 3 : 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: AppColors.ink,
                      child: picked != null
                          ? Image.file(File(picked), fit: BoxFit.contain)
                          : CachedNetworkImage(imageUrl: url!, cacheKey: cacheKey, fit: BoxFit.contain),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        children: [
                          _OverlayButton(icon: Icons.refresh, label: '다시 찍기', onTap: () => _pick(body)),
                          const SizedBox(width: 6),
                          _OverlayButton(
                            icon: Icons.delete_outline,
                            label: '삭제',
                            danger: true,
                            onTap: () => _removePhoto(body),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _EmptyPhoto(onTap: () => _pick(body), label: body ? '눈바디 사진 추가' : '식단 사진 추가'),
        ],
      ),
    );
  }

  Widget _workoutCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            '오늘의 운동 (선택)',
            icon: Icons.fitness_center_outlined,
            trailing: Text('+${PointRules.workout}P · 30분↑ +${PointRules.longWorkoutBonus}', style: AppText.caption),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: AppSpacing.chip,
            runSpacing: AppSpacing.chip,
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
            const SizedBox(height: 12),
            const Text('운동 시간', style: AppText.label),
            const SizedBox(height: 6),
            Wrap(
              spacing: AppSpacing.chip,
              runSpacing: AppSpacing.chip,
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
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('오늘의 기록', style: AppText.headline),
                SizedBox(height: 2),
                Text('체중, 눈바디, 식단, 운동 중 원하는 것 1개만 입력해도 오늘 출석이 인정됩니다.', style: AppText.label),
              ],
            ),
          ),
          IconButton(tooltip: '닫기', onPressed: onClose, icon: const Icon(Icons.close, size: 20)),
        ],
      ),
    );
  }
}

/// 앱은 기록을 그룹마다 따로 저장하지 않는다. 웹의 '기록 대상 그룹' 자리에 그 사실을 알린다.
class _SharedNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.chipFill),
      ),
      child: const Row(
        children: [
          Expanded(child: Text('기록은 내가 속한 모든 그룹에 함께 보여요', style: AppText.label)),
          Icon(Icons.circle, size: 7, color: AppColors.accent),
          SizedBox(width: 4),
          Text(
            '모든 그룹',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.points, required this.input});

  final int points;
  final RecordScoreInput input;

  @override
  Widget build(BuildContext context) {
    // 올클리어 세 항목: 체중, 눈바디, 운동
    final steps = [input.hasWeight, input.hasBodyPhoto, input.hasWorkout];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.mutedBg,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 7, color: input.isAttendance ? AppColors.success : AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  input.isAttendance ? '출석 인정! 저장하면 오늘 스트릭이 이어져요' : '원하는 것 1개만 입력해도 출석 인정!',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip('+${points}P', tone: ChipTone.neutral, mono: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: steps[i] ? AppColors.accent : AppColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text('체중 · 눈바디 · 운동을 모두 하면 올클리어 +${PointRules.allClear}P', style: AppText.caption),
        ],
      ),
    );
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
        onTap: onTap,
        // alignment를 주면 Wrap 안에서 한 줄 폭을 다 차지하므로, 글자 크기만큼만 잡는다.
        child: Container(
          constraints: const BoxConstraints(minWidth: 42, minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(label, style: AppText.number(size: 11.5, weight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: danger ? const Color(0xFFFF6568) : Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPhoto extends StatelessWidget {
  const _EmptyPhoto({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.tile)),
        onTap: onTap,
        child: SizedBox(
          height: 96,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_a_photo_outlined, color: AppColors.faint),
              const SizedBox(height: 6),
              Text(label, style: AppText.label),
              const SizedBox(height: 2),
              const Text('카메라 또는 갤러리 · 하루 1장', style: AppText.caption),
            ],
          ),
        ),
      ),
    );
  }
}
