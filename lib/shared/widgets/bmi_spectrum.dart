import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/profile.dart';

class BmiPin {
  const BmiPin({required this.nickname, required this.bmi, required this.weight, required this.isMe});

  final String nickname;
  final double bmi;
  final double weight;
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

const _bands = [
  (14.5, 18.5, '저체중', '< 18.5'),
  (18.5, 23.0, '정상', '18.5~22.9'),
  (23.0, 25.0, '비만 전단계', '23~24.9'),
  (25.0, 30.0, '1단계 비만', '25~29.9'),
  (30.0, 35.0, '2단계 비만', '30~34.9'),
  (35.0, 39.0, '3단계 비만', '35 이상'),
];

/// 띠마다 같은 각도를 주고, 띠 안에서는 BMI에 비례해 놓는다. 왼쪽이 π, 오른쪽이 0.
double _angleOfBmi(double bmi) {
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

/// 웹 'BMI 스펙트럼'과 같은 반원 게이지: 단계별 띠와 라벨, 바늘, 멤버 이름 알약.
/// 이름 알약을 누르면 바늘이 저울처럼 흔들리며 그 멤버의 BMI로 가고, 알약 옆에 체중과 BMI가 뜬다.
class BmiSpectrum extends StatefulWidget {
  const BmiSpectrum({super.key, required this.pins});

  final List<BmiPin> pins;

  @override
  State<BmiSpectrum> createState() => _BmiSpectrumState();
}

class _BmiSpectrumState extends State<BmiSpectrum> with SingleTickerProviderStateMixin {
  late final AnimationController _swing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  final _pillRects = <int, Rect>{};
  int? _selected;
  double? _fromAngle;
  double? _toAngle;

  @override
  void initState() {
    super.initState();
    _toAngle = _restAngle();
  }

  @override
  void didUpdateWidget(covariant BmiSpectrum oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pins.length != widget.pins.length) _selected = null;
    if (!_swing.isAnimating) {
      _fromAngle = null;
      _toAngle = _selected == null ? _restAngle() : _angleOfBmi(widget.pins[_selected!].bmi);
    }
  }

  @override
  void dispose() {
    _swing.dispose();
    super.dispose();
  }

  /// 아무도 고르지 않았을 때 바늘은 내 BMI에 있다.
  double? _restAngle() {
    final me = widget.pins.where((pin) => pin.isMe);
    return me.isEmpty ? null : _angleOfBmi(me.first.bmi);
  }

  double? get _needleAngle {
    final to = _toAngle;
    if (to == null) return null;
    final from = _fromAngle ?? to;
    final t = const ElasticOutCurve(0.55).transform(_swing.value);
    return from + (to - from) * t;
  }

  void _onTap(Offset position) {
    int? hit;
    for (final entry in _pillRects.entries) {
      if (entry.value.inflate(4).contains(position)) hit = entry.key;
    }
    // 같은 알약이나 빈 곳을 누르면 선택을 풀고 바늘은 내 BMI로 돌아간다.
    final next = hit == _selected ? null : hit;
    final target = next == null ? _restAngle() : _angleOfBmi(widget.pins[next].bmi);
    setState(() {
      _fromAngle = _needleAngle ?? pi / 2;
      _toAngle = target;
      _selected = next;
    });
    if (target != null) _swing.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final pins = widget.pins;
    if (pins.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('키와 체중이 있는 멤버가 없습니다.', style: AppText.label)),
      );
    }
    return AspectRatio(
      aspectRatio: 360 / 250,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _onTap(details.localPosition),
        child: AnimatedBuilder(
          animation: _swing,
          builder: (context, _) => CustomPaint(
            // 이름표가 캔버스 밖으로 밀려나지 않도록 글자 확대는 1.4배까지만 따른다.
            painter: _GaugePainter(
              pins,
              MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4),
              needleAngle: _needleAngle,
              selected: _selected,
              pillRects: _pillRects,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(
    this.pins,
    this.textScaler, {
    required this.needleAngle,
    required this.selected,
    required this.pillRects,
  });

  final List<BmiPin> pins;
  final TextScaler textScaler;
  final double? needleAngle;
  final int? selected;

  /// 그린 알약 자리를 탭 판정에 쓰도록 위젯에 돌려준다.
  final Map<int, Rect> pillRects;

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

    // 바늘: 고른 멤버, 없으면 내 BMI
    if (needleAngle case final a?) {
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
    final order = [for (var i = 0; i < pins.length; i++) i]
      ..sort((a, b) => (pins[b].isMe ? 1 : 0) - (pins[a].isMe ? 1 : 0));
    pillRects.clear();
    for (final pinIndex in order) {
      final pin = pins[pinIndex];
      final picked = pinIndex == selected;
      final a = _angleOfBmi(pin.bmi);
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
      pillRects[pinIndex] = spot;

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
          ..color = picked
              ? AppColors.ink
              : pin.isMe
              ? AppColors.accent.withValues(alpha: 0.4)
              : AppColors.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = picked ? 1.6 : 1,
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

    if (selected case final index? when pillRects[index] != null) {
      _paintBubble(canvas, size, pins[index], pillRects[index]!);
    }
  }

  /// 고른 알약 옆 말풍선: 닉네임, 체중, BMI와 단계.
  void _paintBubble(Canvas canvas, Size size, BmiPin pin, Rect pill) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: textScaler.clamp(maxScaleFactor: 1.2),
      text: TextSpan(
        children: [
          TextSpan(
            text: '${pin.isMe ? '나' : pin.nickname}\n',
            style: const TextStyle(
              fontFamily: AppText.sans,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          AppText.mixed(
            '${pin.weight.toStringAsFixed(1)}kg · BMI ${pin.bmi.toStringAsFixed(1)}\n',
            AppText.number(size: 11, weight: FontWeight.w700, color: Colors.white),
          ),
          TextSpan(
            text: bmiCategory(pin.bmi),
            style: TextStyle(
              fontFamily: AppText.sans,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    )..layout(maxWidth: size.width - 16);
    final w = tp.width + 16;
    final h = tp.height + 10;
    const gap = 6.0;
    // 위에 자리가 있으면 위, 없으면 아래.
    final above = pill.top - gap - h >= 0;
    final top = above ? pill.top - gap - h : pill.bottom + gap;
    final left = (pill.center.dx - w / 2).clamp(4.0, max(4.0, size.width - w - 4)).toDouble();
    final rect = Rect.fromLTWH(left, top, w, h);
    final bubble = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(bubble.shift(const Offset(0, 2)), Paint()..color = const Color(0x22000000));
    canvas.drawRRect(bubble, Paint()..color = AppColors.ink);
    final tipX = pill.center.dx.clamp(rect.left + 10, rect.right - 10).toDouble();
    final tail = Path();
    if (above) {
      tail
        ..moveTo(tipX - 5, rect.bottom)
        ..lineTo(tipX, rect.bottom + 5)
        ..lineTo(tipX + 5, rect.bottom);
    } else {
      tail
        ..moveTo(tipX - 5, rect.top)
        ..lineTo(tipX, rect.top - 5)
        ..lineTo(tipX + 5, rect.top);
    }
    canvas.drawPath(tail..close(), Paint()..color = AppColors.ink);
    tp.paint(canvas, Offset(rect.left + 8, rect.top + 5));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.pins != pins ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.needleAngle != needleAngle ||
      oldDelegate.selected != selected;
}

List<BmiPin> pinsFor({
  required List<Profile> profiles,
  required String? myId,
  required double? Function(String userId) weightOf,
}) {
  return [
    for (final profile in profiles)
      if (weightOf(profile.id) case final weight?)
        if (bmiOf(heightCm: profile.height, weightKg: weight) case final bmi?)
          BmiPin(nickname: profile.nickname, bmi: bmi, weight: weight, isMe: profile.id == myId),
  ];
}
