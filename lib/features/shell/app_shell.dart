import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';

/// 하단 탭: 홈, 기록, 통계, 샵, 마이페이지 (얇은 아이콘 + 11 라벨).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          // 큰 글자에서도 탭 이름이 한 줄에 들어가도록 확대를 1.4배로 묶고, 높이는 내용만큼 늘린다.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 58),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _tab(0, Icons.grid_view_outlined, Icons.grid_view_rounded, '홈'),
                    _tab(1, Icons.edit_calendar_outlined, Icons.edit_calendar, '기록'),
                    _tab(2, Icons.insights_outlined, Icons.insights, '통계'),
                    _tab(3, Icons.storefront_outlined, Icons.storefront, '샵'),
                    _tab(4, Icons.person_outline, Icons.person, '마이페이지'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int index, IconData outlined, IconData filled, String label) {
    final selected = navigationShell.currentIndex == index;
    final color = selected ? AppColors.accent : AppColors.faint;
    return Expanded(
      child: InkWell(
        onTap: () => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? filled : outlined, size: 20, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
