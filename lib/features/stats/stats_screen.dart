import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/local_date.dart';
import '../../data/models/daily_record.dart';
import '../../data/repositories/group_repository.dart';
import '../../shared/widgets/bmi_spectrum.dart';
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
    final session = ref.read(sessionProvider).value;
    final group = session?.currentGroup;
    if (group == null) {
      setState(() => _loading = false);
      return;
    }
    final members = await ref.read(groupRepositoryProvider).fetchMembers(group.id);
    final userIds = _selfOnly
        ? [session!.userId!]
        : members.map((m) => m.profile.id).toList();
    final records = await ref.read(recordRepositoryProvider).fetchForUsers(userIds);
    setState(() {
      _members = members;
      _records = records;
      _loading = false;
    });
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
      appBar: AppBar(title: const Text('통계')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final period in StatsPeriod.values)
                      ChoiceChip(
                        label: Text(switch (period) {
                          StatsPeriod.all => '전체',
                          StatsPeriod.year => '연간',
                          StatsPeriod.month => '월간',
                          StatsPeriod.week => '주간',
                        }),
                        selected: _period == period,
                        onSelected: (_) => setState(() {
                          _period = period;
                          _offset = 0;
                        }),
                      ),
                    if (_period != StatsPeriod.all) ...[
                      ActionChip(
                        label: const Text('이전'),
                        onPressed: () => setState(() => _offset += 1),
                      ),
                      if (_offset > 0)
                        ActionChip(
                          label: const Text('다음'),
                          onPressed: () => setState(() => _offset -= 1),
                        ),
                    ],
                    if (!hideToggle)
                      FilterChip(
                        label: const Text('본인만'),
                        selected: _selfOnly,
                        onSelected: (value) {
                          setState(() {
                            _selfOnly = value;
                            _loading = true;
                          });
                          _load();
                        },
                      ),
                    FilterChip(
                      label: const Text('절대 체중'),
                      selected: _absolute,
                      onSelected: (value) => setState(() => _absolute = value),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                WeightChart(
                    records: _filtered,
                    allRecords: _records,
                    profiles: {
                      for (final member in _members) member.profile.id: member.profile,
                    },
                    absolute: _absolute,
                  ),
                  const SizedBox(height: 16),
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
                  if (_selfOnly || hideToggle) ...[
                    const SizedBox(height: 16),
                    const Text('이 기간의 기록', style: TextStyle(fontWeight: FontWeight.w800)),
                    for (final record in (_filtered.where((r) => r.userId == session?.userId).toList()
                      ..sort((a, b) => b.recordDate.compareTo(a.recordDate))))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(record.recordDate),
                        subtitle: Text(
                          [
                            if (record.weight != null) '${record.weight}kg',
                            if (record.workoutSummary.isNotEmpty) record.workoutSummary,
                            if (record.memo != null && record.memo!.isNotEmpty) record.memo!,
                          ].join(' · '),
                        ),
                      ),
                  ],
              ],
            ),
    );
  }
}
