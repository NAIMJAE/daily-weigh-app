import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../record/record_sheet.dart';

/// 하단 탭 (웹 하단 탭과 같은 구성: 얇은 아이콘 + 11 라벨, 가운데 떠 있는 기록 버튼).
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
                    _tab(0, Icons.grid_view_outlined, Icons.grid_view_rounded, '대시보드'),
                    _tab(1, Icons.visibility_outlined, Icons.visibility, '눈바디'),
                    Expanded(
                      child: Transform.translate(
                        offset: const Offset(0, -14),
                        child: Center(
                          child: Semantics(
                            button: true,
                            label: '오늘 기록',
                            child: Material(
                              color: AppColors.accent,
                              shape: const CircleBorder(side: BorderSide(color: AppColors.card, width: 3)),
                              elevation: 6,
                              shadowColor: AppColors.accent.withValues(alpha: 0.5),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => showRecordSheet(context),
                                child: const SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: Icon(Icons.add, color: Colors.white, size: 26),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _tab(2, Icons.insights_outlined, Icons.insights, '통계'),
                    _tab(3, Icons.person_outline, Icons.person, '마이페이지'),
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
