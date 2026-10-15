import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/local_date.dart';
import '../../core/utils/points.dart';
import '../../core/utils/weight.dart';
import '../models/daily_record.dart';
import '../models/workout.dart';
import '../supabase/app_supabase.dart';

class PokeNotice {
  const PokeNotice({
    required this.id,
    required this.senderName,
    required this.createdAt,
  });

  final String id;
  final String senderName;
  final DateTime createdAt;
}

class RecordDraft {
  String weight;
  String memo;
  int workoutMinutes;
  Set<WorkoutKind> kinds;
  String? bodyPhotoPath;
  String? mealPhotoPath;
  String? existingBodyPath;
  String? existingMealPath;

  RecordDraft({
    this.weight = '',
    this.memo = '',
    this.workoutMinutes = 30,
    Set<WorkoutKind>? kinds,
    this.bodyPhotoPath,
    this.mealPhotoPath,
    this.existingBodyPath,
    this.existingMealPath,
  }) : kinds = kinds ?? {};

  factory RecordDraft.fromRecord(DailyRecord? record) {
    return RecordDraft(
      weight: record?.weight?.toString() ?? '',
      memo: record?.memo ?? '',
      workoutMinutes: record?.workoutMinutes ?? 30,
      kinds: {...?record?.workoutKinds},
      existingBodyPath: record?.bodyPhotoPath,
      existingMealPath: record?.mealPhotoPath,
    );
  }
}

class RecordRepository {
  Future<DailyRecord?> fetchForUserOn(String userId, String date) async {
    final client = requireSupabase();
    final row = await client
        .from('daily_records')
        .select()
        .eq('user_id', userId)
        .eq('record_date', date)
        .maybeSingle();
    if (row == null) return null;
    return hydrate(DailyRecord.fromMap(row));
  }

  Future<DailyRecord> hydrate(DailyRecord record) async {
    return record.copyWith(
      bodyPhotoUrl: await signUrl('body-photos', record.bodyPhotoPath),
      mealPhotoUrl: await signUrl('meal-photos', record.mealPhotoPath),
    );
  }

  Future<List<DailyRecord>> _hydrateAll(List<DailyRecord> records) async {
    return [for (final record in records) await hydrate(record)];
  }

  Future<String?> signUrl(String bucket, String? path) async {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    final client = requireSupabase();
    return client.storage.from(bucket).createSignedUrl(path, 60 * 60 * 24);
  }

  Future<Map<String, DailyRecord>> fetchTodayForUsers(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final client = requireSupabase();
    final today = localDateString();
    final rows = await client
        .from('daily_records')
        .select()
        .eq('record_date', today)
        .inFilter('user_id', userIds);
    final mapped = {
      for (final row in rows as List)
        row['user_id'] as String: DailyRecord.fromMap(Map<String, dynamic>.from(row as Map)),
    };
    final hydrated = <String, DailyRecord>{};
    for (final entry in mapped.entries) {
      hydrated[entry.key] = await hydrate(entry.value);
    }
    return hydrated;
  }

  Future<List<DailyRecord>> fetchForUser(String userId) async {
    final client = requireSupabase();
    final rows = await client
        .from('daily_records')
        .select()
        .eq('user_id', userId)
        .order('record_date', ascending: false);
    return _hydrateAll([
      for (final row in rows as List)
        DailyRecord.fromMap(Map<String, dynamic>.from(row as Map)),
    ]);
  }

