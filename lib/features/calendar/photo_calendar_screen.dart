import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/daily_record.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/photo_calendar.dart';
import '../home/home_controller.dart';
import '../record/record_sheet.dart';
import '../session/session_controller.dart';

class PhotoCalendarScreen extends ConsumerStatefulWidget {
  const PhotoCalendarScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<PhotoCalendarScreen> createState() => _PhotoCalendarScreenState();
}

class _PhotoCalendarScreenState extends ConsumerState<PhotoCalendarScreen> {
  var _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<DailyRecord> _records = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final records = await ref.read(recordRepositoryProvider).fetchForUser(widget.userId);
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
    final mine = ref.watch(sessionProvider).value?.userId == widget.userId;
    return Scaffold(
      appBar: AppBar(title: const Text('사진 달력')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                AppCard(
                  child: PhotoCalendar(
                    month: _month,
                    records: _records,
                    onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                    onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                    onDayTap: (date, record) {
                      final today = localDateString();
                      if (mine && localDateString(date) == today) {
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
