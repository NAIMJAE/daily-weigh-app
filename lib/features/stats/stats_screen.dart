import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/daily_record.dart';
import '../../data/repositories/group_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/bmi_spectrum.dart';
import '../../shared/widgets/section_title.dart';
import '../../shared/widgets/ui_parts.dart';
import '../../shared/widgets/weight_chart.dart';
import '../home/home_controller.dart';
import '../session/session_controller.dart';

enum StatsPeriod { all, year, month, week }

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  var _period = StatsPeriod.all;
  var _selfOnly = false;
  var _absolute = false;
  var _offset = 0;
  List<DailyRecord> _records = [];
  List<GroupMate> _members = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await currentSession(ref);
    if (!mounted) return;
    final group = session.currentGroup;
    if (group == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final members = await ref.read(groupRepositoryProvider).fetchMembers(group.id);
      final userIds = _selfOnly ? [session.userId!] : members.map((m) => m.profile.id).toList();
      final records = await ref.read(recordRepositoryProvider).fetchForUsers(userIds);
      if (!mounted) return;
      setState(() {
        _members = members;
        _records = records;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorSnack(context, error);
    }
  }

  DateTimeRange? _range() {
    final now = DateTime.now();
    switch (_period) {
      case StatsPeriod.all:
        return null;
      case StatsPeriod.year:
        final start = DateTime(now.year - _offset, 1, 1);
        return DateTimeRange(start: start, end: DateTime(start.year + 1, 1, 0));
      case StatsPeriod.month:
        final start = DateTime(now.year, now.month - _offset, 1);
        return DateTimeRange(start: start, end: DateTime(start.year, start.month + 1, 0));
      case StatsPeriod.week:
        final start = startOfWeekMonday(now).subtract(Duration(days: 7 * _offset));
        return DateTimeRange(start: start, end: start.add(const Duration(days: 6)));
    }
  }

  String _rangeLabel() {
    final range = _range();
    if (range == null) return '';
    final s = range.start;
    final e = range.end;
    return switch (_period) {
      StatsPeriod.all => '',
      StatsPeriod.year => '${s.year}년',
      StatsPeriod.month => '${s.year}년 ${s.month}월',
      StatsPeriod.week => '${s.month}/${s.day} – ${e.month}/${e.day}',
    };
  }

  List<DailyRecord> get _filtered {
    final range = _range();
    if (range == null) {
      return _records.where((r) => r.weight != null).toList();
    }
    return _records.where((record) {
      if (record.weight == null) return false;
      final date = parseLocalDate(record.recordDate);
      return !date.isBefore(range.start) && !date.isAfter(range.end);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      if (previous?.value?.currentGroupId != next.value?.currentGroupId) {
        _load();
      }
    });
    ref.listen(recordRevisionProvider, (previous, next) {
      if (previous != next) _load();
    });
    final session = ref.watch(sessionProvider).value;
    final profile = session?.profile;
    final hideToggle = _members.length <= 1;

    return Scaffold(
      appBar: const AppTopBar(title: '통계', icon: Icons.insights_outlined),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('기간', style: AppText.title)),
                          SegmentedToggle<StatsPeriod>(
                            options: const [
                              (StatsPeriod.all, '전체'),
                              (StatsPeriod.year, '연간'),
                              (StatsPeriod.month, '월간'),
                              (StatsPeriod.week, '주간'),
                            ],
                            value: _period,
                            onChanged: (period) => setState(() {
                              _period = period;
                              _offset = 0;
                            }),
                          ),
                        ],
                      ),
                      // 기간 이동은 자기 줄에 둔다. 다른 버튼 자리가 밀리지 않게 '다음'은 숨기지 않고 비활성화한다.
                      if (_period != StatsPeriod.all) ...[
                        const SizedBox(height: AppSpacing.gap),
                        Row(
                          children: [
                            IconButton(
                              tooltip: '이전 기간',
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () => setState(() => _offset += 1),
                            ),
                            Expanded(
                              child: NumText(
                                _rangeLabel(),
                                textAlign: TextAlign.center,
                                style: AppText.number(size: 14),
                              ),
                            ),
                            IconButton(
                              tooltip: '다음 기간',
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _offset > 0 ? () => setState(() => _offset -= 1) : null,
                            ),
                          ],
                        ),
                      ],
                      if (!hideToggle) ...[
                        const SizedBox(height: AppSpacing.gap),
                        Row(
                          children: [
                            const Expanded(child: Text('보기', style: AppText.title)),
                            SegmentedToggle<bool>(
                              options: const [(false, '그룹 전체'), (true, '본인만')],
                              value: _selfOnly,
                              onChanged: (value) {
                                setState(() {
                                  _selfOnly = value;
                                  _loading = true;
                                });
                                _load();
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionTitle(
                        '체중 변화 그래프',
                        icon: Icons.trending_down,
                        trailing: SegmentedToggle<bool>(
                          options: const [(false, '변화량'), (true, '절대체중')],
                          value: _absolute,
                          onChanged: (value) => setState(() => _absolute = value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      WeightChart(
                        records: _filtered,
                        allRecords: _records,
                        profiles: {for (final member in _members) member.profile.id: member.profile},
                        absolute: _absolute,
                        myId: session?.userId,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionTitle('BMI 스펙트럼', icon: Icons.monitor_heart_outlined),
                      const SizedBox(height: 4),
                      BmiSpectrum(
                        pins: pinsFor(
                          profiles: _selfOnly || hideToggle
                              ? [?profile]
                              : [for (final member in _members) member.profile],
                          myId: session?.userId,
                          weightOf: (userId) {
                            final mine = _filtered.where((record) => record.userId == userId).toList()
                              ..sort((a, b) => b.recordDate.compareTo(a.recordDate));
                            return mine.isEmpty ? null : mine.first.weight;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selfOnly || hideToggle) ...[
                  const SizedBox(height: AppSpacing.section),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionTitle('이 기간의 기록', icon: Icons.list_alt_outlined),
                        const SizedBox(height: AppSpacing.gap),
                        for (final record
                            in (_filtered.where((r) => r.userId == session?.userId).toList()
                              ..sort((a, b) => b.recordDate.compareTo(a.recordDate))))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 84,
                                  child: Text(
                                    record.recordDate,
                                    style: AppText.number(size: 12, weight: FontWeight.w500),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    [
                                      if (record.weight != null) '${record.weight}kg',
                                      if (record.workoutSummary.isNotEmpty) record.workoutSummary,
                                      if (record.memo != null && record.memo!.isNotEmpty) record.memo!,
                                    ].join(' · '),
                                    style: AppText.label,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
