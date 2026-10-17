class Group {
  const Group({required this.id, required this.name, required this.isPersonal, this.inviteCode, this.createdBy});

  final String id;
  final String name;
  final bool isPersonal;
  final String? inviteCode;
  final String? createdBy;

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'] as String,
      name: map['name'] as String,
      isPersonal: map['is_personal'] as bool? ?? false,
      inviteCode: map['invite_code'] as String?,
      createdBy: map['created_by'] as String?,
    );
  }
}

class GroupMember {
  const GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.profile,
  });

  final String id;
  final String groupId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final dynamic profile;

  bool get isOwner => role == 'owner';

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      userId: map['user_id'] as String,
      role: map['role'] as String? ?? 'member',
      joinedAt: DateTime.parse(map['joined_at'] as String),
      profile: map['profiles'],
    );
  }
}
