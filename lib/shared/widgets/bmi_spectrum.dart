import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/profile.dart';

class BmiPin {
  const BmiPin({required this.nickname, required this.bmi, required this.isMe});

  final String nickname;
  final double bmi;
  final bool isMe;
}

double? bmiOf({required double? heightCm, required double? weightKg}) {
  if (heightCm == null || weightKg == null || heightCm <= 0) return null;
  final meters = heightCm / 100;
  return weightKg / (meters * meters);
}

/// 대한비만학회 기준 단계 이름.
String bmiCategory(double bmi) {
  if (bmi < 18.5) return '저체중';
  if (bmi < 23) return '정상';
  if (bmi < 25) return '비만 전단계';
  if (bmi < 30) return '1단계 비만';
  if (bmi < 35) return '2단계 비만';
  return '3단계 비만';
}

/// 웹 'BMI 스펙트럼'과 같은 반원 게이지: 단계별 띠와 라벨, 내 BMI 바늘, 멤버 이름 알약.
class BmiSpectrum extends StatelessWidget {
  const BmiSpectrum({super.key, required this.pins});

  final List<BmiPin> pins;

  @override
  Widget build(BuildContext context) {
    if (pins.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('키와 체중이 있는 멤버가 없습니다.', style: AppText.label)),
      );
    }
    return AspectRatio(
      aspectRatio: 360 / 250,
      child: CustomPaint(
        // 이름표가 캔버스 밖으로 밀려나지 않도록 글자 확대는 1.4배까지만 따른다.
        painter: _GaugePainter(pins, MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4)),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.pins, this.textScaler);

  final List<BmiPin> pins;
  final TextScaler textScaler;

  static const _bands = [
    (14.5, 18.5, '저체중', '< 18.5'),
    (18.5, 23.0, '정상', '18.5~22.9'),
    (23.0, 25.0, '비만 전단계', '23~24.9'),
    (25.0, 30.0, '1단계 비만', '25~29.9'),
    (30.0, 35.0, '2단계 비만', '30~34.9'),
    (35.0, 39.0, '3단계 비만', '35 이상'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 위쪽에 이름 알약 자리를 남기고 반원을 아래에 둔다.
    final outer = min(size.width * 0.44, size.height * 0.68);
    final inner = outer * 0.5;
    final center = Offset(size.width / 2, size.height - 6);
    final ring = (outer + inner) / 2;
    final thickness = outer - inner;
    final arcRect = Rect.fromCircle(center: center, radius: ring);

    // 띠. 캔버스 각도는 y가 아래로 커지므로 왼쪽(π)에서 양의 방향으로 돈다.
    final sweep = pi / _bands.length;
    for (var i = 0; i < _bands.length; i++) {
      canvas.drawArc(
        arcRect,
        pi + i * sweep,
        sweep,
        false,
        Paint()
          ..color = AppColors.bmiBands[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness,
      );
    }
    // 띠 사이 흰 구분선
    for (var i = 1; i < _bands.length; i++) {
      final a = pi + i * sweep;
      canvas.drawLine(
        center + Offset(cos(a), sin(a)) * inner,
        center + Offset(cos(a), sin(a)) * outer,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5,
      );
    }
    // 안쪽 반원
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: inner - 4),
      pi,
      pi,
      true,
      Paint()..color = AppColors.gaugeHub,
    );

    // 띠 안 라벨 (이름 + 범위)
    final labelScaler = textScaler.clamp(maxScaleFactor: 1.15);
    for (var i = 0; i < _bands.length; i++) {
      final a = pi + (i + 0.5) * sweep;
      final p = center + Offset(cos(a), sin(a)) * ring;
      final light = i == 2; // 노란 띠는 어두운 글자
      final color = light ? AppColors.ink : Colors.white;
      final tp = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        textScaler: labelScaler,
        text: TextSpan(
          children: [
            TextSpan(
              text: '${_bands[i].$3}\n',
              style: TextStyle(fontFamily: AppText.sans, fontSize: 9, fontWeight: FontWeight.w800, color: color),
            ),
            AppText.mixed(
              _bands[i].$4,
              AppText.number(size: 8, weight: FontWeight.w500, color: color.withValues(alpha: 0.85)),
            ),
          ],
        ),
      )..layout(maxWidth: thickness * 1.25);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    // 내 BMI 바늘
    final me = pins.where((p) => p.isMe).toList();
    if (me.isNotEmpty) {
      final a = _angle(me.first.bmi);
      final tip = center + Offset(cos(a), -sin(a)) * (outer - 6);
      canvas.drawLine(
        center,
        tip,
        Paint()
          ..color = AppColors.ink
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(center, 7, Paint()..color = AppColors.ink);
      canvas.drawCircle(center, 3, Paint()..color = Colors.white);
    }

    // 멤버 이름 알약: 띠 바깥, 자기 BMI 각도 근처에 겹치지 않게 놓는다. 내 알약이 먼저 자리를 잡는다.
    final bounds = Offset.zero & size;
    final taken = <Rect>[Rect.fromCircle(center: center, radius: outer)];
    final order = [...pins]..sort((a, b) => (b.isMe ? 1 : 0) - (a.isMe ? 1 : 0));
    for (final pin in order) {
      final a = _angle(pin.bmi);
      final anchor = center + Offset(cos(a), -sin(a)) * outer;
      final name = pin.isMe ? '나' : pin.nickname;
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
        ellipsis: '…',
        text: TextSpan(
          text: name,
          style: TextStyle(
            fontFamily: AppText.sans,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: pin.isMe ? AppColors.accent : AppColors.ink,
          ),
        ),
      )..layout(maxWidth: 64 * textScaler.scale(1));
      const dot = 14.0;
      final w = dot + 4 + tp.width + 10;
      final h = max(dot, tp.height) + 6;
      Rect? spot;
      for (var k = 0; k < 10 && spot == null; k++) {
        final r = 10.0 + k * (h * 0.9);
        final c = center + Offset(cos(a), -sin(a)) * (outer + r);
        for (final dx in [0.0, -w * 0.6, w * 0.6]) {
          final rect = Rect.fromCenter(center: c + Offset(dx, 0), width: w, height: h);
          final inside = bounds.contains(rect.topLeft) && bounds.contains(rect.bottomRight);
          if (inside && !taken.any((t) => t.overlaps(rect.inflate(1)))) {
            spot = rect;
            break;
          }
        }
      }
      spot ??= Rect.fromCenter(center: anchor + Offset(0, -h), width: w, height: h);
      taken.add(spot);

      // 알약에서 띠까지 짧은 연결선
      canvas.drawLine(
        anchor,
        Offset(spot.center.dx.clamp(spot.left + 6, spot.right - 6), spot.bottom),
        Paint()
          ..color = AppColors.faint.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
      final rrect = RRect.fromRectAndRadius(spot, Radius.circular(h / 2));
      canvas.drawRRect(rrect.shift(const Offset(0, 1)), Paint()..color = const Color(0x14000000));
      canvas.drawRRect(rrect, Paint()..color = pin.isMe ? AppColors.chipFill : Colors.white);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = pin.isMe ? AppColors.accent.withValues(alpha: 0.4) : AppColors.line
          ..style = PaintingStyle.stroke,
      );
      final dotCenter = Offset(spot.left + 3 + dot / 2, spot.center.dy);
      canvas.drawCircle(dotCenter, dot / 2, Paint()..color = pin.isMe ? AppColors.accent : AppColors.ink);
      final initial = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: pin.nickname.characters.first,
          style: const TextStyle(
            fontFamily: AppText.sans,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      )..layout();
      initial.paint(canvas, dotCenter - Offset(initial.width / 2, initial.height / 2));
      tp.paint(canvas, Offset(spot.left + 3 + dot + 4, spot.center.dy - tp.height / 2));
    }
  }

  double _angle(double bmi) {
    final clamped = bmi.clamp(14.5, 39.0);
    var covered = 0.0;
    for (final band in _bands) {
      final span = band.$2 - band.$1;
      if (clamped <= band.$2) {
        final ratio = ((clamped - band.$1) / span).clamp(0.0, 1.0);
        return pi - ((covered + ratio) / _bands.length) * pi;
      }
      covered += 1;
    }
    return 0;
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.pins != pins || oldDelegate.textScaler != textScaler;
}

List<BmiPin> pinsFor({
  required List<Profile> profiles,
  required String? myId,
  required double? Function(String userId) weightOf,
}) {
  return [
    for (final profile in profiles)
      if (bmiOf(heightCm: profile.height, weightKg: weightOf(profile.id)) case final bmi?)
        BmiPin(nickname: profile.nickname, bmi: bmi, isMe: profile.id == myId),
  ];
}
