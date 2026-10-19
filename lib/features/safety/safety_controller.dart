import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../data/repositories/safety_repository.dart';
import '../session/session_controller.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) => SafetyRepository());

/// 내가 차단한 사람들. 차단하거나 풀면 다시 읽는다.
final blockedUsersProvider = FutureProvider<Set<String>>((ref) async {
  final userId = (await ref.watch(sessionProvider.future)).userId;
  if (userId == null) return {};
  return ref.read(safetyRepositoryProvider).fetchBlockedIds();
});

/// 신고 시트. 사유를 고르고 설명을 조금 적을 수 있다. 보내면 true.
Future<bool> showReportSheet(
  BuildContext context, {
  required String targetUserId,
  required ReportTarget target,
  String? recordId,
  String? commentId,
  String? commentBody,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
    builder: (context) => _ReportSheet(
      targetUserId: targetUserId,
      target: target,
      recordId: recordId,
      commentId: commentId,
      commentBody: commentBody,
    ),
  );
  return sent ?? false;
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.targetUserId,
    required this.target,
    this.recordId,
    this.commentId,
    this.commentBody,
  });

  final String targetUserId;
  final ReportTarget target;
  final String? recordId;
  final String? commentId;
  final String? commentBody;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportReason? _reason;
  final _detail = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(safetyRepositoryProvider).report(
        targetUserId: widget.targetUserId,
        target: widget.target,
        reason: reason,
        groupId: ref.read(sessionProvider).value?.currentGroup?.id,
        recordId: widget.recordId,
        commentId: widget.commentId,
        commentBody: widget.commentBody,
        detail: _detail.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고했어요. 운영자가 확인하고 조치할게요.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _sending = false);
        showErrorSnack(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, AppSpacing.page + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.target.label} 신고', style: AppText.headline),
          const SizedBox(height: 4),
          const Text('신고한 사람은 상대에게 알려지지 않아요.', style: AppText.label),
          const SizedBox(height: 12),
          RadioGroup<ReportReason>(
            groupValue: _reason,
            onChanged: (value) => setState(() => _reason = value),
            child: Column(
              children: [
                for (final reason in ReportReason.values)
                  RadioListTile<ReportReason>(
                    value: reason,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(reason.label, style: AppText.body),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _detail,
            maxLength: 300,
            maxLines: 2,
            decoration: const InputDecoration(hintText: '자세한 내용 (선택)'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _reason == null || _sending ? null : _send,
            child: Text(_sending ? '보내는 중…' : '신고하기'),
          ),
        ],
      ),
    );
  }
}

/// 차단 확인. 차단하면 그 사람의 사진과 댓글이 나에게 보이지 않고, 그 사람은 나를 찌를 수 없다.
Future<bool> confirmBlock(BuildContext context, WidgetRef ref, {required String userId, required String nickname}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$nickname님을 차단할까요?'),
      content: const Text(
        '차단하면 이 멤버의 사진과 댓글이 나에게 보이지 않고, 이 멤버는 나를 찌를 수 없어요. '
        '상대에게는 알리지 않아요. 멤버 방에서 언제든 풀 수 있어요.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('차단하기'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await ref.read(safetyRepositoryProvider).block(userId);
    ref.invalidate(blockedUsersProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$nickname님을 차단했어요.')));
    }
    return true;
  } catch (error) {
    if (context.mounted) showErrorSnack(context, error);
    return false;
  }
}

Future<void> unblock(BuildContext context, WidgetRef ref, {required String userId, required String nickname}) async {
  try {
    await ref.read(safetyRepositoryProvider).unblock(userId);
    ref.invalidate(blockedUsersProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$nickname님 차단을 풀었어요.')));
    }
  } catch (error) {
    if (context.mounted) showErrorSnack(context, error);
  }
}
