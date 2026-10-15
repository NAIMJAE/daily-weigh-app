import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
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

class BmiSpectrum extends StatelessWidget {
  const BmiSpectrum({super.key, required this.pins});

  final List<BmiPin> pins;

  @override
  Widget build(BuildContext context) {
    if (pins.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('BMI', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 360 / 210,
          child: CustomPaint(
            painter: _SpectrumPainter(pins),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter(this.pins);

  final List<BmiPin> pins;

  static const _bands = [
    (Color(0xFF5C887B), 14.5, 18.5),
    (Color(0xFF72BF8E), 18.5, 23.0),
    (Color(0xFFF5B754), 23.0, 25.0),
    (Color(0xFFE87352), 25.0, 30.0),
    (Color(0xFFD93B3E), 30.0, 35.0),
    (Color(0xFF991B24), 35.0, 39.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.92);
    final outer = size.width * 0.46;
    final inner = outer * 0.52;
    final rect = Rect.fromCircle(center: center, radius: outer);
    for (var i = 0; i < _bands.length; i++) {
      final start = pi - (i * pi / _bands.length);
      final sweep = -pi / _bands.length;
      final paint = Paint()
        ..color = _bands[i].$1
        ..style = PaintingStyle.stroke
        ..strokeWidth = outer - inner;
      canvas.drawArc(rect.deflate((outer - inner) / 2), start, sweep, false, paint);
    }

    for (final pin in pins) {
      final angle = _angle(pin.bmi);
      final radius = outer - 8;
      final point = Offset(
        center.dx + cos(angle) * radius,
        center.dy - sin(angle) * (outer * 0.92),
      );
      canvas.drawCircle(point, pin.isMe ? 7 : 5, Paint()..color = pin.isMe ? AppColors.accent : AppColors.ink);
      final text = TextPainter(
        text: TextSpan(
          text: pin.nickname,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 10,
            fontWeight: pin.isMe ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 72);
      text.paint(canvas, point + const Offset(8, -6));
    }
  }

  double _angle(double bmi) {
    final clamped = bmi.clamp(14.5, 39.0);
    var covered = 0.0;
    for (final band in _bands) {
      final span = band.$3 - band.$2;
      if (clamped <= band.$3) {
        final ratio = ((clamped - band.$2) / span).clamp(0.0, 1.0);
        return pi - ((covered + ratio) / _bands.length) * pi;
      }
      covered += 1;
    }
    return 0;
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) => oldDelegate.pins != pins;
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
