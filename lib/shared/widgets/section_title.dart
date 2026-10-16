import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text.dart';

/// 카드 머리: 연한 주황 바탕의 작은 아이콘 + 14 굵은 제목 + 오른쪽 보조 요소 (웹 카드 머리와 같은 구성).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.icon});

  final String text;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[IconBadge(icon!), const SizedBox(width: 8)],
        Expanded(child: Text(text, style: AppText.title)),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.size = 24});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.chipFill, borderRadius: BorderRadius.circular(size / 2)),
      child: Icon(icon, size: size * 0.6, color: AppColors.accent),
    );
  }
}
