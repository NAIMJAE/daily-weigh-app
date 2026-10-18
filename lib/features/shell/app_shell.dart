import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../workout/active_workout_controller.dart';
import '../workout/today_routine_card.dart';

/// 하단 탭: 홈, 기록, 통계, 샵, 마이페이지 (얇은 아이콘 + 11 라벨).
/// 끝내지 않은 운동이 있으면 탭 바로 위에 이어 하기 시트가 붙는다.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeWorkout = ref.watch(activeWorkoutProvider).value;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (activeWorkout != null) ResumeWorkoutBar(workout: activeWorkout),
          _tabBar(),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return DecoratedBox(
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
