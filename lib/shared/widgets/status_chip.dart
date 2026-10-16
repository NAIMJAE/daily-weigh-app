import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';

enum ChipTone { accent, danger, warn, success, neutral }

/// 작은 배지 (방장, 비만, 코드, +15P …). 웹의 연한 바탕 + 같은 계열 글자 배지.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = ChipTone.accent, this.icon, this.mono = false});

  final String label;
  final ChipTone tone;
  final IconData? icon;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (tone) {
      ChipTone.accent => (AppColors.chipFill, AppColors.accent, AppColors.chipFill),
      ChipTone.danger => (AppColors.dangerSoft, AppColors.danger, AppColors.dangerLine),
      ChipTone.warn => (AppColors.warnSoft, AppColors.warn, AppColors.warnLine),
      ChipTone.success => (AppColors.successSoft, AppColors.success, AppColors.successSoft),
      ChipTone.neutral => (AppColors.mutedBg, AppColors.muted, AppColors.line),
    };
    final style = mono
        ? AppText.number(size: 11, color: fg)
        : TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 3)],
          mono ? NumText(label, style: style) : Text(label, style: style),
        ],
      ),
    );
  }
}
