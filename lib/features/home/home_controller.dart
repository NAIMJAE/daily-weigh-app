import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/daily_record.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/repositories/record_repository.dart';
import '../session/session_controller.dart';

class HomeSnapshot {
  const HomeSnapshot({
    required this.members,
    required this.todayRecords,
    required this.history,
    required this.pokedUserIds,
  });

  final List<GroupMate> members;
  final Map<String, DailyRecord> todayRecords;
  final List<DailyRecord> history;
  final Set<String> pokedUserIds;
}

final groupRepositoryProvider = Provider<GroupRepository>((ref) => GroupRepository());
final recordRepositoryProvider = Provider<RecordRepository>((ref) => RecordRepository());

class RecordRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final recordRevisionProvider = NotifierProvider<RecordRevision, int>(RecordRevision.new);

final homeSnapshotProvider = FutureProvider<HomeSnapshot>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  final group = session.currentGroup;
  if (group == null) {
    return const HomeSnapshot(members: [], todayRecords: {}, history: [], pokedUserIds: {});
  }
  final members = await ref.read(groupRepositoryProvider).fetchMembers(group.id);
  final userIds = members.map((member) => member.profile.id).toList();
  final records = await ref.read(recordRepositoryProvider).fetchTodayForUsers(userIds);
  final history = await ref.read(recordRepositoryProvider).fetchForUsers(userIds);
  final poked = await ref.read(recordRepositoryProvider).fetchPokedUserIds(groupId: group.id);
  return HomeSnapshot(members: members, todayRecords: records, history: history, pokedUserIds: poked);
});
