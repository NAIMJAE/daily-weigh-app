import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../record/record_sheet.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _tab(context, 0, Icons.home_outlined, Icons.home, '홈'),
                _tab(context, 1, Icons.photo_camera_outlined, Icons.photo_camera, '눈바디'),
                Expanded(
                  child: Transform.translate(
                    offset: const Offset(0, -10),
                    child: Center(
                      child: Material(
                        color: AppColors.accent,
                        shape: const CircleBorder(
                          side: BorderSide(color: Colors.white, width: 3),
                        ),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => showRecordSheet(context),
                          child: const SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(Icons.add, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _tab(context, 2, Icons.show_chart, Icons.show_chart, '통계'),
                _tab(context, 3, Icons.person_outline, Icons.person, '마이'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    int index,
    IconData outlined,
    IconData filled,
    String label,
  ) {
    final selected = navigationShell.currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? filled : outlined, color: selected ? AppColors.accent : AppColors.muted),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? AppColors.accent : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
