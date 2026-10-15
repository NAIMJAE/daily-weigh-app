import '../models/group.dart';
import '../models/profile.dart';
import '../supabase/app_supabase.dart';

class GroupMate {
  const GroupMate({
    required this.member,
    required this.profile,
  });

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
        .order('joined_at');

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
    final client = requireSupabase();
    await client.from('groups').update({'name': name.trim()}).eq('id', groupId);
  }

  Future<void> leaveGroup({
    required Group group,
    required String userId,
  }) async {
    if (group.isPersonal) {
      throw StateError('개인 그룹은 나갈 수 없습니다.');
    }
    final client = requireSupabase();
    final members = await fetchMembers(group.id);
    final remaining = members.where((m) => m.profile.id != userId).toList();

    await client
        .from('group_members')
        .delete()
        .eq('group_id', group.id)
        .eq('user_id', userId);

    if (remaining.isEmpty) {
      await client.from('groups').delete().eq('id', group.id);
      return;
    }

    final wasOwner = members.any(
      (m) => m.profile.id == userId && m.member.isOwner,
    );
    if (wasOwner) {
      remaining.sort((a, b) => a.member.joinedAt.compareTo(b.member.joinedAt));
      await client
          .from('group_members')
          .update({'role': 'owner'})
          .eq('id', remaining.first.member.id);
    }
  }

  Future<void> kickMember({
    required String groupId,
    required String ownerId,
    required String targetUserId,
  }) async {
    if (ownerId == targetUserId) {
      throw StateError('방장은 자신을 내보낼 수 없습니다.');
    }
    final client = requireSupabase();
    await client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', targetUserId);
  }
}
