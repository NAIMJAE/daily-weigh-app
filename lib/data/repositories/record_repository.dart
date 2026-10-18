import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/local_date.dart';
import '../../core/utils/points.dart';
import '../../core/utils/storage_path.dart';
import '../../core/utils/weight.dart';
import '../models/daily_record.dart';
import '../models/meal_entry.dart';
import '../models/workout.dart';
import '../supabase/app_supabase.dart';

class PokeNotice {
  const PokeNotice({required this.id, required this.senderName, required this.createdAt});

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
  // 미리보기용: 이미 올린 사진의 서명 URL과 캐시 키.
  String? existingBodyUrl;
  String? existingMealUrl;
  String? existingBodyCacheKey;
  String? existingMealCacheKey;
  // 이미 올린 사진을 오늘 기록에서 뺀다 (파일은 스토리지에 둔다).
  bool removeBody;
  bool removeMeal;

  RecordDraft({
    this.weight = '',
    this.memo = '',
    this.workoutMinutes = 30,
    Set<WorkoutKind>? kinds,
    this.bodyPhotoPath,
    this.mealPhotoPath,
    this.existingBodyPath,
    this.existingMealPath,
    this.existingBodyUrl,
    this.existingMealUrl,
    this.existingBodyCacheKey,
    this.existingMealCacheKey,
    this.removeBody = false,
    this.removeMeal = false,
  }) : kinds = kinds ?? {};

  factory RecordDraft.fromRecord(DailyRecord? record) {
    return RecordDraft(
      weight: record?.weight?.toString() ?? '',
      memo: record?.memo ?? '',
      workoutMinutes: record?.workoutMinutes ?? 30,
      kinds: {...?record?.workoutKinds},
      existingBodyPath: record?.bodyPhotoPath,
      existingMealPath: record?.mealPhotoPath,
      existingBodyUrl: record?.bodyPhotoUrl,
      existingMealUrl: record?.mealPhotoUrl,
      existingBodyCacheKey: record?.bodyPhotoCacheKey,
      existingMealCacheKey: record?.mealPhotoCacheKey,
    );
  }

  bool get hasBody => bodyPhotoPath != null || (!removeBody && (existingBodyPath?.isNotEmpty ?? false));
  bool get hasMeal => mealPhotoPath != null || (!removeMeal && (existingMealPath?.isNotEmpty ?? false));
}

class RecordRepository {
  Future<DailyRecord?> fetchForUserOn(String userId, String date) async {
    final client = requireSupabase();
    final row = await client.from('daily_records').select().eq('user_id', userId).eq('record_date', date).maybeSingle();
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
    final body = await _signAll('body-photos', [for (final record in records) record.bodyPhotoPath]);
    final meal = await _signAll('meal-photos', [for (final record in records) record.mealPhotoPath]);
    return [
      for (final record in records)
        record.copyWith(bodyPhotoUrl: body[record.bodyPhotoPath], mealPhotoUrl: meal[record.mealPhotoPath]),
    ];
  }

  /// 서명 URL은 1시간만 쓴다. 그룹에서 나가거나 사진을 뺀 뒤에도 예전 주소로 오래 보이지 않게 한다.
  /// 이미지 캐시는 저장 경로로 찾으므로, 이미 받은 사진은 주소가 만료돼도 그대로 보인다.
  static const _signedUrlSeconds = 60 * 60;

  /// 우리 저장소의 경로만 서명한다. 바깥 주소(http)는 그룹원 기기가 낯선 서버에 접속하게 되므로 보여 주지 않는다.
  Future<String?> signUrl(String bucket, String? path) async {
    if (path == null || path.isEmpty || path.startsWith('http')) return null;
    final client = requireSupabase();
    return client.storage.from(bucket).createSignedUrl(path, _signedUrlSeconds);
  }

