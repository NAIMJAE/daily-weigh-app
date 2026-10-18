import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
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
import '../home/home_controller.dart';
import '../session/session_controller.dart';

/// 웹 마이페이지와 같은 구성: 프로필 카드(2×2 정보, BMI, 포인트·출석), 현재 그룹 카드, 멤버 목록.
class MyPageScreen extends ConsumerStatefulWidget {
  const MyPageScreen({super.key});

  @override
  ConsumerState<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends ConsumerState<MyPageScreen> {
  final _groupName = TextEditingController();
  final _invite = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _groupName.dispose();
    _invite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    final snapshot = ref.watch(homeSnapshotProvider).value;
    final profile = session?.profile;
    final group = session?.currentGroup;
    final myId = session?.userId;
    final members = snapshot?.members ?? const <GroupMate>[];
    final me = members.where((m) => m.profile.id == myId);
    final isOwner = me.isNotEmpty && me.first.member.isOwner;
    final latest = myId == null || snapshot == null ? null : _latestWeight(snapshot.history, myId);

    return Scaffold(
      appBar: const AppTopBar(title: '마이페이지', icon: Icons.person_outline),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          if (profile != null)
            _ProfileCard(
              profile: profile,
              groupName: group?.name,
              isOwner: isOwner && !(group?.isPersonal ?? true),
              latestWeight: latest,
              onEditNickname: () => _rename(profile.nickname),
              onEditBody: () => context.push('/edit-body'),
            ),
          if (group != null) ...[
            const SizedBox(height: AppSpacing.section),
            _GroupCard(
              group: group,
              memberCount: members.length,
              onRename: group.isPersonal ? () => _renameGroup(group) : null,
              onLeave: group.isPersonal || myId == null ? null : () => _leave(group, myId, members.length),
              onRotateCode: isOwner && !group.isPersonal ? () => _rotateCode(group) : null,
            ),
            const SizedBox(height: AppSpacing.section),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(
                    '그룹 멤버 (${members.length}명)',
                    icon: Icons.group_outlined,
                    trailing: const Text('가입 순', style: AppText.caption),
                  ),
                  const SizedBox(height: 12),
                  for (final member in members) ...[
                    MemberRow(
                      name: member.profile.nickname,
                      subtitle: [
                        if (member.profile.height != null) '${member.profile.height!.toStringAsFixed(0)}cm',
                        '시작 ${member.profile.startWeight == null ? '-' : member.profile.startWeight!.toStringAsFixed(1)}kg',
                      ].join(' · '),
                      isMe: member.profile.id == myId,
                      isOwner: member.member.isOwner && !group.isPersonal,
                      onTap: () => context.push('/room/${member.profile.id}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${member.profile.walletPoints}P', style: AppText.number(size: 12)),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_fire_department, size: 11, color: AppColors.accent),
                                  NumText(
                                    '${member.profile.currentStreak}일',
                                    style: AppText.number(size: 11, color: AppColors.accent),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (isOwner && !group.isPersonal && member.profile.id != myId) ...[
                            const SizedBox(width: 8),
                            _SmallDangerButton(label: '강퇴', onTap: () => _kick(group, myId!, member)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.gap),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('내 그룹', icon: Icons.layers_outlined),
                const SizedBox(height: 12),
                for (final g in session?.groups ?? <Group>[]) ...[
                  _GroupSwitchTile(
                    group: g,
                    selected: g.id == group?.id,
                    onTap: () {
                      ref.read(sessionProvider.notifier).selectGroup(g.id);
                      ref.invalidate(homeSnapshotProvider);
                    },
                  ),
                  const SizedBox(height: AppSpacing.gap),
                ],
                const Divider(height: 24),
                const Text('친구 그룹 만들기', style: AppText.title),
                const SizedBox(height: AppSpacing.gap),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _groupName,
                        decoration: const InputDecoration(hintText: '그룹 이름'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.gap),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(72, 44)),
                      onPressed: _busy ? null : _createGroup,
                      child: const Text('만들기'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('초대 코드로 들어가기', style: AppText.title),
                const SizedBox(height: AppSpacing.gap),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _invite,
                        textCapitalization: TextCapitalization.characters,
                        style: AppText.number(size: 14, weight: FontWeight.w600),
                        decoration: const InputDecoration(hintText: '예: 4ST854CH'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.gap),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(72, 44)),
                      onPressed: _busy ? null : _join,
                      child: const Text('참여'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          OutlinedButton.icon(
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('로그아웃'),
          ),
          const SizedBox(height: AppSpacing.gap),
          if (profile != null)
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => _deleteAccount(profile.username),
                style: TextButton.styleFrom(foregroundColor: AppColors.faint),
                child: const Text('회원 탈퇴'),
              ),
            ),
          const SizedBox(height: AppSpacing.page),
        ],
      ),
    );
  }

  double? _latestWeight(List<DailyRecord> history, String userId) {
    final mine = history.where((r) => r.userId == userId && r.weight != null).toList()
      ..sort((a, b) => b.recordDate.compareTo(a.recordDate));
    return mine.isEmpty ? null : mine.first.weight;
  }

