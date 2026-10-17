import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/section_title.dart';

/// 포인트를 쓰는 상점 자리. 아직 열지 않았다.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppTopBar(title: '샵', icon: Icons.storefront_outlined, showGroup: false),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconBadge(Icons.storefront_outlined, size: 48),
              SizedBox(height: 12),
              Text('준비 중이에요', style: AppText.headline),
              SizedBox(height: 4),
              Text('기록으로 모은 포인트를 여기서 쓸 수 있게 될 거예요.', textAlign: TextAlign.center, style: AppText.label),
            ],
          ),
        ),
      ),
    );
  }
}
