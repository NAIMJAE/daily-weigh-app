import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/daily_record.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/record_repository.dart';
import '../home/home_controller.dart';
import '../record/record_sheet.dart';
import '../session/session_controller.dart';
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
    final match = members.where((m) => m.profile.id == widget.userId);
    final records = await ref.read(recordRepositoryProvider).fetchForUser(widget.userId);
    final pokes = session?.userId == widget.userId
        ? await ref.read(recordRepositoryProvider).fetchPokesFor(
            groupId: group.id,
            receiverId: widget.userId,
          )
        : <PokeNotice>[];
    setState(() {
      _profile = match.isEmpty ? null : match.first.profile;
      _records = records;
      _pokes = pokes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recordRevisionProvider, (previous, next) {
      if (previous != next) _load();
    });
    final session = ref.watch(sessionProvider).value;
    final mine = session?.userId == widget.userId;
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.nickname ?? '방'),
        actions: [
          IconButton(
            tooltip: '사진 달력',
            onPressed: () => context.push('/calendar/${widget.userId}'),
            icon: const Icon(Icons.calendar_month),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Text(
                    _profile?.title.isEmpty ?? true
                        ? '${_profile?.streakDays ?? 0}일 스트릭'
                        : '${_profile!.title} · ${_profile!.streakDays}일',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                if (mine)
                  FilledButton(
                    onPressed: () => context.push('/overlay/${widget.userId}'),
                    child: const Text('겹쳐보기'),
                  )
                else
                  FilledButton(
                    onPressed: () async {
                      final groupId = session?.currentGroup?.id;
                      if (groupId == null) return;
                      await ref.read(recordRepositoryProvider).poke(
                        groupId: groupId,
                        receiverId: widget.userId,
                      );
                      ref.invalidate(homeSnapshotProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('찌르기를 보냈습니다.')),
                        );
                      }
                    },
                    child: const Text('찌르기'),
                  ),
                if (mine && _pokes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('이 방의 찌르기', style: TextStyle(fontWeight: FontWeight.w800)),
                  for (final poke in _pokes)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${poke.senderName}님이 찔렀습니다'),
                      subtitle: Text(
                        '${poke.createdAt.month}/${poke.createdAt.day} ${poke.createdAt.hour.toString().padLeft(2, '0')}:${poke.createdAt.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                const Text('기록', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                if (_records.isEmpty) const Text('아직 기록이 없습니다.', style: TextStyle(color: AppColors.muted)),
                for (final record in _records) _RecordTile(record: record, mine: mine),
              ],
            ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.mine});

  final DailyRecord record;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(record.recordDate),
        subtitle: Text(
          [
            if (record.weight != null) '${record.weight}kg',
            if (record.workoutSummary.isNotEmpty) record.workoutSummary,
            if (record.memo != null && record.memo!.isNotEmpty) record.memo!,
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (record.bodyPhotoUrl != null)
              GestureDetector(
                onTap: () => showPhotoComments(
                  context: context,
                  record: record,
                  photoKind: 'body',
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CachedNetworkImage(imageUrl: record.bodyPhotoUrl!, fit: BoxFit.cover),
                ),
              ),
            if (record.mealPhotoUrl != null)
              IconButton(
                tooltip: '식단 댓글',
                onPressed: () => showPhotoComments(
                  context: context,
                  record: record,
                  photoKind: 'meal',
                ),
                icon: const Icon(Icons.restaurant),
              ),
            if (mine && record.recordDate == localDateString())
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => showRecordSheet(context),
              ),
          ],
        ),
      ),
    );
  }
}
