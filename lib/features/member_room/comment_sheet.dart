import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/error_message.dart';
import '../../data/models/daily_record.dart';
import '../../shared/widgets/photo_viewer.dart';
import '../home/home_controller.dart';
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
    // 키보드가 올라오면 사진을 숨겨 댓글 입력칸 자리를 확보한다.
    final showPhoto = url != null && bottom == 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, AppSpacing.page + bottom),
      child: SizedBox(
        height: showPhoto ? screen * 0.78 : 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(meal ? '식단 댓글' : '눈바디 댓글', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
                  : _comments.isEmpty
                  ? const Text('아직 댓글이 없습니다.')
                  : ListView(
                      children: [
                        for (final row in _comments)
                          ListTile(
                            dense: true,
                            title: Text((row['profiles'] as Map?)?['nickname'] as String? ?? '멤버'),
                            subtitle: Text('${row['body']}'),
                          ),
                      ],
                    ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    decoration: const InputDecoration(hintText: '댓글'),
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
