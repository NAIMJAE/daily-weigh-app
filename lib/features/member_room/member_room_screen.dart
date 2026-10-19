import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/daily_record.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/record_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/section_title.dart';
import '../../shared/widgets/status_chip.dart';
import '../../shared/widgets/ui_parts.dart';
import '../home/home_controller.dart';
import '../record/record_sheet.dart';
import '../safety/safety_controller.dart';
import '../session/session_controller.dart';
import '../../data/repositories/safety_repository.dart';
import '../workout/member_workout_card.dart';
import 'comment_sheet.dart';

class MemberRoomScreen extends ConsumerStatefulWidget {
  const MemberRoomScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<MemberRoomScreen> createState() => _MemberRoomScreenState();
}

class _MemberRoomScreenState extends ConsumerState<MemberRoomScreen> {
  Profile? _profile;
  List<DailyRecord> _records = [];
  List<PokeNotice> _pokes = [];
  var _loading = true;
  var _poking = false;
  var _showAllPokes = false;
  static const _pokePreview = 3;

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
      final match = members.where((m) => m.profile.id == widget.userId);
      // 지금 그룹의 멤버가 아니면 (나갔거나 강퇴됨) 이 그룹에서는 기록을 보여 주지 않는다.
      final records = match.isEmpty
          ? <DailyRecord>[]
          : await ref.read(recordRepositoryProvider).fetchForUser(widget.userId);
      final pokes = match.isNotEmpty && session.userId == widget.userId
          ? await ref.read(recordRepositoryProvider).fetchPokesFor(groupId: group.id, receiverId: widget.userId)
          : <PokeNotice>[];
      if (!mounted) return;
      setState(() {
        _profile = match.isEmpty ? null : match.first.profile;
        _records = records;
        _pokes = pokes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorSnack(context, error);
    }
  }

