import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding ?? const EdgeInsets.all(AppSpacing.card), child: child),
    );
  }
}