  Future<List<DailyRecord>> fetchForUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final client = requireSupabase();
    final rows = await client
        .from('daily_records')
        .select()
        .inFilter('user_id', userIds)
        .order('record_date');
    return _hydrateAll([
      for (final row in rows as List)
        DailyRecord.fromMap(Map<String, dynamic>.from(row as Map)),
    ]);
  }

  Future<Map<String, double>> fetchPreviousWeights({
    required List<String> userIds,
    required String beforeDate,
  }) async {
    if (userIds.isEmpty) return {};
    final client = requireSupabase();
    final rows = await client
        .from('daily_records')
        .select('user_id, weight, record_date')
        .inFilter('user_id', userIds)
        .lt('record_date', beforeDate)
        .not('weight', 'is', null)
        .order('record_date');
    final latest = <String, double>{};
    for (final row in rows as List) {
      latest[row['user_id'] as String] = (row['weight'] as num).toDouble();
    }
    return latest;
  }

  Future<Set<String>> fetchPokedUserIds({required String groupId}) async {
    final client = requireSupabase();
    final start = '${localDateString()}T00:00:00';
    final rows = await client
        .from('pokes')
        .select('receiver_id')
        .eq('group_id', groupId)
        .gte('created_at', start);
    return {
      for (final row in rows as List) row['receiver_id'] as String,
    };
  }

  Future<List<PokeNotice>> fetchPokesFor({
    required String groupId,
    required String receiverId,
  }) async {
    final client = requireSupabase();
    final rows = await client
        .from('pokes')
        .select('id, created_at, sender:profiles!sender_id(nickname)')
        .eq('group_id', groupId)
        .eq('receiver_id', receiverId)
        .order('created_at', ascending: false)
        .limit(20);
    return [
      for (final row in rows as List)
        PokeNotice(
          id: row['id'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
          senderName: (row['sender'] as Map?)?['nickname'] as String? ?? '멤버',
        ),
    ];
  }

  Future<DailyRecord?> previousWeightBefore({
    required String userId,
    required String date,
  }) async {
    final client = requireSupabase();
    final row = await client
        .from('daily_records')
        .select()
        .eq('user_id', userId)
        .lt('record_date', date)
        .not('weight', 'is', null)
        .order('record_date', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return DailyRecord.fromMap(row);
  }

  Future<void> saveToday(RecordDraft draft) async {
    final client = requireSupabase();
    final user = client.auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    final today = localDateString();
    final existing = await fetchForUserOn(user.id, today);

    final weight = roundWeight(draft.weight);
    final memo = draft.memo.trim();
    var bodyPath = draft.existingBodyPath;
    var mealPath = draft.existingMealPath;

    if (draft.bodyPhotoPath != null) {
      bodyPath = await _uploadPhoto(
        userId: user.id,
        date: today,
        path: draft.bodyPhotoPath!,
        bucket: 'body-photos',
      );
    }
    if (draft.mealPhotoPath != null) {
      mealPath = await _uploadPhoto(
        userId: user.id,
        date: today,
        path: draft.mealPhotoPath!,
        bucket: 'meal-photos',
      );
    }

    final restOnly = isRestOnly(draft.kinds);
    final input = RecordScoreInput(
      hasWeight: weight != null,
      hasBodyPhoto: bodyPath != null && bodyPath.isNotEmpty,
      hasMealPhoto: mealPath != null && mealPath.isNotEmpty,
      hasWorkout: draft.kinds.isNotEmpty,
      isRestDay: restOnly,
      workoutMinutes: draft.workoutMinutes,
      hasMemo: memo.isNotEmpty,
    );
    if (!input.isAttendance) {
      throw StateError('체중, 눈바디, 식단, 운동, 메모 중 하나는 필요합니다.');
    }

    final points = computePoints(input);
    final payload = {
      'user_id': user.id,
      'record_date': today,
      'weight': weight,
      'body_photo_url': bodyPath,
      'meal_photo_url': mealPath,
      'workout_minutes': draft.kinds.isEmpty || restOnly ? null : draft.workoutMinutes,
      'workout_kinds': draft.kinds.isEmpty
          ? null
          : [for (final kind in WorkoutKind.values) if (draft.kinds.contains(kind)) kind.dbValue],
      'memo': memo.isEmpty ? null : memo,
      'points_earned': points,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await client.from('daily_records').upsert(payload, onConflict: 'user_id,record_date');

    final previousPoints = existing?.pointsEarned ?? 0;
    await _applyWalletAndStreak(
      userId: user.id,
      pointDelta: points - previousPoints,
      today: today,
    );
  }

  Future<void> poke({required String groupId, required String receiverId}) async {
    final client = requireSupabase();
    final senderId = client.auth.currentUser?.id;
    if (senderId == null) return;
    await client.from('pokes').insert({
      'group_id': groupId,
      'sender_id': senderId,
      'receiver_id': receiverId,
    });
  }

  Future<void> addComment({
    required String groupId,
    required String recordId,
    required String photoKind,
    required String body,
  }) async {
    final client = requireSupabase();
    final authorId = client.auth.currentUser?.id;
    if (authorId == null) return;
    await client.from('comments').insert({
      'group_id': groupId,
      'record_id': recordId,
      'author_id': authorId,
      'photo_kind': photoKind,
      'body': body.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchComments({
    required String groupId,
    required String recordId,
  }) async {
    final client = requireSupabase();
    final rows = await client
        .from('comments')
        .select('*, profiles(nickname)')
        .eq('group_id', groupId)
        .eq('record_id', recordId)
        .order('created_at');
    return [for (final row in rows as List) Map<String, dynamic>.from(row as Map)];
  }

  Future<String> _uploadPhoto({
    required String userId,
    required String date,
    required String path,
    required String bucket,
  }) async {
    final client = requireSupabase();
    final compressed = await FlutterImageCompress.compressWithFile(
      path,
      minWidth: AppConstants.photoMaxDimension,
      minHeight: AppConstants.photoMaxDimension,
      quality: AppConstants.photoQuality,
      format: CompressFormat.jpeg,
    );
    if (compressed == null) {
      throw StateError('사진을 압축하지 못했습니다.');
    }
    final objectPath = '$userId/$date.jpg';
    await client.storage.from(bucket).uploadBinary(
      objectPath,
      compressed,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );
    return objectPath;
  }

  Future<void> _applyWalletAndStreak({
    required String userId,
    required int pointDelta,
    required String today,
  }) async {
    final client = requireSupabase();
    final profile = await client
        .from('profiles')
        .select('wallet_points, streak_days, last_attend_date')
        .eq('id', userId)
        .single();

    final last = profile['last_attend_date'] as String?;
    final yesterday = localDateString(DateTime.now().subtract(const Duration(days: 1)));
    var streak = (profile['streak_days'] as int?) ?? 0;
    if (last == today) {
      // already counted today
    } else if (last == yesterday) {
      streak += 1;
    } else {
      streak = 1;
    }

    await client.from('profiles').update({
      'wallet_points': ((profile['wallet_points'] as int?) ?? 0) + pointDelta,
      'streak_days': streak,
      'last_attend_date': today,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }
}

Future<String?> pickImagePath(ImageSource source) async {
  final file = await ImagePicker().pickImage(source: source, imageQuality: 95);
  return file?.path;
}
