import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// 웹 MVP의 글자 단계. 본문 14, 라벨 12, 보조 11, 아주 작은 표시 10. 숫자는 Geist Mono.
class AppText {
  static const sans = 'Geist';
  static const mono = 'GeistMono';

  static const title = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink);
  static const headline = TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink);
  static const body = TextStyle(fontSize: 14, color: AppColors.ink);
  static const label = TextStyle(fontSize: 12, color: AppColors.muted);
  static const caption = TextStyle(fontSize: 11, color: AppColors.faint);
  static const micro = TextStyle(fontSize: 10, color: AppColors.faint);

  static TextStyle number({double size = 14, FontWeight weight = FontWeight.w700, Color color = AppColors.ink}) {
    return TextStyle(fontFamily: mono, fontSize: size, fontWeight: weight, color: color, letterSpacing: -0.2);
  }

  static final _monoRun = RegExp(r'[0-9A-Za-z.+\-−:/~<>%#,@_]+');

  /// 숫자·영문은 Mono, 공백과 한글은 기본 글꼴로 나눈다. Mono의 공백은 폭이 넓어 '시작  대비'처럼 벌어진다.
  static TextSpan mixed(String text, TextStyle numberStyle) {
    final sansStyle = numberStyle.copyWith(fontFamily: sans, letterSpacing: 0);
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _monoRun.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start), style: sansStyle));
      spans.add(TextSpan(text: m.group(0), style: numberStyle));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: sansStyle));
    return TextSpan(children: spans);
  }
}

/// 숫자와 한글이 섞인 값 (예: '시작 대비 -4.9kg', '46일째', '173 cm').
class NumText extends StatelessWidget {
  const NumText(this.text, {super.key, required this.style, this.textAlign, this.maxLines});

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      AppText.mixed(text, style),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
