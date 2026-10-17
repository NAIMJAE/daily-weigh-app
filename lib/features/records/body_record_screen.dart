import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/local_date.dart';
import '../session/session_controller.dart';
import 'record_browser.dart';
import 'record_type.dart';
import 'records_controller.dart';

class BodyRecordScreen extends ConsumerWidget {
  const BodyRecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(sessionProvider).value?.userId;
    final records = ref.watch(myDailyRecordsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(RecordType.body.title),
        actions: [
          // 겹쳐보기는 내 눈바디 사진만 쓴다.
          IconButton(
            tooltip: '겹쳐보기',
            onPressed: userId == null ? null : () => context.push('/overlay/$userId'),
            icon: const Icon(Icons.compare_outlined),
          ),
        ],
      ),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(friendlyError(error))),
        data: (byDate) => ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            RecordBrowser(
              emptyIcon: RecordType.body.icon,
              countLabel: '기록한 날',
              onEditDay: (date) => context.push('/write/body?date=${localDateString(date)}'),
              dayOf: (date) {
                final record = byDate[localDateString(date)];
                return RecordDay(
                  photoUrl: record?.bodyPhotoUrl,
                  cacheKey: record?.bodyPhotoCacheKey,
                  lines: [
                    if (record?.weight != null) '${record!.weight!.toStringAsFixed(1)}kg',
                    if (record?.memo != null && record!.memo!.trim().isNotEmpty) record.memo!,
                  ],
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: AddRecordBar(label: '눈바디 기록하기', onPressed: () => context.push('/write/body')),
    );
  }
}
