import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/app_supabase.dart';

/// 신고 사유. 값은 reports.reason 과 같다.
enum ReportReason { sexual, harassment, spam, violence, other }

extension ReportReasonX on ReportReason {
  String get dbValue => name;

  String get label => switch (this) {
    ReportReason.sexual => '선정적이거나 불쾌한 사진',
    ReportReason.harassment => '괴롭힘이나 욕설',
    ReportReason.spam => '스팸이나 광고',
    ReportReason.violence => '폭력적이거나 위험한 내용',
    ReportReason.other => '그 밖의 문제',
  };
}

/// 무엇을 신고하는지. 값은 reports.target_kind 와 같다.
enum ReportTarget { user, bodyPhoto, mealPhoto, comment }

extension ReportTargetX on ReportTarget {
  String get dbValue => switch (this) {
    ReportTarget.user => 'user',
    ReportTarget.bodyPhoto => 'body_photo',
    ReportTarget.mealPhoto => 'meal_photo',
    ReportTarget.comment => 'comment',
  };

  String get label => switch (this) {
    ReportTarget.user => '멤버',
    ReportTarget.bodyPhoto => '눈바디 사진',
    ReportTarget.mealPhoto => '식단 사진',
    ReportTarget.comment => '댓글',
  };
}

/// 신고와 차단. 신고는 운영자가 Supabase 대시보드(reports)에서 보고 처리한다.
class SafetyRepository {
  Future<void> report({
    required String targetUserId,
    required ReportTarget target,
    required ReportReason reason,
    String? groupId,
    String? recordId,
    String? commentId,
    String? commentBody,
    String? detail,
  }) async {
    final text = detail?.trim() ?? '';
    await requireSupabase().from('reports').insert({
      'target_user_id': targetUserId,
      'target_kind': target.dbValue,
      'reason': reason.dbValue,
      'group_id': groupId,
      'record_id': recordId,
      'comment_id': commentId,
      'comment_body': commentBody,
      'detail': text.isEmpty ? null : text,
    });
  }

  Future<Set<String>> fetchBlockedIds() async {
    final client = requireSupabase();
    if (client.auth.currentUser == null) return {};
    final rows = await client.from('blocks').select('blocked_id');
    return {for (final row in rows as List) (row as Map)['blocked_id'] as String};
  }

  /// 차단. 차단 행은 고치지 않으므로(update 권한 없음) upsert 대신 넣고, 이미 차단했으면 넘어간다.
  Future<void> block(String userId) async {
    try {
      await requireSupabase().from('blocks').insert({'blocked_id': userId});
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }
  }

  Future<void> unblock(String userId) async {
    final client = requireSupabase();
    final me = client.auth.currentUser?.id;
    if (me == null) return;
    await client.from('blocks').delete().eq('blocker_id', me).eq('blocked_id', userId);
  }
}
