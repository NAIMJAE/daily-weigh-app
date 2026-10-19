import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// 앱 아이콘(눈금 저울). assets/icon/app_icon.svg와 같은 모양을 108 칸 기준으로 그린다.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _AppLogoPainter());
  }
}

class _AppLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 108);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 108, 108), const Radius.circular(24)),
      Paint()..color = AppColors.accent,
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(54, 68), radius: 30),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(54, 68),
      const Offset(68, 46),
      Paint()
        ..color = AppColors.ink
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(54, 68), 7, Paint()..color = AppColors.ink);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(30, 80, 48, 6), const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_AppLogoPainter oldDelegate) => false;
}

/// 네이티브 스플래시(흰 바탕, 가운데 128dp 아이콘)와 똑같이 보이는 첫 로딩 화면.
class AppSplash extends StatelessWidget {
  const AppSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.white,
      child: Center(child: AppLogo(size: 128)),
    );
  }
}
