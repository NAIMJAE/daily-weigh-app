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

/// 끼니의 식사 종류. 한 끼에 하나만 고른다. 통계의 식사 종류 비율이 이 값으로 센다.
enum MealCategory { home, eatout, delivery, salad, simple, cheat }

extension MealCategoryX on MealCategory {
  String get dbValue => name;

  String get label => switch (this) {
    MealCategory.home => '집밥',
    MealCategory.eatout => '외식',
    MealCategory.delivery => '배달',
    MealCategory.salad => '샐러드',
    MealCategory.simple => '간편식',
    MealCategory.cheat => '치팅',
  };
}

/// 종류 칸을 읽는다. 종류가 없는 예전 기록은 첫 태그(tags)를 종류로 본다.
MealCategory? mealCategoryFrom(Object? category, [Object? legacyTags]) {
  final value = category ?? (legacyTags is List && legacyTags.isNotEmpty ? legacyTags.first : null);
  for (final item in MealCategory.values) {
    if (item.dbValue == '$value') return item;
  }
  return null;
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
    this.category,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String recordDate;
  final MealSlot slot;
  final String? photoPath;
  final String? photoUrl;
  final String? description;
  final MealCategory? category;
  final DateTime? updatedAt;

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
      category: category,
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
      category: mealCategoryFrom(map['category'], map['tags']),
      updatedAt: map['updated_at'] == null ? null : DateTime.tryParse(map['updated_at'] as String),
    );
  }
}
