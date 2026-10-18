import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../features/session/session_controller.dart';
import '../shared/widgets/app_logo.dart';
import 'router.dart';

class DailyWeighApp extends ConsumerWidget {
  const DailyWeighApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // 세션을 처음 읽는 동안은 네이티브 스플래시와 같은 화면을 이어서 보여 준다.
    final starting = ref.watch(sessionProvider.select((s) => s.isLoading && !s.hasValue));
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // 기간 고르기 달력 같은 기본 위젯도 한국어로 보인다.
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
      builder: (context, child) => starting ? const AppSplash() : child!,
    );
  }
}
