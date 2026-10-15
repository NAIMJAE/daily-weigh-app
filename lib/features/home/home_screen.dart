import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/daily_record.dart';
import '../../data/models/group.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/group_repository.dart';
import '../../shared/widgets/bmi_spectrum.dart';
import '../../shared/widgets/weight_chart.dart';
import '../session/session_controller.dart';
import 'home_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _absolute = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    final snapshot = ref.watch(homeSnapshotProvider);
    final group = session?.currentGroup;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: _GroupSwitcher(
          groups: session?.groups ?? [],
          current: group,
          onSelected: (id) {
            ref.read(sessionProvider.notifier).selectGroup(id);
            ref.invalidate(homeSnapshotProvider);
          },
        ),
        actions: [
          if (group != null && !group.isPersonal && group.inviteCode != null)
            IconButton(
              tooltip: '초대',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: group.inviteCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('초대 코드 ${group.inviteCode}를 복사했습니다.')),
                );
              },
              icon: const Icon(Icons.person_add_alt_1),
            ),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (data) {
          final profile = session?.profile;
          final me = session?.userId == null ? null : data.todayRecords[session!.userId];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TodayCard(profile: profile, today: me),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text('그룹 체중', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  FilterChip(
                    label: const Text('절대 체중'),
                    selected: _absolute,
                    onSelected: (value) => setState(() => _absolute = value),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              WeightChart(
                records: data.history,
                allRecords: data.history,
                profiles: {for (final member in data.members) member.profile.id: member.profile},
                absolute: _absolute,
              ),
              const SizedBox(height: 16),
              BmiSpectrum(
                pins: pinsFor(
                  profiles: [for (final member in data.members) member.profile],
                  myId: session?.userId,
                  weightOf: (userId) => data.todayRecords[userId]?.weight ?? _latestWeight(data.history, userId),
                ),
              ),
              const SizedBox(height: 16),
              const Text('멤버', style: TextStyle(fontWeight: FontWeight.w800)),
              if (data.members.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('이 방에 멤버가 없습니다.'),
                ),
              for (final member in data.members)
                _MemberTile(
                  member: member,
                  today: data.todayRecords[member.profile.id],
                  poked: data.pokedUserIds.contains(member.profile.id),
                  onTap: () => context.push('/room/${member.profile.id}'),
                ),
            ],
          );
        },
      ),
    );
  }

  double? _latestWeight(List<DailyRecord> history, String userId) {
    final mine = history.where((record) => record.userId == userId && record.weight != null).toList()
      ..sort((a, b) => b.recordDate.compareTo(a.recordDate));
    return mine.isEmpty ? null : mine.first.weight;
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.profile, required this.today});

  final Profile? profile;
  final DailyRecord? today;

  @override
  Widget build(BuildContext context) {
    final logged = today?.isLogged ?? false;
    final weight = today?.weight;
    final start = profile?.startWeight;
    final delta = weight != null && start != null ? weight - start : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              logged ? '오늘 출석' : '오늘 아직 기록 없음',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(weight == null ? '오늘 체중 —' : '오늘 체중 ${weight.toStringAsFixed(1)}kg'),
            Text(
              delta == null
                  ? '시작 체중 대비 —'
                  : '시작 대비 ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}kg',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.today,
    required this.poked,
    required this.onTap,
  });

  final GroupMate member;
  final DailyRecord? today;
  final bool poked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = member.profile;
    final logged = today?.isLogged ?? false;
    final detail = [
      if (!logged) '오늘 기록 없음',
      if (today?.weight != null) '${today!.weight!.toStringAsFixed(1)}kg',
      if (today != null && today!.workoutSummary.isNotEmpty) today!.workoutSummary,
      if (today?.hasBodyPhoto ?? false) '눈바디',
      if (today?.hasMealToday ?? false) '식단',
      if (poked) '찌름',
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(profile.nickname, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(detail),
      trailing: Text(
        profile.title.isEmpty ? '${profile.streakDays}일' : profile.title,
        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _GroupSwitcher extends StatelessWidget {
  const _GroupSwitcher({
    required this.groups,
    required this.current,
    required this.onSelected,
  });

  final List<Group> groups;
  final Group? current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const Text(AppConstants.appName);
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: current?.id ?? groups.first.id,
        isExpanded: true,
        items: [
          for (final group in groups)
            DropdownMenuItem(
              value: group.id,
              child: Text(group.isPersonal ? '${group.name} · 개인' : group.name),
            ),
        ],
        onChanged: (id) {
          if (id != null) onSelected(id);
        },
      ),
    );
  }
}