  Future<void> _poke(String? groupId) async {
    if (groupId == null || _poking) return;
    setState(() => _poking = true);
    try {
      await ref.read(recordRepositoryProvider).poke(groupId: groupId, receiverId: widget.userId);
      ref.invalidate(homeSnapshotProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('찌르기를 보냈습니다.')));
      }
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _poking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recordRevisionProvider, (previous, next) {
      if (previous != next) _load();
    });
    final session = ref.watch(sessionProvider).value;
    final mine = session?.userId == widget.userId;
    // 차단한 멤버의 사진은 숨긴다. 체중과 운동 같은 숫자 기록은 그대로 보인다.
    final blocked = ref.watch(blockedUsersProvider).value?.contains(widget.userId) ?? false;
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.nickname ?? '방'),
        actions: [
          if (!blocked)
            IconButton(
              tooltip: '사진 달력',
              onPressed: () => context.push('/calendar/${widget.userId}'),
              icon: const Icon(Icons.calendar_month),
            ),
          if (!mine && profile != null)
            PopupMenuButton<String>(
              tooltip: '더 보기',
              onSelected: (action) async {
                if (action == 'report') {
                  await showReportSheet(context, targetUserId: widget.userId, target: ReportTarget.user);
                } else if (action == 'block') {
                  await confirmBlock(context, ref, userId: widget.userId, nickname: profile.nickname);
                } else if (action == 'unblock') {
                  await unblock(context, ref, userId: widget.userId, nickname: profile.nickname);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'report', child: Text('신고하기')),
                PopupMenuItem(value: blocked ? 'unblock' : 'block', child: Text(blocked ? '차단 풀기' : '차단하기')),
              ],
            ),
        ],
      ),
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
                          Avatar(_profile?.nickname ?? '?', size: 44, highlight: mine),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profile?.nickname ?? '',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    if ((_profile?.title ?? '').isNotEmpty) StatusChip(_profile!.title),
                                    StatusChip(
                                      '${_profile?.currentStreak ?? 0}일 연속',
                                      tone: ChipTone.neutral,
                                      icon: Icons.local_fire_department,
                                    ),
                                    if (_records.isNotEmpty)
                                      StatusChip('기록 ${_records.length}일', tone: ChipTone.neutral, mono: true),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (blocked)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.mutedBg,
                            borderRadius: BorderRadius.circular(AppRadius.tile),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text('차단한 멤버예요. 사진과 댓글이 보이지 않아요.', style: AppText.label),
                              ),
                              TextButton(
                                onPressed: profile == null
                                    ? null
                                    : () => unblock(context, ref, userId: widget.userId, nickname: profile.nickname),
                                child: const Text('차단 풀기'),
                              ),
                            ],
                          ),
                        )
                      else if (mine)
                        FilledButton.icon(
                          onPressed: () => context.push('/overlay/${widget.userId}'),
                          icon: const Icon(Icons.compare_outlined, size: 18),
                          label: const Text('겹쳐보기'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: _profile == null || _poking ? null : () => _poke(session?.currentGroup?.id),
                          icon: const Icon(Icons.touch_app_outlined, size: 18),
                          label: const Text('찌르기'),
                        ),
                    ],
                  ),
                ),
                // 친구 방에서는 루틴(가져가기)과 최근 운동을 본다. 같은 그룹 멤버일 때만 보인다.
                if (!mine && _profile != null) ...[
                  const SizedBox(height: AppSpacing.section),
                  MemberWorkoutCard(userId: widget.userId, nickname: _profile!.nickname),
                ],
                if (mine && _pokes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.section),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionTitle(
                          '받은 찌르기',
                          icon: Icons.touch_app_outlined,
                          trailing: _pokes.length > _pokePreview
                              ? TextButton(
                                  onPressed: () => setState(() => _showAllPokes = !_showAllPokes),
                                  child: Text(_showAllPokes ? '접기' : '${_pokes.length}개 모두 보기'),
                                )
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.gap),
                        // 기록이 이 방의 본문이므로, 찌르기는 최근 몇 개만 보여 기록을 아래로 밀어내지 않는다.
                        for (final poke in _showAllPokes ? _pokes : _pokes.take(_pokePreview))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Avatar(poke.senderName, size: 24),
                                const SizedBox(width: 8),
                                Expanded(child: Text('${poke.senderName}님이 찔렀습니다', style: AppText.body)),
                                NumText(
                                  '${poke.createdAt.month}/${poke.createdAt.day} ${poke.createdAt.hour.toString().padLeft(2, '0')}:${poke.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: AppText.number(size: 11, weight: FontWeight.w500, color: AppColors.faint),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.section),
                const SectionTitle('기록', icon: Icons.history),
                const SizedBox(height: AppSpacing.gap),
                if (_profile == null)
                  const Text('지금 그룹의 멤버가 아닙니다.', style: AppText.label)
                else if (_records.isEmpty)
                  const Text('아직 기록이 없습니다.', style: AppText.label),
                for (final record in _records) _RecordTile(record: record, mine: mine, hidePhotos: blocked),
              ],
            ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.mine, this.hidePhotos = false});

  final DailyRecord record;
  final bool mine;

  /// 차단한 멤버의 방에서는 사진(과 그 댓글)을 보이지 않는다.
  final bool hidePhotos;

  // 사진은 글 아래 줄에 둔다. 오른쪽에 두면 좁은 화면에서 날짜가 '2026-10-1 / 6'처럼 쪼개진다.
  @override
  Widget build(BuildContext context) {
    final detail = [
      if (record.weight != null) '${record.weight}kg',
      if (record.workoutSummary.isNotEmpty) record.workoutSummary,
      if (record.memo != null && record.memo!.isNotEmpty) record.memo!,
    ].join(' · ');
    final hasPhoto = !hidePhotos && (record.bodyPhotoUrl != null || record.mealPhotoUrl != null);
    final editable = mine && record.recordDate == localDateString();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gap),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(record.recordDate, style: AppText.number(size: 13))),
                if (editable)
                  IconButton(
                    tooltip: '오늘 기록 고치기',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit),
                    onPressed: () => showRecordSheet(context),
                  ),
              ],
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(detail, style: const TextStyle(color: AppColors.muted)),
            ],
            if (hasPhoto) ...[
              const SizedBox(height: AppSpacing.gap),
              Wrap(
                spacing: AppSpacing.gap,
                runSpacing: AppSpacing.gap,
                children: [
                  if (record.bodyPhotoUrl != null)
                    _PhotoThumb(
                      url: record.bodyPhotoUrl!,
                      cacheKey: record.bodyPhotoCacheKey,
                      label: '눈바디',
                      onTap: () => showPhotoComments(context: context, record: record, photoKind: 'body'),
                    ),
                  if (record.mealPhotoUrl != null)
                    _PhotoThumb(
                      url: record.mealPhotoUrl!,
                      cacheKey: record.mealPhotoCacheKey,
                      label: '식단',
                      onTap: () => showPhotoComments(context: context, record: record, photoKind: 'meal'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.url, required this.cacheKey, required this.label, required this.onTap});

  final String url;
  final String? cacheKey;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label 사진과 댓글 보기',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          child: SizedBox(
            width: 64,
            height: 64,
            child: CachedNetworkImage(imageUrl: url, cacheKey: cacheKey, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}
