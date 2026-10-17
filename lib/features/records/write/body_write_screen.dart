import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/local_date.dart';
import '../../../core/utils/weight.dart';
import '../../../data/models/daily_record.dart';
import '../../../shared/widgets/app_card.dart';
import '../../home/home_controller.dart';
import '../../session/session_controller.dart';
import '../records_controller.dart';
import 'write_parts.dart';

/// 눈바디 기록: 사진, 체중, 한 줄 메모. 오늘과 어제만 쓴다.
class BodyWriteScreen extends ConsumerStatefulWidget {
  const BodyWriteScreen({super.key, this.date});

  /// 'YYYY-MM-DD'. 없거나 고칠 수 없는 날이면 오늘.
  final String? date;

  @override
  ConsumerState<BodyWriteScreen> createState() => _BodyWriteScreenState();
}

class _BodyWriteScreenState extends ConsumerState<BodyWriteScreen> {
  final _weight = TextEditingController();
  final _memo = TextEditingController();
  late DateTime _date = editableDayFrom(widget.date);
  DailyRecord? _existing;
  DailyRecord? _previousPhoto;
  double? _lastWeight;
  String? _pickedPath;
  var _removePhoto = false;
  var _ghost = 0.0;
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
    setState(() => _loading = true);
    try {
      final session = await currentSession(ref);
      final records = await ref.read(myDailyRecordsProvider.future);
      final key = localDateString(_date);
      final previous = session.userId == null
          ? null
          : await ref.read(recordRepositoryProvider).previousWeightBefore(userId: session.userId!, date: key);
      final before = records.values.where((r) => r.recordDate.compareTo(key) < 0 && r.bodyPhotoUrl != null).toList()
        ..sort((a, b) => b.recordDate.compareTo(a.recordDate));
      if (!mounted) return;
      final existing = records[key];
      setState(() {
        _existing = existing;
        _previousPhoto = before.isEmpty ? null : before.first;
        _lastWeight = previous?.weight ?? session.profile?.startWeight;
        _weight.text = existing?.weight?.toStringAsFixed(1) ?? '';
        _memo.text = existing?.memo ?? '';
        _pickedPath = null;
        _removePhoto = false;
        _ghost = 0;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(error);
      });
    }
  }

  bool get _hasPhoto => _pickedPath != null || (!_removePhoto && _existing?.bodyPhotoUrl != null);
  bool get _hasWeight => roundWeight(_weight.text) != null;

  int get _points =>
      (_hasWeight ? PointRules.weight : 0) + (_hasPhoto ? PointRules.bodyPhoto : 0);

  Future<void> _pick() async {
    final path = await pickPhoto(context);
    if (path == null) return;
    setState(() => _pickedPath = path);
  }

  void _nudge(double delta) {
    final base = double.tryParse(_weight.text.trim()) ?? _lastWeight;
    if (base == null) return;
    final next = roundWeight((base + delta).toString());
    if (next == null) return;
    setState(() => _weight.text = next.toStringAsFixed(1));
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(recordRepositoryProvider).saveBody(
        date: localDateString(_date),
        weight: _weight.text,
        memo: _memo.text,
        newPhotoPath: _pickedPath,
        removePhoto: _removePhoto && _pickedPath == null,
      );
      await afterRecordSaved(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('눈바디 기록을 저장했어요.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = ref.watch(sessionProvider).value?.profile?.startWeight;
    final weight = roundWeight(_weight.text);
    final delta = weight != null && start != null ? weight - start : null;
    final canSave = !_loading && (_hasWeight || _hasPhoto);
    return Scaffold(
      appBar: AppBar(title: Text(_existing == null ? '눈바디 기록하기' : '눈바디 기록 고치기')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                DayChoice(
                  value: _date,
                  onChanged: (date) {
                    if (date == _date) return;
                    _date = date;
                    _load();
                  },
                ),
                const SizedBox(height: AppSpacing.section),
                AppCard(
                  child: WriteSection(
                    title: '눈바디 사진',
                    trailing: Text('+${PointRules.bodyPhoto}P', style: AppText.caption),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PhotoField(
                          aspectRatio: 4 / 5,
                          emptyLabel: '눈바디 사진 추가',
                          pickedPath: _pickedPath,
                          url: _removePhoto ? null : _existing?.bodyPhotoUrl,
                          cacheKey: _existing?.bodyPhotoCacheKey,
                          ghostUrl: _previousPhoto?.bodyPhotoUrl,
                          ghostCacheKey: _previousPhoto?.bodyPhotoCacheKey,
                          ghostOpacity: _ghost,
                          onPick: _pick,
                          onRemove: () => setState(() {
                            _pickedPath = null;
                            _removePhoto = true;
                          }),
                        ),
                        if (_hasPhoto && _previousPhoto != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.layers_outlined, size: 16, color: AppColors.muted),
                              const SizedBox(width: 6),
                              NumText(
                                '지난 사진 (${_previousPhoto!.recordDate.substring(5).replaceAll('-', '.')}) 겹쳐 보기',
                                style: AppText.number(size: 12, weight: FontWeight.w500, color: AppColors.muted),
                              ),
                            ],
                          ),
                          Slider(
                            value: _ghost,
                            max: 0.7,
                            onChanged: (value) => setState(() => _ghost = value),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          const Text('매번 같은 자리, 같은 자세로 찍으면 변화가 잘 보여요.', style: AppText.caption),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                AppCard(
                  child: WriteSection(
                    title: '체중',
                    trailing: Text('+${PointRules.weight}P', style: AppText.caption),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _weight,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: AppText.number(size: 28),
                          decoration: InputDecoration(
                            hintText: _lastWeight?.toStringAsFixed(1) ?? '0.0',
                            hintStyle: AppText.number(size: 28, weight: FontWeight.w500, color: AppColors.line),
                            suffixText: 'kg',
                            suffixStyle: AppText.label,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (final d in const [-0.5, -0.1, 0.1, 0.5]) ...[
                              if (d != -0.5) const SizedBox(width: 6),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                                  onPressed: () => _nudge(d),
                                  child: Text('${d > 0 ? '+' : ''}$d', style: AppText.number(size: 13)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: NumText(
                                _lastWeight == null ? '처음 남기는 체중이에요' : '지난 체중 ${_lastWeight!.toStringAsFixed(1)}kg',
                                style: AppText.number(size: 12, weight: FontWeight.w500, color: AppColors.faint),
                              ),
                            ),
                            if (delta != null)
                              NumText(
                                '시작 대비 ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}kg',
                                style: AppText.number(
                                  size: 12,
                                  color: delta <= 0 ? AppColors.success : AppColors.danger,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                AppCard(
                  child: WriteSection(
                    title: '한 줄 메모 (선택)',
                    child: TextField(
                      controller: _memo,
                      maxLength: 60,
                      decoration: const InputDecoration(hintText: '예: 야식의 유혹을 참아냄!', counterText: ''),
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
        label: canSave ? '저장하기 · +${_points}P' : '체중이나 사진을 넣어 주세요',
        saving: _saving,
        onPressed: canSave ? _save : null,
      ),
    );
  }
}