  Future<void> _createGroup() async {
    // 저장 뒤 화면이 다시 그려져도 키보드가 다시 뜨지 않게 입력 칸에서 커서를 뺀다.
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).createFriendGroup(_groupName.text);
      _groupName.clear();
      await ref.read(sessionProvider.notifier).reload();
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).joinFriendGroup(_invite.text);
      _invite.clear();
      await ref.read(sessionProvider.notifier).reload();
      ref.invalidate(homeSnapshotProvider);
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(String current) async {
    final next = await _askText('닉네임 바꾸기', current);
    if (next == null || next.trim().isEmpty) return;
    await _run(() => ref.read(sessionProvider.notifier).updateNickname(next));
  }

  Future<void> _renameGroup(Group group) async {
    final next = await _askText('개인 그룹 이름', group.name);
    if (next == null || next.trim().isEmpty) return;
    await _run(() async {
      await ref.read(groupRepositoryProvider).renameGroup(group.id, next);
      await ref.read(sessionProvider.notifier).reload();
    });
  }

  Future<String?> _askText(String title, String initial) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('저장')),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  /// 그룹·프로필 변경을 실행하고, 실패하면 이유를 보여 준다.
  Future<bool> _run(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
      return false;
    }
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _kick(Group group, String ownerId, GroupMate member) async {
    final ok = await _confirm(
      '멤버 내보내기',
      '${member.profile.nickname}님을 ${group.name}에서 내보낼까요? 기록은 지워지지 않고, 초대 코드로도 다시 들어올 수 없습니다.',
      '내보내기',
    );
    if (!ok) return;
    final done = await _run(
      () => ref
          .read(groupRepositoryProvider)
          .kickMember(groupId: group.id, ownerId: ownerId, targetUserId: member.profile.id),
    );
    if (!done) return;
    await _run(() => ref.read(sessionProvider.notifier).reload());
    ref.invalidate(homeSnapshotProvider);
  }

  Future<void> _deleteAccount(String username) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteAccountDialog(username: username),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sessionProvider.notifier).deleteAccount();
      messenger.showSnackBar(const SnackBar(content: Text('탈퇴했습니다. 그동안 함께해 주셔서 고마워요.')));
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showErrorSnack(context, error);
      }
    }
  }

  Future<void> _rotateCode(Group group) async {
    final ok = await _confirm(
      '초대 코드 바꾸기',
      '새 코드를 만들면 지금 코드로는 더 들어올 수 없습니다. 이미 들어온 멤버는 그대로입니다.',
      '바꾸기',
    );
    if (!ok) return;
    final done = await _run(() => ref.read(groupRepositoryProvider).rotateInviteCode(group.id));
    if (!done) return;
    await _run(() => ref.read(sessionProvider.notifier).reload());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('초대 코드를 새로 만들었습니다.')));
    }
  }

  Future<void> _leave(Group group, String userId, int memberCount) async {
    final ok = await _confirm(
      '그룹 나가기',
      memberCount <= 1 ? '마지막 멤버라 나가면 ${group.name} 그룹이 삭제됩니다.' : '${group.name}에서 나갈까요? 내 기록은 지워지지 않습니다.',
      '나가기',
    );
    if (!ok) return;
    final done = await _run(() => ref.read(groupRepositoryProvider).leaveGroup(group: group, userId: userId));
    if (!done) return;
    await _run(() => ref.read(sessionProvider.notifier).reload());
    ref.invalidate(homeSnapshotProvider);
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.groupName,
    required this.isOwner,
    required this.latestWeight,
    required this.onEditNickname,
    required this.onEditBody,
  });

  final Profile profile;
  final String? groupName;
  final bool isOwner;
  final double? latestWeight;
  final VoidCallback onEditNickname;
  final VoidCallback onEditBody;

  String _kg(double? v) => v == null ? '미설정' : '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)} kg';

  @override
  Widget build(BuildContext context) {
    final bmi = bmiOf(heightCm: profile.height, weightKg: latestWeight ?? profile.startWeight);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(profile.nickname, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(profile.nickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        if (isOwner)
                          const StatusChip('방장', tone: ChipTone.warn, icon: Icons.workspace_premium_outlined),
                        if (profile.title.isNotEmpty) StatusChip(profile.title),
                      ],
                    ),
                    const SizedBox(height: 2),
                    NumText(
                      ['@${profile.username}', ?groupName].join(' · '),
                      style: AppText.number(size: 11, weight: FontWeight.w500, color: AppColors.faint),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.chipFill),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onPressed: onEditNickname,
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('닉네임'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: InfoTile(
                  icon: Icons.straighten,
                  label: '등록된 키',
                  value: profile.height == null ? '미설정' : '${profile.height!.toStringAsFixed(0)} cm',
                ),
              ),
              const SizedBox(width: AppSpacing.gap),
              Expanded(
                child: InfoTile(icon: Icons.scale_outlined, label: '최근 체중', value: _kg(latestWeight)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gap),
          Row(
            children: [
              Expanded(
                child: InfoTile(icon: Icons.radio_button_unchecked, label: '시작 체중', value: _kg(profile.startWeight)),
              ),
              const SizedBox(width: AppSpacing.gap),
              Expanded(
                child: InfoTile(
                  icon: Icons.track_changes,
                  label: '목표 체중',
                  value: _kg(profile.targetWeight),
                  valueColor: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gap),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const Icon(Icons.monitor_heart_outlined, size: 14, color: AppColors.accent),
                const SizedBox(width: 6),
                const Text('체질량지수(BMI): ', style: AppText.label),
                Text(bmi == null ? '-' : bmi.toStringAsFixed(1), style: AppText.number(size: 13)),
                const Spacer(),
                if (bmi != null)
                  StatusChip(
                    bmiCategory(bmi),
                    tone: bmi >= 25 ? ChipTone.danger : (bmi >= 23 ? ChipTone.warn : ChipTone.success),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onEditBody, child: const Text('신체 정보 수정')),
          ),
          const Divider(height: 8),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: '누적 포인트',
                    value: Text('${profile.walletPoints}P', style: AppText.number(size: 15)),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _Stat(
                    label: '연속 출석일',
                    value: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department, size: 16, color: AppColors.accent),
                        NumText('${profile.currentStreak}일째', style: AppText.number(size: 15, color: AppColors.accent)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppText.caption.copyWith(color: AppColors.muted)),
        const SizedBox(height: 4),
        value,
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.memberCount, this.onRename, this.onLeave, this.onRotateCode});

  final Group group;
  final int memberCount;
  final VoidCallback? onRename;
  final VoidCallback? onLeave;

  /// 방장만 있다. 강퇴했거나 코드가 새어 나갔을 때 코드를 바꾼다.
  final VoidCallback? onRotateCode;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('현재 활성 그룹', style: AppText.micro),
                    const SizedBox(height: 2),
                    Text(group.name, style: AppText.headline),
                    const SizedBox(height: 2),
                    Text(group.isPersonal ? '나만 보는 개인 그룹' : '총 $memberCount명 참여 중 · 최대 8명', style: AppText.label),
                  ],
                ),
              ),
              if (group.inviteCode != null)
                StatusChip('코드: ${group.inviteCode}', mono: true)
              else
                const StatusChip('개인', tone: ChipTone.neutral),
            ],
          ),
          if (group.inviteCode != null) ...[
            const Divider(height: 24),
            const Row(
              children: [
                Icon(Icons.share_outlined, size: 14, color: AppColors.accent),
                SizedBox(width: 6),
                Text('초대 코드', style: AppText.title),
              ],
            ),
            const SizedBox(height: AppSpacing.gap),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(group.inviteCode!, style: AppText.number(size: 14, weight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: AppSpacing.gap),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: group.inviteCode!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('초대 코드를 복사했습니다.')));
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('코드 복사'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Expanded(
                  child: Text('친구가 마이페이지에서 이 코드를 입력하면 이 그룹에 합류합니다.', style: AppText.caption),
                ),
                if (onRotateCode != null)
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: onRotateCode,
                    child: const Text('코드 바꾸기'),
                  ),
              ],
            ),
          ],
          if (onRename != null || onLeave != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onRename != null) TextButton(onPressed: onRename, child: const Text('이름 바꾸기')),
                if (onLeave != null)
                  TextButton(
                    onPressed: onLeave,
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Text('그룹 나가기'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupSwitchTile extends StatelessWidget {
  const _GroupSwitchTile({required this.group, required this.selected, required this.onTap});

  final Group group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentSoft : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        side: BorderSide(color: selected ? AppColors.chipFill : AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                group.isPersonal ? Icons.person_outline : Icons.group_outlined,
                size: 16,
                color: selected ? AppColors.accent : AppColors.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(group.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              if (group.isPersonal) const StatusChip('개인', tone: ChipTone.neutral),
              if (selected) ...[const SizedBox(width: 6), const Icon(Icons.check, size: 16, color: AppColors.accent)],
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallDangerButton extends StatelessWidget {
  const _SmallDangerButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: AppColors.danger,
        backgroundColor: AppColors.dangerSoft,
        side: const BorderSide(color: AppColors.dangerLine),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}

/// 탈퇴 확인. 지워지는 것을 알리고, 아이디를 똑같이 입력해야 탈퇴 버튼이 켜진다.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.username});

  final String username;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _matches => _typed.text.trim().toLowerCase() == widget.username;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('회원 탈퇴'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '체중, 눈바디·식단 사진, 운동, 루틴, 댓글, 포인트와 스트릭이 모두 지워지고 되돌릴 수 없습니다. '
            '친구 그룹에서는 나가게 되고, 방장이면 다음 멤버가 방장이 됩니다.',
            style: AppText.body,
          ),
          const SizedBox(height: 12),
          Text('계속하려면 아이디 ${widget.username}을(를) 입력하세요.', style: AppText.label),
          const SizedBox(height: 6),
          TextField(
            controller: _typed,
            autocorrect: false,
            decoration: InputDecoration(hintText: widget.username),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        TextButton(
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('탈퇴하기'),
        ),
      ],
    );
  }
}
