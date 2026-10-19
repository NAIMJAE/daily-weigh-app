import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../data/models/group.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/supabase/app_supabase.dart';

class SessionState {
  const SessionState({this.userId, this.profile, this.groups = const [], this.currentGroupId});

  final String? userId;
  final Profile? profile;
  final List<Group> groups;
  final String? currentGroupId;

  bool get isLoggedIn => userId != null;
  bool get needsOnboarding {
    if (!isLoggedIn || profile == null) return isLoggedIn;
    final hasPersonal = groups.any((group) => group.isPersonal);
    return !profile!.hasBodyInfo || !hasPersonal;
  }

  Group? get currentGroup {
    if (groups.isEmpty) return null;
    for (final group in groups) {
      if (group.id == currentGroupId) return group;
    }
    return groups.first;
  }

  SessionState copyWith({String? userId, Profile? profile, List<Group>? groups, String? currentGroupId}) {
    return SessionState(
      userId: userId ?? this.userId,
      profile: profile ?? this.profile,
      groups: groups ?? this.groups,
      currentGroupId: currentGroupId ?? this.currentGroupId,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class SessionController extends AsyncNotifier<SessionState> {
  StreamSubscription<AuthState>? _authSub;

  @override
  Future<SessionState> build() async {
    _authSub?.cancel();
    final client = supabaseOrNull;
    if (client != null) {
      // 이 스트림은 새 구독자에게 마지막 이벤트를 다시 보낸다. 이벤트 종류로 거르면
      // 다시 받은 signedIn 때문에 build가 끝없이 반복되므로, 로그인한 사용자가 바뀔 때만 다시 읽는다.
      final loadedUserId = client.auth.currentUser?.id;
      _authSub = client.auth.onAuthStateChange.listen((data) {
        if (data.session?.user.id == loadedUserId) return;
        scheduleMicrotask(() {
          if (ref.mounted) ref.invalidateSelf();
        });
      });
      ref.onDispose(() => _authSub?.cancel());
    }
    return _load();
  }

  Future<SessionState> _load({String? keepGroupId}) async {
    if (!AppConfig.isConfigured) return const SessionState();
    final repo = ref.read(authRepositoryProvider);
    final userId = supabaseOrNull?.auth.currentUser?.id;
    if (userId == null) return const SessionState();
    final profile = await repo.fetchMyProfile();
    final groups = await repo.fetchMyGroups();
    // 앱을 다시 켜면 마지막으로 고른 그룹을 연다. 나갔거나 강퇴된 그룹이면 아래 기본값을 쓴다.
    keepGroupId ??= await _savedGroupId(userId);
    String? preferredId;
    for (final group in groups) {
      if (group.isPersonal) {
        preferredId = group.id;
        break;
      }
    }
    preferredId ??= groups.isEmpty ? null : groups.first.id;
    if (keepGroupId != null && groups.any((group) => group.id == keepGroupId)) {
      preferredId = keepGroupId;
    }
    return SessionState(userId: userId, profile: profile, groups: groups, currentGroupId: preferredId);
  }

  Future<void> reload() async {
    final keep = state.value?.currentGroupId;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(keepGroupId: keep));
  }

  void selectGroup(String groupId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(currentGroupId: groupId));
    final userId = current.userId;
    if (userId != null) _saveGroupId(userId, groupId);
  }

  // 마지막 그룹은 계정마다 따로 기억한다. 저장소를 못 쓰면 기본 그룹으로 연다.
  static String _groupKey(String userId) => 'current_group.$userId';

  Future<String?> _savedGroupId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_groupKey(userId));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveGroupId(String userId, String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_groupKey(userId), groupId);
    } catch (_) {}
  }

  Future<void> login(String username, String password) async {
    await ref.read(authRepositoryProvider).login(username: username, password: password);
  }

  Future<void> register({required String username, required String nickname, required String password}) async {
    await ref.read(authRepositoryProvider).register(username: username, nickname: nickname, password: password);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(SessionState());
  }

  /// 회원 탈퇴. 이 기기에 남은 이 계정의 설정(마지막 그룹, 진행 중인 운동)도 지운다.
  Future<void> deleteAccount() async {
    final userId = state.value?.userId;
    await ref.read(authRepositoryProvider).deleteAccount();
    if (userId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_groupKey(userId));
        await prefs.remove('active_workout:$userId');
      } catch (_) {}
    }
    state = const AsyncData(SessionState());
  }

  Future<void> completeOnboarding({
    required double height,
    required double startWeight,
    required double targetWeight,
  }) async {
    await ref
        .read(authRepositoryProvider)
        .completeOnboarding(height: height, startWeight: startWeight, targetWeight: targetWeight);
    await reload();
  }

  Future<void> updateNickname(String nickname) async {
    await ref.read(authRepositoryProvider).updateNickname(nickname);
    await reload();
  }

  Future<void> updateBody({required double height, required double startWeight, required double targetWeight}) async {
    await ref
        .read(authRepositoryProvider)
        .updateBody(height: height, startWeight: startWeight, targetWeight: targetWeight);
    await reload();
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, SessionState>(SessionController.new);

/// 화면이 데이터를 불러올 때 쓰는 세션. 세션을 (다시) 읽는 중이면 끝날 때까지 기다린다.
/// `.value`는 다시 읽는 동안 비어 있어서, 그때 연 화면이 그룹·사용자 없음으로 그려진다.
Future<SessionState> currentSession(WidgetRef ref) async {
  try {
    return await ref.read(sessionProvider.future);
  } catch (_) {
    return const SessionState();
  }
}
