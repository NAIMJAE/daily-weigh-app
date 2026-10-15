import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/local_date.dart';
import '../../data/models/daily_record.dart';
import '../../shared/widgets/photo_calendar.dart';
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
    final userId = ref.read(sessionProvider).value?.userId;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    final records = await ref.read(recordRepositoryProvider).fetchForUser(userId);
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recordRevisionProvider, (previous, next) {
      if (previous != next) _load();
    });
    final userId = ref.watch(sessionProvider).value?.userId;
    return Scaffold(
      appBar: AppBar(title: const Text('눈바디')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton(
                  onPressed: userId == null ? null : () => context.push('/overlay/$userId'),
                  child: const Text('겹쳐보기'),
                ),
                const SizedBox(height: 8),
                const Text(
                  '내 눈바디만 겹칩니다. 식단 사진은 넣지 않습니다.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                PhotoCalendar(
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
              ],
            ),
    );
  }
}
