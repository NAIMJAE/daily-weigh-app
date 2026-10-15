import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/daily_record.dart';
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
    final groupId = ref.read(sessionProvider).value?.currentGroup?.id;
    if (groupId == null) {
      setState(() => _loading = false);
      return;
    }
    final rows = await ref.read(recordRepositoryProvider).fetchComments(
      groupId: groupId,
      recordId: widget.record.id,
    );
    setState(() {
      _comments = rows.where((row) => row['photo_kind'] == widget.photoKind).toList();
      _loading = false;
    });
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    final groupId = ref.read(sessionProvider).value?.currentGroup?.id;
    if (body.isEmpty || groupId == null) return;
    await ref.read(recordRepositoryProvider).addComment(
      groupId: groupId,
      recordId: widget.record.id,
      photoKind: widget.photoKind,
      body: body,
    );
    _text.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.photoKind == 'meal' ? '식단 댓글' : '눈바디 댓글',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const Text('이 그룹에서만 보입니다.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 12),
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
                IconButton(onPressed: _send, icon: const Icon(Icons.send, color: AppColors.accent)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
