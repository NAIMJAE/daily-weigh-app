import '../models/group.dart';
import '../models/profile.dart';
import '../supabase/app_supabase.dart';

class GroupMate {
  const GroupMate({required this.member, required this.profile});

  final GroupMember member;
  final Profile profile;
}

class GroupRepository {
  Future<List<GroupMate>> fetchMembers(String groupId) async {
    final client = requireSupabase();
    final rows = await client
        .from('group_members')
        .select('*, profiles(*)')
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);

    final members = <GroupMate>[];
    for (final row in rows as List) {
      final profileMap = row['profiles'] as Map<String, dynamic>?;
      if (profileMap == null) continue;
      members.add(
        GroupMate(
          member: GroupMember.fromMap(Map<String, dynamic>.from(row as Map)),
          profile: Profile.fromMap(profileMap),
        ),
      );
    }
    return members;
  }

  Future<void> renameGroup(String groupId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw StateError('그룹 이름을 입력하세요.');
    final client = requireSupabase();
    await client.from('groups').update({'name': trimmed}).eq('id', groupId);
  }

  Future<void> leaveGroup({required Group group, required String userId}) async {
    if (group.isPersonal) {
      throw StateError('개인 그룹은 나갈 수 없습니다.');
    }
    // 방장 이관과 마지막 멤버의 그룹 삭제는 서버 함수가 한 번에 처리한다.
    final client = requireSupabase();
    await client.rpc('leave_group', params: {'p_group_id': group.id});
  }

  /// 방장이 초대 코드를 새로 바꾼다. 예전 코드는 바로 못 쓴다.
  Future<String> rotateInviteCode(String groupId) async {
    final client = requireSupabase();
    return await client.rpc('rotate_invite_code', params: {'p_group_id': groupId}) as String;
  }

  Future<void> kickMember({required String groupId, required String ownerId, required String targetUserId}) async {
    if (ownerId == targetUserId) {
      throw StateError('방장은 자신을 내보낼 수 없습니다.');
    }
    final client = requireSupabase();
    await client.rpc('kick_member', params: {'p_group_id': groupId, 'p_user_id': targetUserId});
  }
}
