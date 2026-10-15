import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/local_date.dart';
import '../../core/utils/random_id.dart';
import '../../core/utils/streak.dart';
import '../../core/utils/virtual_email.dart';
import '../models/group.dart';
import '../models/profile.dart';
import '../supabase/app_supabase.dart';
import '../../core/utils/invite_code.dart';

class AuthRepository {
  Future<void> login({required String username, required String password}) async {
    final client = requireSupabase();
    final response = await client.auth.signInWithPassword(
      email: virtualEmailFor(username),
      password: password,
    );
    if (response.session == null) {
      throw AuthException('아이디 또는 비밀번호가 올바르지 않습니다.');
    }
  }

  Future<void> register({
    required String username,
    required String nickname,
    required String password,
  }) async {
    final client = requireSupabase();
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.length < AppConstants.minUsernameLength) {
      throw AuthException('아이디는 최소 3글자입니다.');
    }
    if (nickname.trim().length < AppConstants.minNicknameLength) {
      throw AuthException('닉네임은 최소 2글자입니다.');
    }
    if (password.length < AppConstants.minPasswordLength) {
      throw AuthException('비밀번호는 최소 6자리입니다.');
    }

    final response = await client.auth.signUp(
      email: virtualEmailFor(cleanUsername),
      password: password,
      data: {
        'username': cleanUsername,
        'nickname': nickname.trim(),
      },
    );
    if (response.user == null) {
      throw AuthException('회원가입에 실패했습니다.');
    }

    await client.from('profiles').upsert({
      'id': response.user!.id,
      'username': cleanUsername,
      'nickname': nickname.trim(),
    });
  }

  Future<void> logout() async {
    final client = supabaseOrNull;
    if (client == null) return;
    await client.auth.signOut();
  }

  Future<Profile?> fetchMyProfile() async {
    final client = supabaseOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return null;
    final row = await client.from('profiles').select().eq('id', userId).maybeSingle();
    if (row == null) return null;
    await reconcileStreak(userId);
    final fresh = await client.from('profiles').select().eq('id', userId).maybeSingle();
    if (fresh == null) return null;
    return Profile.fromMap(fresh);
  }

  Future<void> reconcileStreak(String userId) async {
    final client = requireSupabase();
    final row = await client
        .from('profiles')
        .select('streak_days, last_attend_date')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return;
    final today = localDateString();
    final yesterday = localDateString(DateTime.now().subtract(const Duration(days: 1)));
    final next = reconciledStreak(
      streakDays: (row['streak_days'] as int?) ?? 0,
      lastAttendDate: row['last_attend_date'] as String?,
      today: today,
      yesterday: yesterday,
    );
    if (next == ((row['streak_days'] as int?) ?? 0)) return;
    await client.from('profiles').update({
      'streak_days': next,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<void> updateNickname(String nickname) async {
    final client = requireSupabase();
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw AuthException('로그인이 필요합니다.');
    final trimmed = nickname.trim();
    if (trimmed.length < AppConstants.minNicknameLength) {
      throw AuthException('닉네임은 최소 2글자입니다.');
    }
    await client.from('profiles').update({
      'nickname': trimmed,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<List<Group>> fetchMyGroups() async {
    final client = supabaseOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return [];

    final memberships = await client
        .from('group_members')
        .select('role, joined_at, groups(*)')
        .eq('user_id', userId);

    final groups = <Group>[];
    for (final row in memberships as List) {
      final groupMap = row['groups'] as Map<String, dynamic>?;
      if (groupMap == null) continue;
      groups.add(Group.fromMap(groupMap));
    }
    groups.sort((a, b) {
      if (a.isPersonal != b.isPersonal) return a.isPersonal ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return groups;
  }

  Future<void> completeOnboarding({
    required double height,
    required double startWeight,
    required double targetWeight,
  }) async {
    final client = requireSupabase();
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw AuthException('로그인이 필요합니다.');

    await client.from('profiles').update({
      'height': height,
      'start_weight': startWeight,
      'target_weight': targetWeight,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);

    await ensurePersonalGroup();
  }

  Future<void> updateBody({
    required double height,
    required double startWeight,
    required double targetWeight,
  }) async {
    final client = requireSupabase();
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw AuthException('로그인이 필요합니다.');
    await client.from('profiles').update({
      'height': height,
      'start_weight': startWeight,
      'target_weight': targetWeight,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<void> ensurePersonalGroup() async {
    final client = requireSupabase();
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    final groups = await fetchMyGroups();
    if (groups.any((group) => group.isPersonal)) return;

    final id = randomUuid();
    await client.from('groups').insert({
      'id': id,
      'name': AppConstants.personalGroupName,
      'is_personal': true,
      'created_by': userId,
    });
    await client.from('group_members').insert({
      'group_id': id,
      'user_id': userId,
      'role': 'owner',
    });
  }

  Future<Group> createFriendGroup(String name) async {
    final client = requireSupabase();
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw AuthException('로그인이 필요합니다.');
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw AuthException('그룹 이름을 입력하세요.');

    final id = randomUuid();
    final code = generateInviteCode();
    await client.from('groups').insert({
      'id': id,
      'name': trimmed,
      'is_personal': false,
      'invite_code': code,
      'created_by': userId,
    });
    await client.from('group_members').insert({
      'group_id': id,
      'user_id': userId,
      'role': 'owner',
    });
    final row = await client.from('groups').select().eq('id', id).single();
    return Group.fromMap(Map<String, dynamic>.from(row));
  }

  Future<String> joinFriendGroup(String code) async {
    final client = requireSupabase();
    try {
      final result = await client.rpc('join_friend_group', params: {'code': code});
      return result as String;
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202') {
        throw AuthException('초대 코드로 들어가려면 앱 DB에 그룹 함수를 먼저 넣어야 합니다.');
      }
      rethrow;
    }
  }
}
