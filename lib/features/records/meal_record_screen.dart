import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/local_date.dart';
import '../../data/models/meal_entry.dart';
import '../../shared/widgets/app_card.dart';
import 'record_browser.dart';
import 'record_type.dart';
import 'records_controller.dart';

class MealRecordScreen extends ConsumerStatefulWidget {
  const MealRecordScreen({super.key});

  @override
  ConsumerState<MealRecordScreen> createState() => _MealRecordScreenState();
}

class _MealRecordScreenState extends ConsumerState<MealRecordScreen> {
  var _slot = MealSlot.breakfast;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(myMealEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(RecordType.meal.title)),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(friendlyError(error))),
        data: (byKey) => ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            RecordBrowser(
              emptyIcon: RecordType.meal.icon,
              countLabel: '${_slot.label} 기록',
              // 끼니 탭은 월·주·일 모두에 걸린다.
              filter: PillTabs<MealSlot>(
                options: [for (final slot in MealSlot.values) (slot, slot.label, slot.icon)],
                value: _slot,
                onChanged: (slot) => setState(() => _slot = slot),
              ),
              dayOf: (date) {
                final entry = byKey[mealKey(localDateString(date), _slot)];
                final description = entry?.description?.trim() ?? '';
                final tags = entry?.tagSummary ?? '';
                return RecordDay(
                  photoUrl: entry?.photoUrl,
                  cacheKey: entry?.photoCacheKey,
                  lines: [
                    if (description.isNotEmpty) description,
                    if (tags.isNotEmpty) tags,
                  ],
                );
              },
              onEditDay: (date) => context.push('/write/meal?date=${localDateString(date)}&slot=${_slot.dbValue}'),
              dayFooter: (date) => _DayMeals(
                date: localDateString(date),
                entries: byKey,
                selected: _slot,
                onSelect: (slot) => setState(() => _slot = slot),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AddRecordBar(label: '식단 기록하기', onPressed: () => context.push('/write/meal')),
    );
  }
}

extension on MealSlot {
  IconData get icon => switch (this) {
    MealSlot.breakfast => Icons.wb_twilight,
    MealSlot.lunch => Icons.light_mode_outlined,
    MealSlot.dinner => Icons.nights_stay_outlined,
    MealSlot.snack => Icons.cookie_outlined,
  };
}

/// 일 보기 아래: 그 날 네 끼니를 한 줄로 보여 주고, 누르면 그 끼니로 바꾼다.
class _DayMeals extends StatelessWidget {
  const _DayMeals({required this.date, required this.entries, required this.selected, required this.onSelect});

  final String date;
  final Map<String, MealEntry> entries;
  final MealSlot selected;
  final ValueChanged<MealSlot> onSelect;

  @override
  Widget build(BuildContext context) {
    final count = MealSlot.values.where((slot) => entries.containsKey(mealKey(date, slot))).length;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('이 날의 식단', style: AppText.title)),
              Text('$count / 4끼', style: AppText.label),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final slot in MealSlot.values) ...[
                if (slot != MealSlot.values.first) const SizedBox(width: AppSpacing.gap),
                Expanded(
                  child: _MealTile(
                    slot: slot,
                    entry: entries[mealKey(date, slot)],
                    selected: slot == selected,
                    onTap: () => onSelect(slot),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  const _MealTile({required this.slot, required this.entry, required this.selected, required this.onTap});

  final MealSlot slot;
  final MealEntry? entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.tile);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: radius,
                border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: selected ? 2 : 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.tile - 1),
                child: entry?.photoUrl != null
                    ? CachedNetworkImage(imageUrl: entry!.photoUrl!, cacheKey: entry!.photoCacheKey, fit: BoxFit.cover)
                    : Icon(
                        entry == null ? slot.icon : Icons.notes,
                        size: 20,
                        color: entry == null ? AppColors.line : AppColors.faint,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            slot.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.accent : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
