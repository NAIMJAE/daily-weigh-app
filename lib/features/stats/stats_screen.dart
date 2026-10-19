import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/daily_record.dart';
import '../../data/models/meal_entry.dart';
import '../../data/models/workout_routine.dart';
import '../../data/repositories/group_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/bmi_spectrum.dart';
import '../../shared/widgets/section_title.dart';
import '../../shared/widgets/ui_parts.dart';
import '../../shared/widgets/weight_chart.dart';
import '../home/home_controller.dart';
import '../records/record_browser.dart';
import '../records/records_controller.dart';
import '../session/session_controller.dart';
import '../workout/active_workout_controller.dart';
import 'group_stats.dart';
import 'record_stats.dart';

/// 기록 화면의 [월 / 주 / 일]처럼 기간을 고른다. 연은 월별, 월은 주별 평균이고, 주와 직접(30일까지)은 하루씩 본다.
enum StatsPeriod { year, month, week, custom }

/// 통계 종류. 그룹 전체로 보면 식단과 운동도 멤버끼리 비교한다.
enum StatsTab { weight, meal, workout }

/// 그룹 통계용 기록. 키는 '사람 id들|시작일|종료일'이다. 기록이 바뀌면 다시 읽는다.
final _groupMealsProvider = FutureProvider.family<List<MealEntry>, String>((ref, key) {
  ref.watch(recordRevisionProvider);
  final (ids, from, to) = _splitKey(key);
  return ref.read(recordRepositoryProvider).fetchMealEntriesForUsers(ids, from: from, to: to);
});

final _groupSessionsProvider = FutureProvider.family<List<WorkoutSession>, String>((ref, key) {
  ref.watch(recordRevisionProvider);
  final (ids, from, to) = _splitKey(key);
  return ref.read(routineRepositoryProvider).fetchSessionsForUsers(ids, from: from, to: to);
});

