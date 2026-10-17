import 'package:flutter/material.dart';

/// 기록 탭에서 고르는 기록 종류. 홈 바로가기도 같은 목록을 쓴다.
enum RecordType { body, meal, workout }

extension RecordTypeX on RecordType {
  String get label => switch (this) {
    RecordType.body => '눈바디',
    RecordType.meal => '식단',
    RecordType.workout => '운동',
  };

  String get title => '$label 기록';

  String get description => switch (this) {
    RecordType.body => '눈바디 사진과 체중',
    RecordType.meal => '아침 · 점심 · 저녁 · 간식',
    RecordType.workout => '운동한 날과 운동 종류',
  };

  IconData get icon => switch (this) {
    RecordType.body => Icons.accessibility_new,
    RecordType.meal => Icons.restaurant_outlined,
    RecordType.workout => Icons.fitness_center_outlined,
  };

  String get path => '/records/$name';
}
