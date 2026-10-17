import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/local_date.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/photo_viewer.dart';

enum RecordPeriod { month, week, day }

/// 운동처럼 사진 없이 보이는 표시: O(함), X(안 함), 휴(휴식 데이).
enum DayMark { done, missed, rest }

/// 기록 화면에서 하루 칸에 보여 줄 내용. 눈바디·식단·운동이 같은 틀을 쓴다.
class RecordDay {
  const RecordDay({this.photoUrl, this.cacheKey, this.mark, this.lines = const []});

  final String? photoUrl;
  final String? cacheKey;

  /// null이면 표시하지 않는다.
  final DayMark? mark;

  /// 사진 오른쪽(주)이나 아래(일)에 보이는 설명. 첫 줄은 굵게 보인다.
  final List<String> lines;

  /// 기간 요약에서 기록한 날로 센다. X와 휴인 날은 설명이 있어도 세지 않는다.
  bool get counts => photoUrl != null || (mark == null ? lines.isNotEmpty : mark == DayMark.done);
}

Color _markFill(DayMark? mark) => switch (mark) {
  DayMark.done => AppColors.chipFill,
  DayMark.rest => AppColors.mutedBg,
  _ => AppColors.canvas,
};

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

String _weekday(DateTime date) => _weekdayLabels[date.weekday - DateTime.monday];

String _monthDay(DateTime date) => '${date.month}.${date.day.toString().padLeft(2, '0')}';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// [월 / 주 / 일] 전환과 기간 넘기기. 월 달력이나 주 카드를 누르면 그 날의 일 보기로 간다.
class RecordBrowser extends StatefulWidget {
  const RecordBrowser({
    super.key,
    required this.dayOf,
    required this.emptyIcon,
    required this.countLabel,
    this.filter,
    this.dayFooter,
    this.onEditDay,
  });

  final RecordDay Function(DateTime date) dayOf;

  /// 사진도 O/X도 없는 칸에 보이는 아이콘.
  final IconData emptyIcon;

  /// 기간 요약 문구 (예: '기록한 날', '운동한 날').
  final String countLabel;

  /// 기간 전환 아래에 붙는 보조 탭 (식단의 끼니 탭).
  final Widget? filter;

  /// 일 보기 카드 아래에 붙는 내용 (식단의 다른 끼니).
  final Widget Function(DateTime date)? dayFooter;

  /// 일 보기에서 그 날을 기록하거나 고친다. 오늘과 어제에만 버튼이 보인다.
  final ValueChanged<DateTime>? onEditDay;

  @override
  State<RecordBrowser> createState() => _RecordBrowserState();
}

class _RecordBrowserState extends State<RecordBrowser> {
  var _period = RecordPeriod.month;
  var _focus = _today();

  DateTime _startOf(DateTime date) => switch (_period) {
    RecordPeriod.month => startOfMonth(date),
    RecordPeriod.week => startOfWeekMonday(date),
    RecordPeriod.day => date,
  };

  DateTime _shift(int step) => switch (_period) {
    RecordPeriod.month => DateTime(_focus.year, _focus.month + step, 1),
    RecordPeriod.week => DateTime(_focus.year, _focus.month, _focus.day + 7 * step),
    RecordPeriod.day => DateTime(_focus.year, _focus.month, _focus.day + step),
  };

  // 오늘이 든 기간 다음으로는 넘기지 않는다.
  bool get _canNext => !_startOf(_shift(1)).isAfter(_today());

  String get _label {
    final start = _startOf(_focus);
    return switch (_period) {
      RecordPeriod.month => '${start.year}.${start.month.toString().padLeft(2, '0')}',
      RecordPeriod.week => '${_monthDay(start)} – ${_monthDay(DateTime(start.year, start.month, start.day + 6))}',
      RecordPeriod.day => '${start.year}.${_monthDay(start)} (${_weekday(start)})',
    };
  }

  /// 기간 안에서 오늘까지 지난 날들.
  List<DateTime> _elapsedDays(DateTime start) {
    final length = switch (_period) {
      RecordPeriod.month => DateUtils.getDaysInMonth(start.year, start.month),
      RecordPeriod.week => 7,
      RecordPeriod.day => 1,
    };
    final today = _today();
    return [
      for (var i = 0; i < length; i++)
        if (!DateTime(start.year, start.month, start.day + i).isAfter(today))
          DateTime(start.year, start.month, start.day + i),
    ];
  }

