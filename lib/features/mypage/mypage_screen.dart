import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/group.dart';
import '../home/home_controller.dart';
import '../session/session_controller.dart';

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

  Future<void> _createGroup() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).createFriendGroup(_groupName.text);
      _groupName.clear();
      await ref.read(sessionProvider.notifier).reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).joinFriendGroup(_invite.text);
      _invite.clear();
      await ref.read(sessionProvider.notifier).reload();
      ref.invalidate(homeSnapshotProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    final profile = session?.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(profile?.nickname ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              TextButton(
                onPressed: () => _rename(profile?.nickname ?? ''),
                child: const Text('닉네임'),
              ),
            ],
          ),
          Text('@${profile?.username ?? ''}', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _chip('포인트 ${profile?.walletPoints ?? 0}'),
              _chip('스트릭 ${profile?.streakDays ?? 0}일'),
              if ((profile?.title ?? '').isNotEmpty) _chip(profile!.title),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '키 ${profile?.height ?? '-'}cm · 시작 ${profile?.startWeight ?? '-'}kg · 목표 ${profile?.targetWeight ?? '-'}kg',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => context.push('/edit-body'),
                child: const Text('신체 정보 수정'),
              ),
            ],
          ),
          const Divider(height: 32),
          const Text('그룹', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final group in session?.groups ?? <Group>[]) _groupTile(group, session?.userId),
          const SizedBox(height: 16),
          TextField(
            controller: _groupName,
            decoration: const InputDecoration(labelText: '친구 그룹 이름'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _createGroup,
            child: const Text('친구 그룹 만들기'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _invite,
            decoration: const InputDecoration(labelText: '초대 코드'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _join,
            child: const Text('코드로 들어가기'),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(String current) async {
    final controller = TextEditingController(text: current);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('닉네임'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('저장')),
        ],
      ),
    );
    if (next == null || next.trim().isEmpty) return;
    await ref.read(sessionProvider.notifier).updateNickname(next);
  }

  Widget _chip(String label) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }

  Future<void> _openGroup(Group group, String? userId) async {
    if (group.isPersonal) {
      final name = TextEditingController(text: group.name);
      final renamed = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('개인 그룹 이름'),
          content: TextField(controller: name),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(context, name.text), child: const Text('저장')),
          ],
        ),
      );
      if (renamed == null || renamed.trim().isEmpty) return;
      await ref.read(groupRepositoryProvider).renameGroup(group.id, renamed);
      await ref.read(sessionProvider.notifier).reload();
      return;
    }

    final members = await ref.read(groupRepositoryProvider).fetchMembers(group.id);
    if (!mounted) return;
    final me = members.where((m) => m.profile.id == userId);
    final isOwner = me.isNotEmpty && me.first.member.isOwner;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(group.name), subtitle: Text('초대 코드 ${group.inviteCode ?? ''}')),
            for (final member in members)
              ListTile(
                title: Text(member.profile.nickname),
                subtitle: Text(member.member.isOwner ? '방장' : '멤버'),
                trailing: isOwner && member.profile.id != userId
                    ? TextButton(
                        onPressed: () async {
                          await ref.read(groupRepositoryProvider).kickMember(
                            groupId: group.id,
                            ownerId: userId!,
                            targetUserId: member.profile.id,
                          );
                          if (context.mounted) Navigator.pop(context);
                          await ref.read(sessionProvider.notifier).reload();
                          ref.invalidate(homeSnapshotProvider);
                        },
                        child: const Text('강퇴'),
                      )
                    : null,
              ),
            ListTile(
              title: const Text('나가기'),
              onTap: () async {
                Navigator.pop(context);
                if (userId == null) return;
                await ref.read(groupRepositoryProvider).leaveGroup(group: group, userId: userId);
                await ref.read(sessionProvider.notifier).reload();
                ref.invalidate(homeSnapshotProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupTile(Group group, String? userId) {
    return Card(
      child: ListTile(
        title: Text(group.isPersonal ? '${group.name} · 개인' : group.name),
        subtitle: group.isPersonal
            ? const Text('이름만 바꿀 수 있습니다')
            : Text(group.inviteCode == null ? '' : '초대 코드 ${group.inviteCode}'),
        trailing: group.isPersonal
            ? null
            : IconButton(
                icon: const Icon(Icons.copy),
                onPressed: group.inviteCode == null
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: group.inviteCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('초대 코드를 복사했습니다.')),
                        );
                      },
              ),
        onTap: () => _openGroup(group, userId),
      ),
    );
  }
}
