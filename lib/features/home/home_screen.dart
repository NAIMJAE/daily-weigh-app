import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/daily_record.dart';
import '../../data/models/group.dart';
import '../../data/models/meal_entry.dart';
import '../../data/repositories/group_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/section_title.dart';
import '../../shared/widgets/ui_parts.dart';
import '../../shared/widgets/weight_chart.dart';
import '../records/record_type.dart';
import '../records/records_controller.dart';
import '../session/session_controller.dart';
import '../workout/active_workout_controller.dart';
import '../workout/workout_controller.dart';
import '../workout/workout_start.dart';
import 'home_controller.dart';

/// 순서: 오늘 할 일, 체중 변화 그래프(최근 2주), 오늘 현황판.
/// 홈은 오늘 내가 할 일과 그룹의 체중 흐름을 본다. BMI와 긴 기간은 통계에 둔다.
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
          final myId = session?.userId;
          final profiles = {for (final member in data.members) member.profile.id: member.profile};
          // 나 먼저, 나머지는 그룹 멤버 순서. 그래프 선 색과 현황판의 색 점이 같은 순서를 쓴다.
          final ordered = [
            ...data.members.where((mate) => mate.profile.id == myId),
            ...data.members.where((mate) => mate.profile.id != myId),
          ];
          Color colorOf(int i) => AppColors.chartSeries[i % AppColors.chartSeries.length];
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(homeSnapshotProvider);
              await ref.read(homeSnapshotProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                _TodayTasks(today: myId == null ? null : data.todayRecords[myId]),
                const SizedBox(height: AppSpacing.section),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionTitle(
                        '체중 변화 (최근 2주)',
                        icon: Icons.trending_down,
                        trailing: SegmentedToggle<bool>(
                          options: const [(false, '변화량'), (true, '절대체중')],
                          value: _absolute,
                          onChanged: (value) => setState(() => _absolute = value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      WeightChart(
                        records: _recentTwoWeeks(data.history),
                        allRecords: data.history,
                        profiles: profiles,
                        absolute: _absolute,
                        myId: myId,
                        userOrder: [for (final mate in ordered) mate.profile.id],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                _TodayBoard(
                  members: ordered,
                  colorOf: colorOf,
                  data: data,
                  myId: myId,
                  group: group,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 홈 그래프는 오늘 포함 최근 14일만 그린다. 변화량의 0점은 전체 기록 기준 그대로다.
  List<DailyRecord> _recentTwoWeeks(List<DailyRecord> history) {
    final now = DateTime.now();
    final from = localDateString(DateTime(now.year, now.month, now.day - 13));
    return history.where((record) => record.recordDate.compareTo(from) >= 0).toList();
  }
}

// ---------------------------------------------------------------------------
// 오늘 할 일
// ---------------------------------------------------------------------------

/// 눈바디, 식단, 운동의 오늘 상태. 안 한 것을 누르면 바로 기록하고, 한 것을 누르면 기록 화면으로 간다.
class _TodayTasks extends ConsumerWidget {
  const _TodayTasks({required this.today});

  final DailyRecord? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = localDateString();
    final meals = ref.watch(myMealEntriesProvider).value ?? const <String, MealEntry>{};
    final mealCount = MealSlot.values.where((slot) => meals.containsKey(mealKey(date, slot))).length;
    final plan = ref.watch(todayPlanProvider).value;
    final active = ref.watch(activeWorkoutProvider).value;

    final weight = today?.weight;
    final bodyPhoto = today?.hasBodyPhoto ?? false;
    final bodyDone = weight != null || bodyPhoto;
    final workoutDone = today?.hasWorkout ?? false;
    final mealDone = mealCount > 0;
    final doneCount = [bodyDone, mealDone, workoutDone].where((done) => done).length;
    // 올클리어는 체중, 눈바디 사진, 운동(휴식 포함)이다. 식단은 들어가지 않는다.
    final allClear = weight != null && bodyPhoto && workoutDone;

    final String workoutStatus;
    if (workoutDone) {
      workoutStatus = (today?.isRestOnly ?? false) ? '오늘은 휴식' : '운동 완료';
    } else if (active != null) {
      workoutStatus = '진행 중 ${active.doneSets}/${active.totalSets}';
    } else if (plan?.next != null) {
      workoutStatus = '오늘은 ${plan!.next!.name}';
    } else {
      workoutStatus = '아직 안 했어요';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            '오늘 할 일',
            icon: Icons.task_alt,
            trailing: NumText(
              '$doneCount/3',
              style: AppText.number(size: 13, color: doneCount == 3 ? AppColors.success : AppColors.accent),
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _TaskTile(
                    type: RecordType.body,
                    done: bodyDone,
                    status: bodyDone
                        ? [if (weight != null) '${weight.toStringAsFixed(1)}kg', if (bodyPhoto) '사진'].join(' · ')
                        : '아직 안 했어요',
                    onTap: () => bodyDone ? context.go(RecordType.body.path) : context.push('/write/body'),
                  ),
                ),
                const SizedBox(width: AppSpacing.gap),
                Expanded(
                  child: _TaskTile(
                    type: RecordType.meal,
                    done: mealDone,
                    status: mealDone ? '$mealCount/4끼' : '아직 안 했어요',
                    onTap: () => mealCount == MealSlot.values.length
                        ? context.go(RecordType.meal.path)
                        : context.push('/write/meal'),
                  ),
                ),
                const SizedBox(width: AppSpacing.gap),
                Expanded(
                  child: _TaskTile(
                    type: RecordType.workout,
                    done: workoutDone,
                    status: workoutStatus,
                    onTap: () => workoutDone
                        ? context.go(RecordType.workout.path)
                        : showWorkoutStartSheet(context, ref),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            allClear
                ? '오늘 올클리어를 했어요 +${PointRules.allClear}P'
                : '체중 · 눈바디 사진 · 운동을 모두 하면 올클리어 +${PointRules.allClear}P',
            style: AppText.caption.copyWith(
              color: allClear ? AppColors.success : AppColors.faint,
              fontWeight: allClear ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.type, required this.done, required this.status, required this.onTap});

  final RecordType type;
  final bool done;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 안 한 일은 강조색 테두리로 눈에 띄게, 한 일은 차분하게 둔다.
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.tile),
      side: BorderSide(color: done ? AppColors.line : AppColors.accent.withValues(alpha: 0.5)),
    );
    return Material(
      color: done ? AppColors.canvas : AppColors.accentSoft,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconBadge(type.icon, size: 32),
                  if (done)
                    const Positioned(
                      right: -4,
                      bottom: -4,
                      child: Icon(Icons.check_circle, size: 16, color: AppColors.success),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(type.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              NumText(
                status,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppText.caption.copyWith(color: done ? AppColors.muted : AppColors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 오늘 현황판
// ---------------------------------------------------------------------------

/// 오늘 이 그룹에서 체중, 식단, 운동을 누가 했는지. 기록 안 한 멤버는 찌를 수 있다.
class _TodayBoard extends ConsumerStatefulWidget {
  const _TodayBoard({
    required this.members,
    required this.colorOf,
    required this.data,
    required this.myId,
    required this.group,
  });

  final List<GroupMate> members;
  final Color Function(int index) colorOf;
  final HomeSnapshot data;
  final String? myId;
  final Group? group;

  @override
  ConsumerState<_TodayBoard> createState() => _TodayBoardState();
}

class _TodayBoardState extends ConsumerState<_TodayBoard> {
  final _poking = <String>{};

  /// 오늘 체중과, 오늘 전 마지막 체중과의 차이.
  (double, double?)? _todayWeight(String userId) {
    final weight = widget.data.todayRecords[userId]?.weight;
    if (weight == null) return null;
    final today = localDateString();
    final before = widget.data.history
        .where((r) => r.userId == userId && r.weight != null && r.recordDate.compareTo(today) < 0)
        .toList()
      ..sort((a, b) => b.recordDate.compareTo(a.recordDate));
    return (weight, before.isEmpty ? null : weight - before.first.weight!);
  }

  Future<void> _poke(GroupMate mate) async {
    final groupId = widget.group?.id;
    if (groupId == null || _poking.contains(mate.profile.id)) return;
    setState(() => _poking.add(mate.profile.id));
    try {
      await ref.read(recordRepositoryProvider).poke(groupId: groupId, receiverId: mate.profile.id);
      ref.invalidate(homeSnapshotProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${mate.profile.nickname}님을 찔렀습니다.')));
      }
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _poking.remove(mate.profile.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final members = widget.members;
    final logged = members.where((mate) => widget.data.todayRecords[mate.profile.id]?.isLogged ?? false).length;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            '오늘 현황',
            icon: Icons.group_outlined,
            trailing: group != null && !group.isPersonal && group.inviteCode != null
                ? _InviteButton(group: group)
                : null,
          ),
          if (members.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                NumText('오늘 $logged/${members.length}명 기록', style: AppText.label),
                const SizedBox(width: AppSpacing.gap),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: logged / members.length,
                      minHeight: 6,
                      backgroundColor: AppColors.mutedBg,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (members.isEmpty) const Text('이 방에 멤버가 없습니다.', style: AppText.label),
          for (var i = 0; i < members.length; i++) ...[
            _BoardLine(
              mate: members[i],
              color: widget.colorOf(i),
              today: widget.data.todayRecords[members[i].profile.id],
              weight: _todayWeight(members[i].profile.id),
              isMe: members[i].profile.id == widget.myId,
              poked: widget.data.pokedUserIds.contains(members[i].profile.id),
              poking: _poking.contains(members[i].profile.id),
              onPoke: () => _poke(members[i]),
              onTap: () => context.push('/room/${members[i].profile.id}'),
            ),
            const SizedBox(height: AppSpacing.gap),
          ],
        ],
      ),
    );
  }
}

class _BoardLine extends StatelessWidget {
  const _BoardLine({
    required this.mate,
    required this.color,
    required this.today,
    required this.weight,
    required this.isMe,
    required this.poked,
    required this.poking,
    required this.onPoke,
    required this.onTap,
  });

  final GroupMate mate;
  final Color color;
  final DailyRecord? today;
  final (double, double?)? weight;
  final bool isMe;
  final bool poked;
  final bool poking;
  final VoidCallback onPoke;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = mate.profile;
    final logged = today?.isLogged ?? false;
    final String subtitle;
    if (weight != null) {
      final (kg, diff) = weight!;
      final change = diff == null
          ? ''
          : diff.abs() < 0.05
          ? ' (그대로)'
          : ' (${diff > 0 ? '+' : '−'}${diff.abs().toStringAsFixed(1)})';
      subtitle = '오늘 ${kg.toStringAsFixed(1)}kg$change';
    } else {
      subtitle = logged ? '오늘 체중은 아직' : '오늘 기록 없음';
    }
    return MemberRow(
      name: profile.nickname,
      markColor: color,
      subtitle: subtitle,
      isMe: isMe,
      isOwner: mate.member.isOwner,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DoneIcon(Icons.monitor_weight_outlined, done: today?.weight != null || (today?.hasBodyPhoto ?? false), label: '체중·눈바디'),
          _DoneIcon(Icons.restaurant_outlined, done: today?.hasMealToday ?? false, label: '식단'),
          _DoneIcon(Icons.fitness_center, done: today?.hasWorkout ?? false, label: '운동'),
          const SizedBox(width: 4),
          SizedBox(
            width: 52,
            child: isMe || logged
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.local_fire_department, size: 12, color: AppColors.accent),
                      NumText(
                        '${profile.currentStreak}일',
                        style: AppText.number(size: 11, weight: FontWeight.w700, color: AppColors.accent),
                      ),
                    ],
                  )
                // 오늘 기록이 없는 멤버만 찌를 수 있다. 오늘 이미 누가 찔렀으면 표시만 한다.
                : poked
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.touch_app_outlined, size: 12, color: AppColors.faint),
                      SizedBox(width: 2),
                      Text('찌름', style: AppText.caption),
                    ],
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.chipFill),
                      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    onPressed: poking ? null : onPoke,
                    child: const Text('찌르기'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DoneIcon extends StatelessWidget {
  const _DoneIcon(this.icon, {required this.done, required this.label});

  final IconData icon;
  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label ${done ? '함' : '안 함'}',
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.only(left: 3),
        decoration: BoxDecoration(
          color: done ? AppColors.successSoft : AppColors.mutedBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: done ? AppColors.success : AppColors.faint.withValues(alpha: 0.6)),
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
