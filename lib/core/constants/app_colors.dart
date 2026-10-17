import 'package:flutter/material.dart';

/// 웹 MVP(daily-weigh.netlify.app)의 디자인 토큰과 같은 값.
class AppColors {
  static const accent = Color(0xFFFF4D00); // --primary
  static const accentDark = Color(0xFFE64500); // --primary-hover
  static const accentSoft = Color(0xFFFFF9F6); // 강조 영역 바탕 (내 줄, 기록 대상 그룹)
  static const chipFill = Color(0xFFFFF1EB); // 강조 배지·선택 칩 바탕
  static const ink = Color(0xFF111111); // --foreground
  static const muted = Color(0xFF666666); // --secondary
  static const faint = Color(0xFF999999); // --muted
  static const line = Color(0xFFE5E5E5); // --border
  static const canvas = Color(0xFFFAFAFA); // --background
  static const card = Color(0xFFFFFFFF); // --card
  static const mutedBg = Color(0xFFF4F4F5); // --muted-bg
  static const stage = Color(0xFFECEEF2);
  static const gaugeHub = Color(0xFFF8F5EE); // BMI 게이지 안쪽 반원
  static const success = Color(0xFF009767); // emerald-600
  static const successSoft = Color(0xFFECFDF5); // emerald-50
  static const danger = Color(0xFFE40014); // red-600
  static const dangerSoft = Color(0xFFFEF2F2); // red-50
  static const dangerLine = Color(0xFFFFCACA); // red-200
  static const warn = Color(0xFFB75000); // amber-700
  static const warnSoft = Color(0xFFFFFBEB); // amber-50
  static const warnLine = Color(0xFFFEE685); // amber-200

  static const bmiBands = [
    Color(0xFF5C887B),
    Color(0xFF72BF8E),
    Color(0xFFF5B754),
    Color(0xFFE87352),
    Color(0xFFD93B3E),
    Color(0xFF991B24),
  ];

  // 웹 그래프와 같은 순서: 파랑, 빨강, 초록, 주황 …
  static const chartSeries = [
    Color(0xFF3080FF),
    Color(0xFFFB2C36),
    Color(0xFF00BB7F),
    Color(0xFFF99C00),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFF3F3F46),
  ];
}
