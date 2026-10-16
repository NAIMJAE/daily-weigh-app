import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/daily_record.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/photo_calendar.dart';
import '../../shared/widgets/section_title.dart';
import '../../shared/widgets/status_chip.dart';
import '../home/home_controller.dart';
import '../record/record_sheet.dart';
import '../session/session_controller.dart';

class BodyScreen extends ConsumerStatefulWidget {
  const BodyScreen({super.key});

  @override
  ConsumerState<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends ConsumerState<BodyScreen> {
  List<DailyRecord> _records = [];
  var _loading = true;
  var _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = (await currentSession(ref)).userId;
    if (!mounted) return;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final records = await ref.read(recordRepositoryProvider).fetchForUser(userId);
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recordRevisionProvider, (previous, next) {
      if (previous != next) _load();
    });
    final userId = ref.watch(sessionProvider).value?.userId;
    final photoCount = _records.where((r) => r.bodyPhotoUrl != null).length;
    return Scaffold(
      appBar: const AppTopBar(title: '눈바디', icon: Icons.visibility_outlined, showGroup: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionTitle(
                        '겹쳐보기',
                        icon: Icons.layers_outlined,
                        trailing: StatusChip('눈바디 $photoCount장', tone: ChipTone.neutral, mono: true),
                      ),
                      const SizedBox(height: 6),
                      const Text('내 눈바디 두 장을 겹쳐 변화를 봅니다. 식단 사진은 넣지 않습니다.', style: AppText.label),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: userId == null ? null : () => context.push('/overlay/$userId'),
                        icon: const Icon(Icons.compare_outlined, size: 18),
                        label: const Text('겹쳐보기 열기'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                AppCard(
                  child: PhotoCalendar(
                    month: _month,
                    records: _records,
                    onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                    onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                    onDayTap: (date, record) {
                      if (localDateString(date) == localDateString()) {
                        showRecordSheet(context);
                        return;
                      }
                      if (record?.bodyPhotoUrl != null) {
                        showBodyPhoto(context, record!);
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
