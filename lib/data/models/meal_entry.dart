import '../../core/utils/storage_path.dart';

enum MealSlot { breakfast, lunch, dinner, snack }

MealSlot? mealSlotFrom(String? value) {
  return switch (value) {
    'breakfast' => MealSlot.breakfast,
    'lunch' => MealSlot.lunch,
    'dinner' => MealSlot.dinner,
    'snack' => MealSlot.snack,
    _ => null,
  };
}

extension MealSlotX on MealSlot {
  String get dbValue => name;

  String get label => switch (this) {
    MealSlot.breakfast => '아침',
    MealSlot.lunch => '점심',
    MealSlot.dinner => '저녁',
    MealSlot.snack => '간식',
  };
}

/// 끼니에 붙이는 빠른 태그. 여러 개 고를 수 있다.
enum MealTag { home, eatout, delivery, salad, simple, cheat }

extension MealTagX on MealTag {
  String get dbValue => name;

  String get label => switch (this) {
    MealTag.home => '집밥',
    MealTag.eatout => '외식',
    MealTag.delivery => '배달',
    MealTag.salad => '샐러드',
    MealTag.simple => '간편식',
    MealTag.cheat => '치팅',
  };
}

Set<MealTag> mealTagsFrom(Object? raw) {
  if (raw is! List) return {};
  return {
    for (final item in raw)
      for (final tag in MealTag.values)
        if (tag.dbValue == '$item') tag,
  };
}

/// 하루 한 끼의 식단 기록. 사용자·날짜·끼니마다 하나다.
class MealEntry {
  const MealEntry({
    required this.id,
    required this.userId,
    required this.recordDate,
    required this.slot,
    this.photoPath,
    this.photoUrl,
    this.description,
    this.tags = const {},
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String recordDate;
  final MealSlot slot;
  final String? photoPath;
  final String? photoUrl;
  final String? description;
  final Set<MealTag> tags;
  final DateTime? updatedAt;

  String get tagSummary => [
    for (final tag in MealTag.values)
      if (tags.contains(tag)) tag.label,
  ].join(' · ');

  // DailyRecord 와 같이 서명 URL 대신 저장 경로와 수정 시각으로 캐시를 찾는다.
  String? get photoCacheKey {
    if (photoPath == null || photoPath!.isEmpty) return null;
    return 'meal-photos/$photoPath#${updatedAt?.millisecondsSinceEpoch ?? 0}';
  }

  MealEntry copyWith({String? photoUrl}) {
    return MealEntry(
      id: id,
      userId: userId,
      recordDate: recordDate,
      slot: slot,
      photoPath: photoPath,
      photoUrl: photoUrl ?? this.photoUrl,
      description: description,
      tags: tags,
      updatedAt: updatedAt,
    );
  }

  static MealEntry? fromMap(Map<String, dynamic> map) {
    final slot = mealSlotFrom(map['slot'] as String?);
    if (slot == null) return null;
    return MealEntry(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      recordDate: map['record_date'] as String,
      slot: slot,
      photoPath: canonicalStoragePath(map['photo_url'] as String?, 'meal-photos'),
      description: map['description'] as String?,
      tags: mealTagsFrom(map['tags']),
      updatedAt: map['updated_at'] == null ? null : DateTime.tryParse(map['updated_at'] as String),
    );
  }
}