  /// 여러 사진의 서명 URL을 요청 한 번으로 받는다. 키는 저장 경로.
  Future<Map<String, String>> _signAll(String bucket, List<String?> paths) async {
    final result = <String, String>{};
    final toSign = <String>{};
    for (final path in paths) {
      if (path == null || path.isEmpty || path.startsWith('http')) continue;
      toSign.add(path);
    }
    if (toSign.isEmpty) return result;
    final client = requireSupabase();
    final signed = await client.storage.from(bucket).createSignedUrlsResult(toSign.toList(), _signedUrlSeconds);
    // 파일이 없어 서명하지 못한 경로는 사진 없음으로 둔다.
    for (final item in signed) {
      if (item is SignedUrlSuccess) result[item.path] = item.signedUrl;
    }
    return result;
  }

  /// 홈 목록용. 사진 URL은 만들지 않는다 (사진 유무는 경로로 판단).
  Future<Map<String, DailyRecord>> fetchTodayForUsers(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final client = requireSupabase();
    final today = localDateString();
    final rows = await client.from('daily_records').select().eq('record_date', today).inFilter('user_id', userIds);
    return {
      for (final row in rows as List)
        row['user_id'] as String: DailyRecord.fromMap(Map<String, dynamic>.from(row as Map)),
    };
  }

  Future<List<DailyRecord>> fetchForUser(String userId) async {
    final client = requireSupabase();
    final rows = await client
        .from('daily_records')
        .select()
        .eq('user_id', userId)
        .order('record_date', ascending: false);
    return _hydrateAll([for (final row in rows as List) DailyRecord.fromMap(Map<String, dynamic>.from(row as Map))]);
  }

  Future<List<MealEntry>> fetchMealEntries(String userId) async {
    final client = requireSupabase();
    final rows = await client
        .from('meal_entries')
        .select()
        .eq('user_id', userId)
        .order('record_date', ascending: false);
    final entries = [
      for (final row in rows as List) ?MealEntry.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
    final signed = await _signAll('meal-photos', [for (final entry in entries) entry.photoPath]);
    return [for (final entry in entries) entry.copyWith(photoUrl: signed[entry.photoPath])];
  }

  /// 그룹 통계용. 기간 안의 끼니를 여러 사람 것까지 읽는다. 사진 URL은 만들지 않는다.
  Future<List<MealEntry>> fetchMealEntriesForUsers(List<String> userIds, {required String from, required String to}) async {
    if (userIds.isEmpty) return [];
    final rows = await requireSupabase()
        .from('meal_entries')
        .select()
        .inFilter('user_id', userIds)
        .gte('record_date', from)
        .lte('record_date', to);
    return [
      for (final row in rows as List) ?MealEntry.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  /// 차트·통계용. 사진 URL은 만들지 않는다.
  Future<List<DailyRecord>> fetchForUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final client = requireSupabase();
    final rows = await client
        .from('daily_records')
        .select()
        .inFilter('user_id', userIds)
        .order('record_date', ascending: true);
    return [for (final row in rows as List) DailyRecord.fromMap(Map<String, dynamic>.from(row as Map))];
  }

  Future<Map<String, double>> fetchPreviousWeights({required List<String> userIds, required String beforeDate}) async {
    if (userIds.isEmpty) return {};
    final client = requireSupabase();
    final rows = await client
        .from('daily_records')
        .select('user_id, weight, record_date')
        .inFilter('user_id', userIds)
        .lt('record_date', beforeDate)
        .not('weight', 'is', null)
        .order('record_date', ascending: true);
    final latest = <String, double>{};
    for (final row in rows as List) {
      latest[row['user_id'] as String] = (row['weight'] as num).toDouble();
    }
    return latest;
  }

  Future<Set<String>> fetchPokedUserIds({required String groupId}) async {
    final client = requireSupabase();
    // 휴대폰 날짜의 자정을 UTC로 바꿔 보낸다. 시간대 없이 보내면 서버가 UTC 자정으로 읽는다.
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final rows = await client.from('pokes').select('receiver_id').eq('group_id', groupId).gte('created_at', start);
    return {for (final row in rows as List) row['receiver_id'] as String};
  }

  Future<List<PokeNotice>> fetchPokesFor({required String groupId, required String receiverId}) async {
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
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          senderName: (row['sender'] as Map?)?['nickname'] as String? ?? '멤버',
        ),
    ];
  }