  void _openDay(DateTime date) {
    setState(() {
      _period = RecordPeriod.day;
      _focus = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = _startOf(_focus);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PeriodTabs(value: _period, onChanged: (value) => setState(() => _period = value)),
        if (widget.filter != null) ...[const SizedBox(height: AppSpacing.gap), widget.filter!],
        const SizedBox(height: AppSpacing.section),
        AppCard(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, AppSpacing.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '이전',
                    onPressed: () => setState(() => _focus = _shift(-1)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: NumText(_label, textAlign: TextAlign.center, style: AppText.number(size: 15)),
                  ),
                  IconButton(
                    tooltip: '다음',
                    onPressed: _canNext ? () => setState(() => _focus = _shift(1)) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: switch (_period) {
                  RecordPeriod.month => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Summary(label: widget.countLabel, days: _elapsedDays(start), dayOf: widget.dayOf),
                      const SizedBox(height: 14),
                      _MonthGrid(month: start, dayOf: widget.dayOf, onDayTap: _openDay),
                    ],
                  ),
                  RecordPeriod.week => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Summary(label: widget.countLabel, days: _elapsedDays(start), dayOf: widget.dayOf),
                      const SizedBox(height: 12),
                      _WeekStrip(start: start, dayOf: widget.dayOf, onDayTap: _openDay),
                    ],
                  ),
                  RecordPeriod.day => _WeekStrip(
                    start: startOfWeekMonday(start),
                    selected: start,
                    dayOf: widget.dayOf,
                    onDayTap: _openDay,
                  ),
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        switch (_period) {
          RecordPeriod.month => const SizedBox.shrink(),
          RecordPeriod.week => _WeekList(
            start: start,
            dayOf: widget.dayOf,
            emptyIcon: widget.emptyIcon,
            onDayTap: _openDay,
          ),
          RecordPeriod.day => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DayDetail(day: widget.dayOf(start), emptyIcon: widget.emptyIcon, title: _label),
              if (widget.onEditDay != null && isEditableDay(start)) ...[
                const SizedBox(height: AppSpacing.gap),
                OutlinedButton.icon(
                  onPressed: () => widget.onEditDay!(start),
                  icon: Icon(widget.dayOf(start).counts ? Icons.edit_outlined : Icons.add, size: 18),
                  label: Text(widget.dayOf(start).counts ? '이 날 기록 고치기' : '이 날 기록하기'),
                ),
              ],
              if (widget.dayFooter != null) ...[const SizedBox(height: AppSpacing.section), widget.dayFooter!(start)],
            ],
          ),
        },
      ],
    );
  }
}

/// 화면 폭을 다 쓰는 [월 / 주 / 일] 전환.
class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.value, required this.onChanged});

  final RecordPeriod value;
  final ValueChanged<RecordPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return PillTabs<RecordPeriod>(
      options: const [(RecordPeriod.month, '월', null), (RecordPeriod.week, '주', null), (RecordPeriod.day, '일', null)],
      value: value,
      onChanged: onChanged,
    );
  }
}

/// 같은 폭으로 나눈 전환 탭. 기간 전환과 식단 끼니 탭이 쓴다.
class PillTabs<T> extends StatelessWidget {
  const PillTabs({super.key, required this.options, required this.value, required this.onChanged});

  final List<(T, String, IconData?)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.mutedBg,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (final (option, label, icon) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: option == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    constraints: const BoxConstraints(minHeight: 36),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: option == value ? AppColors.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: option == value
                          ? const [BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1))]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 15, color: option == value ? AppColors.accent : AppColors.faint),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: option == value ? FontWeight.w700 : FontWeight.w500,
                            color: option == value ? AppColors.ink : AppColors.faint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 기간 요약: '기록한 날 9 / 17일' 과 진행 막대.