(List<String>, String, String) _splitKey(String key) {
  final parts = key.split('|');
  return (parts[0].split(','), parts[1], parts[2]);
}

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  var _tab = StatsTab.weight;
  var _period = StatsPeriod.month;
  var _selfOnly = false;
  var _absolute = false;
  var _offset = 0;
  DateTimeRange? _custom;
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

  DateTimeRange get _range {
    final now = DateTime.now();
    switch (_period) {
      case StatsPeriod.year:
        final start = DateTime(now.year - _offset, 1, 1);
        return DateTimeRange(start: start, end: DateTime(start.year, 12, 31));
      case StatsPeriod.month:
        final start = DateTime(now.year, now.month - _offset, 1);
        return DateTimeRange(start: start, end: DateTime(start.year, start.month + 1, 0));
      case StatsPeriod.week:
        final start = startOfWeekMonday(now).subtract(Duration(days: 7 * _offset));
        return DateTimeRange(start: start, end: start.add(const Duration(days: 6)));
      case StatsPeriod.custom:
        return _custom ??
            DateTimeRange(start: DateTime(now.year, now.month, now.day - maxCustomDays + 1), end: now);
    }
  }

  StatsUnit get _unit => switch (_period) {
    StatsPeriod.year => StatsUnit.month,
    StatsPeriod.month => StatsUnit.week,
    StatsPeriod.week => StatsUnit.day,
    StatsPeriod.custom => StatsUnit.day,
  };

  String get _rangeLabel {
    final s = _range.start;
    final e = _range.end;
    String two(int value) => value.toString().padLeft(2, '0');
    return switch (_period) {
      StatsPeriod.year => '${s.year}',
      StatsPeriod.month => '${s.year}.${two(s.month)}',
      StatsPeriod.week => '${s.month}/${s.day} – ${e.month}/${e.day}',
      StatsPeriod.custom =>
        s.year == e.year
            ? '${s.year}.${two(s.month)}.${two(s.day)} – ${two(e.month)}.${two(e.day)}'
            : '${s.year}.${two(s.month)}.${two(s.day)} – ${e.year}.${two(e.month)}.${two(e.day)}',
    };
  }

  bool get _groupView => !_selfOnly && _members.length > 1;

  /// 나 먼저, 나머지는 그룹 멤버 순서. 세 탭의 그래프가 같은 사람에게 같은 색을 쓴다.
  List<StatsMember> _statsMembers(String? myId) {
    final ordered = [
      ..._members.where((mate) => mate.profile.id == myId),
      ..._members.where((mate) => mate.profile.id != myId),
    ];
    return [
      for (var i = 0; i < ordered.length; i++)
        StatsMember(
          id: ordered[i].profile.id,
          name: ordered[i].profile.nickname,
          color: AppColors.chartSeries[i % AppColors.chartSeries.length],
        ),
    ];
  }

  String _groupKey(List<StatsMember> members) =>
      '${members.map((m) => m.id).join(',')}|${localDateString(_range.start)}|${localDateString(_range.end)}';

  bool _inRange(String recordDate) {
    final date = parseLocalDate(recordDate);
    return !date.isBefore(_range.start) && !date.isAfter(_range.end);
  }

  List<DailyRecord> get _filtered => [
    for (final record in _records)
      if (record.weight != null && _inRange(record.recordDate)) record,
  ];

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _custom,
      helpText: '기간 고르기 (최대 $maxCustomDays일)',
      saveText: '확인',
    );
    if (picked == null || !mounted) return;
    final range = clampCustomRange(picked);
    if (range.end != DateTime(picked.end.year, picked.end.month, picked.end.day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최대 $maxCustomDays일까지 볼 수 있어서 시작일부터 $maxCustomDays일로 맞췄어요.')),
      );
    }
    setState(() {
      _custom = range;
      _period = StatsPeriod.custom;
    });
  }

  void _selectPeriod(StatsPeriod period) {
    if (period == StatsPeriod.custom) {
      // 처음 고를 때는 달력부터 연다. 이미 고른 기간이 있으면 그 기간으로 돌아간다.
      if (_custom == null) {
        _pickRange();
      } else {
        setState(() => _period = period);
      }
      return;
    }
    setState(() {
      _period = period;
      _offset = 0;
    });
  }

  Widget _periodHeader() {
    if (_period == StatsPeriod.custom) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextButton.icon(
          onPressed: _pickRange,
          icon: const Icon(Icons.date_range, size: 18),
          label: NumText(_rangeLabel, style: AppText.number(size: 15, color: AppColors.accent)),
        ),
      );
    }
    return Row(
      children: [
        IconButton(
          tooltip: '이전',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() => _offset += 1),
        ),
        Expanded(
          child: NumText(_rangeLabel, textAlign: TextAlign.center, style: AppText.number(size: 15)),
        ),
        // 오늘이 든 기간 다음으로는 넘기지 않는다. 자리가 밀리지 않게 숨기지 않고 비활성화한다.
        IconButton(
          tooltip: '다음',
          icon: const Icon(Icons.chevron_right),
          onPressed: _offset > 0 ? () => setState(() => _offset -= 1) : null,
        ),
      ],
    );
  }

  List<Widget> _mealCards(List<StatsMember> members) {
    if (_groupView) {
      return [
        ref.watch(_groupMealsProvider(_groupKey(members))).when(
              loading: () => const AppCard(
                child: SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
              ),
              error: (error, _) => AppCard(child: Text(friendlyError(error), style: AppText.label)),
              data: (entries) => MemberMealCategoryCard(members: members, entries: entries),
            ),
      ];
    }
    final entries = ref.watch(myMealEntriesProvider);
    return [
      entries.when(
        loading: () => const AppCard(
          child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
        ),
        error: (error, _) => AppCard(child: Text(friendlyError(error), style: AppText.label)),
        data: (byKey) => MealCategoryCard(
          entries: [
            for (final entry in byKey.values)
              if (_inRange(entry.recordDate)) entry,
          ],
        ),
      ),
    ];
  }

  List<Widget> _workoutCards(List<StatsMember> members) {
    if (_groupView) {
      return [
        ref.watch(_groupSessionsProvider(_groupKey(members))).when(
              loading: () => const AppCard(
                child: SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              ),
              error: (error, _) => AppCard(child: Text(friendlyError(error), style: AppText.label)),
              data: (sessions) => MemberVolumeCard(members: members, sessions: sessions, unit: _unit, range: _range),
            ),
      ];
    }
    final sessions = ref.watch(allMySessionsProvider);
    return [
      sessions.when(
        loading: () => const AppCard(
          child: SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
        ),
        error: (error, _) => AppCard(child: Text(friendlyError(error), style: AppText.label)),
        data: (all) {
          final inRange = [
            for (final session in all)
              if (_inRange(session.recordDate)) session,
          ];
          return VolumeTrendCard(
            sessions: inRange,
            buckets: volumeBuckets(inRange, range: _range, unit: _unit),
          );
        },
      ),
    ];
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
    final range = _range;
    final unit = _unit;
    final members = _statsMembers(session?.userId);

    return Scaffold(
      appBar: const AppTopBar(title: '통계', icon: Icons.insights_outlined),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                PillTabs<StatsTab>(
                  options: const [
                    (StatsTab.weight, '체중', Icons.monitor_weight_outlined),
                    (StatsTab.meal, '식단', Icons.restaurant_outlined),
                    (StatsTab.workout, '운동', Icons.fitness_center),
                  ],
                  value: _tab,
                  onChanged: (tab) => setState(() => _tab = tab),
                ),
                const SizedBox(height: AppSpacing.gap),
                PillTabs<StatsPeriod>(
                  options: const [
                    (StatsPeriod.year, '연', null),
                    (StatsPeriod.month, '월', null),
                    (StatsPeriod.week, '주', null),
                    (StatsPeriod.custom, '직접', Icons.date_range),
                  ],
                  value: _period,
                  onChanged: _selectPeriod,
                ),
                const SizedBox(height: AppSpacing.section),
                AppCard(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _periodHeader(),
                      if (!hideToggle)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          child: Row(
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
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                if (_tab == StatsTab.meal) ..._mealCards(members),
                if (_tab == StatsTab.workout) ..._workoutCards(members),
                if (_tab == StatsTab.weight) ...[
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
                        const SizedBox(height: 4),
                        Text(
                          unit == StatsUnit.day ? '하루마다 잰 체중' : '${unitAverageLabel(unit)} 체중',
                          style: AppText.caption,
                        ),
                        const SizedBox(height: 12),
                        WeightChart(
                          records: averageWeights(_filtered, unit),
                          allRecords: _records,
                          profiles: {for (final member in _members) member.profile.id: member.profile},
                          absolute: _absolute,
                          myId: session?.userId,
                          xLabel: (date) => bucketLabel(parseLocalDate(date), unit, range),
                          userOrder: [for (final member in members) member.id],
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
              ],
            ),
    );
  }
}
