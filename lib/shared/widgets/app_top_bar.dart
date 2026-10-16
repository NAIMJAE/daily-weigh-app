import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../features/home/home_controller.dart';
import '../../features/session/session_controller.dart';
import 'ui_parts.dart';

/// 탭 화면 공통 상단 바 (웹 헤더와 같은 구성).
/// 왼쪽: 브랜드 또는 화면 제목 + 그룹 선택 알약. 오른쪽: 스트릭 + 내 아바타.
class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopBar({super.key, this.title, this.icon, this.showGroup = true, this.actions = const []});

  /// 없으면 '● 매일재라' 브랜드를 보여 준다.
  final String? title;
  final IconData? icon;
  final bool showGroup;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final profile = session?.profile;
    return AppBar(
      titleSpacing: AppSpacing.page,
      title: Row(
        children: [
          if (title == null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            const Text('매일재라', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ] else ...[
            if (icon != null) ...[Icon(icon, size: 18, color: AppColors.accent), const SizedBox(width: 6)],
            Flexible(
              child: Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.headline),
            ),
          ],
          if (showGroup && session != null && session.groups.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(child: _GroupPill(session: session)),
          ],
        ],
      ),
      actions: [
        ...actions,
        if (profile != null) ...[
          StreakPill(profile.currentStreak),
          const SizedBox(width: 8),
          Avatar(profile.nickname, size: 28),
        ],
        const SizedBox(width: AppSpacing.page),
      ],
    );
  }
}

class _GroupPill extends ConsumerWidget {
  const _GroupPill({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = session.currentGroup;
    return PopupMenuButton<String>(
      tooltip: '그룹 바꾸기',
      position: PopupMenuPosition.under,
      onSelected: (id) {
        ref.read(sessionProvider.notifier).selectGroup(id);
        ref.invalidate(homeSnapshotProvider);
      },
      itemBuilder: (context) => [
        for (final group in session.groups)
          PopupMenuItem(
            value: group.id,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.isPersonal ? '${group.name} · 개인' : group.name,
                    style: TextStyle(fontWeight: group.id == current?.id ? FontWeight.w700 : FontWeight.w500),
                  ),
                ),
                if (group.id == current?.id) const Icon(Icons.check, size: 16, color: AppColors.accent),
              ],
            ),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_outlined, size: 14, color: AppColors.muted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                current?.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more, size: 16, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}