class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.days, required this.dayOf});

  final String label;
  final List<DateTime> days;
  final RecordDay Function(DateTime date) dayOf;

  @override
  Widget build(BuildContext context) {
    final count = days.where((date) => dayOf(date).counts).length;
    final ratio = days.isEmpty ? 0.0 : count / days.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(label, style: AppText.label),
            const SizedBox(width: 6),
            NumText('$count', style: AppText.number(size: 20, color: AppColors.accent)),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: NumText('/ ${days.length}일', style: AppText.number(size: 12, weight: FontWeight.w500, color: AppColors.faint)),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: NumText('${(ratio * 100).round()}%', style: AppText.number(size: 12, color: AppColors.muted)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            color: AppColors.accent,
            backgroundColor: AppColors.mutedBg,
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.dayOf, required this.onDayTap});

  final DateTime month;
  final RecordDay Function(DateTime date) dayOf;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    // 주는 월요일에 시작한다 (통계의 주간과 같은 기준).
    final leading = month.weekday - DateTime.monday;
    final today = _today();
    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(label, textAlign: TextAlign.center, style: AppText.caption),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leading + days,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
          ),
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();
            final date = DateTime(month.year, month.month, index - leading + 1);
            return _MonthCell(
              date: date,
              day: dayOf(date),
              isToday: date == today,
              isFuture: date.isAfter(today),
              onTap: () => onDayTap(date),
            );
          },
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.date,
    required this.day,
    required this.isToday,
    required this.isFuture,
    required this.onTap,
  });

  final DateTime date;
  final RecordDay day;
  final bool isToday;
  final bool isFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.chip);
    final filled = day.mark == DayMark.done || day.mark == DayMark.rest;
    final dayNumber = Text(
      '${date.day}',
      style: AppText.number(
        size: 11,
        weight: isToday ? FontWeight.w800 : FontWeight.w500,
        color: isToday
            ? AppColors.accent
            : isFuture
            ? AppColors.line
            : AppColors.muted,
      ),
    );
    final Widget content;
    if (day.photoUrl != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.chip - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: day.photoUrl!, cacheKey: day.cacheKey, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Color(0x66000000), Color(0x00000000)],
                ),
              ),
            ),
            Positioned(
              left: 4,
              top: 2,
              child: Text('${date.day}', style: AppText.number(size: 10, color: Colors.white)),
            ),
          ],
        ),
      );
    } else if (day.mark != null) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [dayNumber, const SizedBox(height: 1), _Mark(mark: day.mark!, size: 13)],
      );
    } else {
      content = Center(child: dayNumber);
    }
    return Material(
      color: filled ? _markFill(day.mark) : (isFuture ? AppColors.card : AppColors.canvas),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: isToday ? AppColors.accent : (filled ? _markFill(day.mark) : AppColors.line),
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: InkWell(customBorder: RoundedRectangleBorder(borderRadius: radius), onTap: onTap, child: content),
    );
  }
}

