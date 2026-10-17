import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';

/// 이름 첫 글자 동그라미. 앱은 프로필 사진을 쓰지 않는다.
class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 32, this.highlight = false});

  final String name;
  final double size;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.ink,
        shape: BoxShape.circle,
        border: highlight ? Border.all(color: AppColors.accent, width: 2) : null,
      ),
      child: Text(
        initial,
        style: TextStyle(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// 두 값 중 하나를 고르는 작은 전환 버튼 (웹의 '변화량 | 절대체중').
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({super.key, required this.options, required this.value, required this.onChanged});

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.mutedBg,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (option, label) in options)
            Semantics(
              button: true,
              selected: option == value,
              child: GestureDetector(
                onTap: () => onChanged(option),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 28),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: option == value ? AppColors.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: option == value
                        ? const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))]
                        : null,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: option == value ? FontWeight.w700 : FontWeight.w500,
                      color: option == value ? AppColors.ink : AppColors.faint,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 그래프 범례 칩: 색 점 + 이름.
class LegendChip extends StatelessWidget {
  const LegendChip({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// 2×2 정보 타일 한 칸: 작은 아이콘·라벨 + 굵은 숫자.
class InfoTile extends StatelessWidget {
  const InfoTile({super.key, required this.icon, required this.label, required this.value, this.valueColor});

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.accent),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label, style: AppText.caption.copyWith(color: AppColors.muted)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          NumText(value, style: AppText.number(size: 14, color: valueColor ?? AppColors.ink)),
        ],
      ),
    );
  }
}

/// 테두리 있는 멤버 줄. 내 줄은 연한 주황 바탕.
class MemberRow extends StatelessWidget {
  const MemberRow({
    super.key,
    required this.name,
    this.subtitle,
    this.isMe = false,
    this.isOwner = false,
    this.trailing,
    this.onTap,
  });

  final String name;
  final String? subtitle;
  final bool isMe;
  final bool isOwner;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isMe ? AppColors.accentSoft : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        side: BorderSide(color: isMe ? AppColors.chipFill : AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Avatar(name, highlight: isMe),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        if (isMe)
                          const Text(
                            '나',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent),
                          ),
                        if (isOwner) const _OwnerBadge(),
                      ],
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppText.caption),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerBadge extends StatelessWidget {
  const _OwnerBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.warnSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.warnLine),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_outlined, size: 10, color: AppColors.warn),
          SizedBox(width: 2),
          Text(
            '방장',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.warn),
          ),
        ],
      ),
    );
  }
}

/// 스트릭 알약: 불꽃 + 'n일'.
class StreakPill extends StatelessWidget {
  const StreakPill(this.days, {super.key});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.chipFill, borderRadius: BorderRadius.circular(AppRadius.chip)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, size: 14, color: AppColors.accent),
          const SizedBox(width: 2),
          NumText('$days일', style: AppText.number(size: 12, color: AppColors.ink)),
        ],
      ),
    );
  }
}
