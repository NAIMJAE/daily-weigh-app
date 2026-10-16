import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/daily_record.dart';
import '../../data/models/group.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/group_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/bmi_spectrum.dart';
import '../../shared/widgets/section_title.dart';
import '../../shared/widgets/status_chip.dart';
import '../../shared/widgets/ui_parts.dart';
import '../../shared/widgets/weight_chart.dart';
import '../record/record_sheet.dart';
import '../session/session_controller.dart';
import 'home_controller.dart';

/// 웹 대시보드와 같은 순서: 오늘 카드, BMI 스펙트럼, 체중 변화 그래프, 멤버.
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
      appBar: const AppTopBar(),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (data) {
          final profile = session?.profile;
          final myId = session?.userId;
          final me = myId == null ? null : data.todayRecords[myId];
          final profiles = {for (final member in data.members) member.profile.id: member.profile};
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(homeSnapshotProvider);
              await ref.read(homeSnapshotProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                _TodayCard(groupName: group?.name ?? '', profile: profile, today: me),
                const SizedBox(height: AppSpacing.section),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionTitle('BMI 스펙트럼', icon: Icons.monitor_heart_outlined),
                      const SizedBox(height: 4),
                      BmiSpectrum(
                        pins: pinsFor(
                          profiles: [for (final member in data.members) member.profile],
                          myId: myId,
                          weightOf: (userId) =>
                              data.todayRecords[userId]?.weight ?? _latestWeight(data.history, userId),
                        ),
                      ),
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
                        records: data.history,
                        allRecords: data.history,
                        profiles: profiles,
                        absolute: _absolute,
                        myId: myId,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionTitle(
                        '그룹 멤버 (${data.members.length}명)',
                        icon: Icons.group_outlined,
                        trailing: group != null && !group.isPersonal && group.inviteCode != null
                            ? _InviteButton(group: group)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      if (data.members.isEmpty) const Text('이 방에 멤버가 없습니다.', style: AppText.label),
                      for (final member in data.members) ...[
                        _MemberLine(
                          member: member,
                          today: data.todayRecords[member.profile.id],
                          poked: data.pokedUserIds.contains(member.profile.id),
                          isMe: member.profile.id == myId,
                          onTap: () => context.push('/room/${member.profile.id}'),
                        ),
                        const SizedBox(height: AppSpacing.gap),
                      ],
                    ],
                  ),
                ),
              ],
            ),
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
  const _TodayCard({required this.groupName, required this.profile, required this.today});

  final String groupName;
  final Profile? profile;
  final DailyRecord? today;

  @override
  Widget build(BuildContext context) {
    final logged = today?.isLogged ?? false;
    final weight = today?.weight;
    final start = profile?.startWeight;
    final delta = weight != null && start != null ? weight - start : null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(groupName, style: AppText.headline)),
              if (weight != null) Text('${weight.toStringAsFixed(1)}kg', style: AppText.number(size: 15)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text(logged ? '오늘의 출석 완료! 🎉' : '아직 오늘 기록이 없어요. 하나만 남겨도 출석이에요.', style: AppText.label)),
              if (delta != null)
                NumText(
                  '시작 대비 ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}kg',
                  style: AppText.number(
                    size: 11,
                    weight: FontWeight.w600,
                    color: delta <= 0 ? AppColors.success : AppColors.danger,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => showRecordSheet(context),
            icon: Icon(logged ? Icons.edit_outlined : Icons.add, size: 18),
            label: Text(logged ? '기록 수정하기' : '오늘 기록하기'),
          ),
        ],
      ),
    );
  }
}

class _MemberLine extends StatelessWidget {
  const _MemberLine({
    required this.member,
    required this.today,
    required this.poked,
    required this.isMe,
    required this.onTap,
  });

  final GroupMate member;
  final DailyRecord? today;
  final bool poked;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = member.profile;
    final logged = today?.isLogged ?? false;
    final detail = [
      if (today?.weight != null) '${today!.weight!.toStringAsFixed(1)}kg',
      if (today != null && today!.workoutSummary.isNotEmpty) today!.workoutSummary,
      if (today?.hasBodyPhoto ?? false) '눈바디',
      if (today?.hasMealToday ?? false) '식단',
      if (!logged) '오늘 기록 없음',
    ].join(' · ');
    return MemberRow(
      name: profile.nickname,
      subtitle: detail,
      isMe: isMe,
      isOwner: member.member.isOwner,
      onTap: onTap,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (profile.title.isNotEmpty)
            StatusChip(profile.title)
          else
            StatusChip(logged ? '출석' : '미출석', tone: logged ? ChipTone.success : ChipTone.neutral),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (poked) ...[
                const Icon(Icons.touch_app_outlined, size: 12, color: AppColors.accent),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.local_fire_department, size: 12, color: AppColors.accent),
              NumText(
                '${profile.currentStreak}일',
                style: AppText.number(size: 11, weight: FontWeight.w700, color: AppColors.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteButton extends StatelessWidget {
  const _InviteButton({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.chipFill),
        backgroundColor: AppColors.accentSoft,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      onPressed: () {
        Clipboard.setData(ClipboardData(text: group.inviteCode!));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('초대 코드 ${group.inviteCode}를 복사했습니다.')));
      },
      icon: const Icon(Icons.person_add_alt_1, size: 14),
      label: const Text('초대'),
    );
  }
}