  Future<DailyRecord?> previousWeightBefore({required String userId, required String date}) async {
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
    // 창을 연 뒤 날짜가 바뀌었으면 어제 사진을 오늘로 옮기지 않도록 지금 오늘 기록에서 다시 읽는다.
    var bodyPath = draft.removeBody ? null : existing?.bodyPhotoPath;
    var mealPath = draft.removeMeal ? null : existing?.mealPhotoPath;

    if (draft.bodyPhotoPath != null) {
      bodyPath = await _uploadPhoto(userId: user.id, name: today, path: draft.bodyPhotoPath!, bucket: 'body-photos');
    }
    if (draft.mealPhotoPath != null) {
      mealPath = await _uploadPhoto(userId: user.id, name: today, path: draft.mealPhotoPath!, bucket: 'meal-photos');
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

    // points_earned, 지갑, 스트릭은 서버 트리거(daily_records_points / daily_records_wallet)가 계산한다.
    final payload = {
      'user_id': user.id,
      'record_date': today,
      'weight': weight,
      'body_photo_url': bodyPath,
      'meal_photo_url': mealPath,
      'workout_minutes': draft.kinds.isEmpty || restOnly ? null : draft.workoutMinutes,
      'workout_kinds': draft.kinds.isEmpty
          ? null
          : [
              for (final kind in WorkoutKind.values)
                if (draft.kinds.contains(kind)) kind.dbValue,
            ],
      'memo': memo.isEmpty ? null : memo,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await client.from('daily_records').upsert(payload, onConflict: 'user_id,record_date');
  }

  /// 눈바디 기록 저장. 체중, 눈바디 사진, 메모만 바꾸고 식단·운동 칸은 그대로 둔다.
  Future<void> saveBody({
    required String date,
    required String weight,
    required String memo,
    String? newPhotoPath,
    bool removePhoto = false,
  }) async {
    final client = requireSupabase();
    final user = client.auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    final existing = await fetchForUserOn(user.id, date);

    var bodyPath = removePhoto ? null : existing?.bodyPhotoPath;
    if (newPhotoPath != null) {
      bodyPath = await _uploadPhoto(userId: user.id, name: date, path: newPhotoPath, bucket: 'body-photos');
    }
    final value = roundWeight(weight);
    if (value == null && bodyPath == null) {
      throw StateError('체중이나 눈바디 사진 중 하나는 필요합니다.');
    }
    final note = memo.trim();

    // 보낸 칸만 바뀐다. points_earned, 지갑, 스트릭은 서버 트리거가 계산한다.
    await client.from('daily_records').upsert({
      'user_id': user.id,
      'record_date': date,
      'weight': value,
      'body_photo_url': bodyPath,
      'memo': note.isEmpty ? null : note,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,record_date');
    // 사진을 빼면 파일도 지워서 그룹원이 더 볼 수 없게 한다.
    if (removePhoto && newPhotoPath == null) {
      await _removeOwnPhoto(userId: user.id, bucket: 'body-photos', path: existing?.bodyPhotoPath);
    }
  }

  /// 그 날을 휴식 데이로 남긴다. 루틴 순서는 그대로고, 달력에는 '휴'로 보인다.
  Future<void> saveRestDay(String date) async {
    final client = requireSupabase();
    final user = client.auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    await client.from('daily_records').upsert({
      'user_id': user.id,
      'record_date': date,
      'workout_kinds': [WorkoutKind.rest.dbValue],
      'workout_minutes': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,record_date');
  }

  /// 한 끼 저장. 하루 기록의 식단 표시와 점수는 서버 트리거(meal_entries_sync_day)가 맞춘다.
  Future<void> saveMeal({
    required String date,
    required MealSlot slot,
    required String description,
    required MealCategory category,
    String? newPhotoPath,
    bool removePhoto = false,
  }) async {
    final client = requireSupabase();
    final user = client.auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    final row = await client
        .from('meal_entries')
        .select()
        .eq('user_id', user.id)
        .eq('record_date', date)
        .eq('slot', slot.dbValue)
        .maybeSingle();
    final existing = row == null ? null : MealEntry.fromMap(row);

    var photoPath = removePhoto ? null : existing?.photoPath;
    if (newPhotoPath != null) {
      photoPath = await _uploadPhoto(
        userId: user.id,
        name: '$date-${slot.dbValue}',
        path: newPhotoPath,
        bucket: 'meal-photos',
      );
    }
    final text = description.trim();
    if (photoPath == null && text.isEmpty) {
      throw StateError('사진이나 메뉴 중 하나는 필요합니다.');
    }

    await client.from('meal_entries').upsert({
      'user_id': user.id,
      'record_date': date,
      'slot': slot.dbValue,
      'photo_url': photoPath,
      'description': text.isEmpty ? null : text,
      'category': category.dbValue,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,record_date,slot');
    if (removePhoto && newPhotoPath == null) {
      await _removeOwnPhoto(userId: user.id, bucket: 'meal-photos', path: existing?.photoPath);
    }
  }

  /// 한 끼를 지운다. 사진 파일도 지워서 그룹원이 더 볼 수 없게 한다.
  Future<void> deleteMeal({required String date, required MealSlot slot}) async {
    final client = requireSupabase();
    final user = client.auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    final rows = await client
        .from('meal_entries')
        .delete()
        .eq('user_id', user.id)
        .eq('record_date', date)
        .eq('slot', slot.dbValue)
        .select('photo_url');
    for (final row in rows as List) {
      await _removeOwnPhoto(
        userId: user.id,
        bucket: 'meal-photos',
        path: canonicalStoragePath((row as Map)['photo_url'] as String?, 'meal-photos'),
      );
    }
  }

  /// 내 폴더의 사진 파일을 지운다. 기록은 이미 저장됐으니 파일 지우기가 실패해도 넘어간다.
  Future<void> _removeOwnPhoto({required String userId, required String bucket, required String? path}) async {
    if (path == null || !path.startsWith('$userId/')) return;
    try {
      await requireSupabase().storage.from(bucket).remove([path]);
    } on StorageException {
      // 다음에 같은 날 사진을 올리면 덮어쓴다.
    }
  }

  Future<void> poke({required String groupId, required String receiverId}) async {
    final client = requireSupabase();
    final senderId = client.auth.currentUser?.id;
    if (senderId == null) return;
    try {
      await client.from('pokes').insert({'group_id': groupId, 'sender_id': senderId, 'receiver_id': receiverId});
    } on PostgrestException catch (error) {
      // 같은 사람은 하루 한 번만 찌를 수 있다(서버 정책).
      // 오늘 이미 찔렀거나, 상대가 나를 차단했을 때다. 차단 여부는 알리지 않는다.
      if (error.code == '42501') throw StateError('오늘은 더 찌를 수 없어요. 내일 다시 찔러 주세요.');
      rethrow;
    }
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

  /// 내 댓글이나, 내 사진에 달린 댓글을 지운다(서버 정책 comments_delete).
  Future<void> deleteComment(String commentId) async {
    await requireSupabase().from('comments').delete().eq('id', commentId);
  }

  Future<List<Map<String, dynamic>>> fetchComments({required String groupId, required String recordId}) async {
    final client = requireSupabase();
    final rows = await client
        .from('comments')
        .select('*, profiles(nickname)')
        .eq('group_id', groupId)
        .eq('record_id', recordId)
        .order('created_at', ascending: true);
    return [for (final row in rows as List) Map<String, dynamic>.from(row as Map)];
  }

  Future<String> _uploadPhoto({
    required String userId,
    required String name,
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
    final objectPath = '$userId/$name.jpg';
    await client.storage
        .from(bucket)
        .uploadBinary(objectPath, compressed, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
    return objectPath;
  }
}

Future<String?> pickImagePath(ImageSource source) async {
  final file = await ImagePicker().pickImage(source: source, imageQuality: 95);
  return file?.path;
}
