import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../data/models/group.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/supabase/app_supabase.dart';

class SessionState {
  const SessionState({
    this.userId,
    this.profile,
    this.groups = const [],
    this.currentGroupId,
  });

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

  SessionState copyWith({
    String? userId,
    Profile? profile,
    List<Group>? groups,
    String? currentGroupId,
  }) {
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
      var attached = false;
      _authSub = client.auth.onAuthStateChange.listen((data) {
        if (!attached || data.event == AuthChangeEvent.initialSession) return;
        scheduleMicrotask(() {
          if (ref.mounted) ref.invalidateSelf();
        });
      });
      attached = true;
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
    return SessionState(
      userId: userId,
      profile: profile,
      groups: groups,
      currentGroupId: preferredId,
    );
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
  }

  Future<void> login(String username, String password) async {
    await ref.read(authRepositoryProvider).login(username: username, password: password);
  }

  Future<void> register({
    required String username,
    required String nickname,
    required String password,
  }) async {
    await ref.read(authRepositoryProvider).register(
      username: username,
      nickname: nickname,
      password: password,
    );
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(SessionState());
  }

  Future<void> completeOnboarding({
    required double height,
    required double startWeight,
    required double targetWeight,
  }) async {
    await ref.read(authRepositoryProvider).completeOnboarding(
      height: height,
      startWeight: startWeight,
      targetWeight: targetWeight,
    );
    await reload();
  }

  Future<void> updateNickname(String nickname) async {
    await ref.read(authRepositoryProvider).updateNickname(nickname);
    await reload();
  }

  Future<void> updateBody({
    required double height,
    required double startWeight,
    required double targetWeight,
  }) async {
    await ref.read(authRepositoryProvider).updateBody(
      height: height,
      startWeight: startWeight,
      targetWeight: targetWeight,
    );
    await reload();
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
