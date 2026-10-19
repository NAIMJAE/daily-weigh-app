import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/error_message.dart';
import '../../data/models/daily_record.dart';
import '../../shared/widgets/photo_viewer.dart';
import '../../core/theme/app_text.dart';
import '../../data/repositories/safety_repository.dart';
import '../home/home_controller.dart';
import '../safety/safety_controller.dart';
import '../session/session_controller.dart';

Future<void> showPhotoComments({
  required BuildContext context,
  required DailyRecord record,
  required String photoKind,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // 탭 화면에서 열어도 하단 탭을 덮고, 길어져도 상태 표시줄 아래에서 멈춘다.
    useRootNavigator: true,
    useSafeArea: true,
    backgroundColor: AppColors.canvas,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
    builder: (context) => CommentSheet(record: record, photoKind: photoKind),
  );
}

class CommentSheet extends ConsumerStatefulWidget {
  const CommentSheet({super.key, required this.record, required this.photoKind});

  final DailyRecord record;
  final String photoKind;

  @override
  ConsumerState<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends ConsumerState<CommentSheet> {
  final _text = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  var _loading = true;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final groupId = (await currentSession(ref)).currentGroup?.id;
    if (!mounted) return;
    if (groupId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final rows = await ref.read(recordRepositoryProvider).fetchComments(groupId: groupId, recordId: widget.record.id);
      if (!mounted) return;
      setState(() {
        _comments = rows.where((row) => row['photo_kind'] == widget.photoKind).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorSnack(context, error);
    }
  }

  Future<void> _delete(String commentId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글을 지울까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(recordRepositoryProvider).deleteComment(commentId);
      await _load();
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    }
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    final groupId = ref.read(sessionProvider).value?.currentGroup?.id;
    if (body.isEmpty || groupId == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(recordRepositoryProvider)
          .addComment(groupId: groupId, recordId: widget.record.id, photoKind: widget.photoKind, body: body);
      _text.clear();
      await _load();
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final screen = MediaQuery.sizeOf(context).height;
    final meal = widget.photoKind == 'meal';
    final url = meal ? widget.record.mealPhotoUrl : widget.record.bodyPhotoUrl;
    final cacheKey = meal ? widget.record.mealPhotoCacheKey : widget.record.bodyPhotoCacheKey;
    final title = '${widget.record.recordDate} ${meal ? '식단' : '눈바디'}';
    final myId = ref.watch(sessionProvider).value?.userId;
    final ownerId = widget.record.userId;
    final mineRecord = ownerId == myId;
    // 차단한 사람의 댓글은 서버가 빼 주지만, 방금 차단한 경우를 위해 여기서도 거른다.
    final blocked = ref.watch(blockedUsersProvider).value ?? const <String>{};
    final comments = [
      for (final row in _comments)
        if (!blocked.contains(row['author_id'])) row,
    ];
    // 키보드가 올라오면 사진을 숨겨 댓글 입력칸 자리를 확보한다.
    final showPhoto = url != null && bottom == 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, AppSpacing.page + bottom),
      child: SizedBox(
        height: showPhoto ? screen * 0.78 : 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(meal ? '식단 댓글' : '눈바디 댓글', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                if (!mineRecord && url != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.muted, minimumSize: const Size(0, 32)),
                    onPressed: () => showReportSheet(
                      context,
                      targetUserId: ownerId,
                      target: meal ? ReportTarget.mealPhoto : ReportTarget.bodyPhoto,
                      recordId: widget.record.id,
                    ),
                    icon: const Icon(Icons.flag_outlined, size: 16),
                    label: const Text('사진 신고'),
                  ),
              ],
            ),
            const Text('이 그룹에서만 보입니다. 사진을 누르면 크게 봅니다.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 12),
            if (showPhoto) ...[
              SizedBox(
                height: screen * 0.36,
                child: GestureDetector(
                  onTap: () => showPhotoViewer(context, url: url, cacheKey: cacheKey, title: title),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: ColoredBox(
                      color: AppColors.stage,
                      child: CachedNetworkImage(imageUrl: url, cacheKey: cacheKey, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : comments.isEmpty
                  ? const Text('아직 댓글이 없습니다.')
                  : ListView(
                      children: [
                        for (final row in comments)
                          _CommentTile(
                            row: row,
                            canDelete: row['author_id'] == myId || mineRecord,
                            canReport: row['author_id'] != myId,
                            onDelete: () => _delete(row['id'] as String),
                            onReport: () => showReportSheet(
                              context,
                              targetUserId: row['author_id'] as String,
                              target: ReportTarget.comment,
                              recordId: widget.record.id,
                              commentId: row['id'] as String,
                              commentBody: row['body'] as String?,
                            ),
                            onBlock: () => confirmBlock(
                              context,
                              ref,
                              userId: row['author_id'] as String,
                              nickname: (row['profiles'] as Map?)?['nickname'] as String? ?? '멤버',
                            ),
                          ),
                      ],
                    ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    maxLength: 300,
                    decoration: const InputDecoration(hintText: '댓글', counterText: ''),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send, color: AppColors.accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 댓글 한 줄. 내 댓글이나 내 사진의 댓글은 지울 수 있고, 다른 사람 댓글은 신고·차단할 수 있다.
class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.row,
    required this.canDelete,
    required this.canReport,
    required this.onDelete,
    required this.onReport,
    required this.onBlock,
  });

  final Map<String, dynamic> row;
  final bool canDelete;
  final bool canReport;
  final VoidCallback onDelete;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 4),
      title: Text((row['profiles'] as Map?)?['nickname'] as String? ?? '멤버', style: AppText.title),
      subtitle: Text('${row['body']}', style: AppText.body),
      trailing: canDelete || canReport
          ? PopupMenuButton<String>(
              tooltip: '댓글 메뉴',
              icon: const Icon(Icons.more_vert, size: 18, color: AppColors.faint),
              onSelected: (action) => switch (action) {
                'delete' => onDelete(),
                'report' => onReport(),
                _ => onBlock(),
              },
              itemBuilder: (context) => [
                if (canDelete) const PopupMenuItem(value: 'delete', child: Text('지우기')),
                if (canReport) const PopupMenuItem(value: 'report', child: Text('신고하기')),
                if (canReport) const PopupMenuItem(value: 'block', child: Text('이 멤버 차단하기')),
              ],
            )
          : null,
    );
  }
}