/// 한 주를 동그라미 7개로 보여 준다. 주 보기에서는 요약, 일 보기에서는 날짜 고르기다.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.start, required this.dayOf, required this.onDayTap, this.selected});

  final DateTime start;
  final DateTime? selected;
  final RecordDay Function(DateTime date) dayOf;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final today = _today();
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(
              builder: (context) {
                final date = DateTime(start.year, start.month, start.day + i);
                final future = date.isAfter(today);
                final counts = !future && dayOf(date).counts;
                final isSelected = date == selected;
                return InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  onTap: future ? null : () => onDayTap(date),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Text(
                          _weekdayLabels[i],
                          style: AppText.caption.copyWith(
                            color: date == today ? AppColors.accent : AppColors.faint,
                            fontWeight: date == today ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.ink
                                : counts
                                ? AppColors.accent
                                : AppColors.mutedBg,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${date.day}',
                            style: AppText.number(
                              size: 12,
                              color: isSelected || counts
                                  ? Colors.white
                                  : future
                                  ? AppColors.line
                                  : AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _WeekList extends StatelessWidget {
  const _WeekList({required this.start, required this.dayOf, required this.emptyIcon, required this.onDayTap});

  final DateTime start;
  final RecordDay Function(DateTime date) dayOf;
  final IconData emptyIcon;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final today = _today();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.gap),
          _WeekCard(
            date: DateTime(start.year, start.month, start.day + i),
            today: today,
            dayOf: dayOf,
            emptyIcon: emptyIcon,
            onTap: onDayTap,
          ),
        ],
      ],
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.date,
    required this.today,
    required this.dayOf,
    required this.emptyIcon,
    required this.onTap,
  });

  final DateTime date;
  final DateTime today;
  final RecordDay Function(DateTime date) dayOf;
  final IconData emptyIcon;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final day = dayOf(date);
    final isToday = date == today;
    final future = date.isAfter(today);
    return Opacity(
      opacity: future ? 0.5 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: isToday ? AppColors.accent : AppColors.line, width: isToday ? 1.5 : 1),
        ),
        child: InkWell(
          onTap: () => onTap(date),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _Thumb(day: day, emptyIcon: emptyIcon, size: 72),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _weekday(date),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isToday ? AppColors.accent : AppColors.ink,
                            ),
                          ),
                          const SizedBox(width: 6),
                          NumText(_monthDay(date), style: AppText.number(size: 11, weight: FontWeight.w500, color: AppColors.faint)),
                          if (isToday) ...[
                            const SizedBox(width: 6),
                            const _TodayBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (day.lines.isEmpty)
                        Text(future ? '아직이에요' : '기록 없음', style: AppText.caption)
                      else ...[
                        Text(
                          day.lines.first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                        for (final line in day.lines.skip(1))
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              line,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.day, required this.emptyIcon, required this.title});

  final RecordDay day;
  final IconData emptyIcon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (day.photoUrl != null)
            GestureDetector(
              onTap: () => showPhotoViewer(context, url: day.photoUrl!, cacheKey: day.cacheKey, title: title),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: AppColors.ink,
                        child: CachedNetworkImage(imageUrl: day.photoUrl!, cacheKey: day.cacheKey, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                          ),
                          child: const Icon(Icons.zoom_out_map, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: _markFill(day.mark),
                borderRadius: BorderRadius.circular(AppRadius.tile),
                border: Border.all(color: day.mark == null ? AppColors.line : _markFill(day.mark)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (day.mark == null)
                    Icon(emptyIcon, size: 36, color: AppColors.line)
                  else
                    _Mark(mark: day.mark!, size: 64),
                  const SizedBox(height: 8),
                  Text(
                    switch (day.mark) {
                      DayMark.done => '운동 완료',
                      DayMark.rest => '휴식 데이',
                      _ => day.lines.isEmpty ? '이 날은 기록이 없어요' : '사진 없이 남긴 기록',
                    },
                    style: AppText.label,
                  ),
                ],
              ),
            ),
          if (day.lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day.lines.first, style: AppText.headline),
                  for (final line in day.lines.skip(1)) ...[
                    const SizedBox(height: 4),
                    Text(line, style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 주 카드 왼쪽 칸: 사진, O/X, 빈 칸 아이콘 중 하나.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.day, required this.emptyIcon, required this.size});

  final RecordDay day;
  final IconData emptyIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.tile);
    if (day.photoUrl != null) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox.square(
          dimension: size,
          child: CachedNetworkImage(imageUrl: day.photoUrl!, cacheKey: day.cacheKey, fit: BoxFit.cover),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _markFill(day.mark),
        borderRadius: radius,
        border: Border.all(color: day.mark == null || day.mark == DayMark.missed ? AppColors.line : _markFill(day.mark)),
      ),
      child: Center(
        child: day.mark == null
            ? Icon(emptyIcon, size: 24, color: AppColors.line)
            : _Mark(mark: day.mark!, size: 30),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.mark, required this.size});

  final DayMark mark;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: switch (mark) {
        DayMark.done => '함',
        DayMark.missed => '안 함',
        DayMark.rest => '휴식',
      },
      child: ExcludeSemantics(
        child: switch (mark) {
          DayMark.done => Icon(Icons.circle_outlined, size: size, color: AppColors.accent),
          DayMark.missed => Icon(Icons.close, size: size, color: AppColors.faint),
          // 글자 '휴'를 아이콘과 같은 크기로 맞춘다.
          DayMark.rest => SizedBox.square(
            dimension: size,
            child: Center(
              child: Text(
                '휴',
                style: TextStyle(fontSize: size * 0.72, height: 1, fontWeight: FontWeight.w800, color: AppColors.muted),
              ),
            ),
          ),
        },
      ),
    );
  }
}

class _TodayBadge extends StatelessWidget {
  const _TodayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)),
      child: const Text(
        '오늘',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

/// 기록 화면 아래의 추가 버튼. [onPressed]가 없으면 누를 수 없는 자리로 둔다.
class AddRecordBar extends StatelessWidget {
  const AddRecordBar({super.key, this.onPressed, this.label = '기록 추가 (준비 중)'});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 10),
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add, size: 18),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}
