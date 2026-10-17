import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';
import '../../data/models/workout_routine.dart';
import '../records/records_controller.dart';
import '../records/write/write_parts.dart';
import 'workout_controller.dart';

/// 루틴 만들기 첫 화면: 템플릿을 고르면 내 루틴으로 복사하고 편집 화면으로 간다.
class TemplatePickerScreen extends ConsumerStatefulWidget {
  const TemplatePickerScreen({super.key});

  @override
  ConsumerState<TemplatePickerScreen> createState() => _TemplatePickerScreenState();
}

class _TemplatePickerScreenState extends ConsumerState<TemplatePickerScreen> {
  String? _selectedId;
  var _withCardio = false;
  var _saving = false;

  Future<void> _create() async {
    final id = _selectedId;
    if (id == null) return;
    setState(() => _saving = true);
    try {
      final newId = await ref.read(routineRepositoryProvider).copyRoutine(id, withCardio: _withCardio);
      refreshRoutines(ref);
      if (mounted) context.pushReplacement('/workout/routines/$newId?fresh=1');
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(routineTemplatesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('루틴 만들기')),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(friendlyError(error))),
        data: (list) => ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const Text('템플릿을 고르면 내 루틴으로 만들어져요. 다음 화면에서 종목과 세트를 고칠 수 있어요.', style: AppText.label),
            const SizedBox(height: AppSpacing.section),
            for (final template in list) ...[
              _TemplateCard(
                template: template,
                selected: template.id == _selectedId,
                onTap: () => setState(() => _selectedId = template.id),
              ),
              const SizedBox(height: AppSpacing.section),
            ],
            Card(
              child: SwitchListTile(
                value: _withCardio,
                onChanged: (value) => setState(() => _withCardio = value),
                title: const Text('끝에 유산소 넣기', style: AppText.title),
                subtitle: const Text('날마다 마지막에 러닝머신 20분이 붙어요.', style: AppText.label),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SaveBar(
        label: _selectedId == null ? '템플릿을 골라 주세요' : '이 템플릿으로 만들기',
        saving: _saving,
        onPressed: _selectedId == null ? null : _create,
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.selected, required this.onTap});

  final Routine template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: selected ? AppColors.accent : AppColors.line, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? AppColors.accent : AppColors.faint,
                  ),
                  const SizedBox(width: 8),
                  Text(template.name, style: AppText.headline),
                  const SizedBox(width: 8),
                  Text('${template.days.length}일 순환', style: AppText.label),
                ],
              ),
              if (template.description != null) ...[
                const SizedBox(height: 4),
                Text(template.description!, style: AppText.label),
              ],
              // 고른 템플릿만 날마다 종목을 펼쳐 보여 준다.
              if (selected) ...[
                const SizedBox(height: 12),
                for (final day in template.days) ...[
                  _DayPreview(day: day),
                  const SizedBox(height: AppSpacing.gap),
                ],
              ] else ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: AppSpacing.chip,
                  runSpacing: AppSpacing.chip,
                  children: [for (final day in template.days) _DayChip(day.name)],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.mutedBg,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _DayPreview extends StatelessWidget {
  const _DayPreview({required this.day});

  final RoutineDay day;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(day.name, style: AppText.title),
          const SizedBox(height: 6),
          for (final item in day.items)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Expanded(child: Text(item.exercise.name, style: const TextStyle(fontSize: 13))),
                  NumText(item.targetLabel, style: AppText.number(size: 12, weight: FontWeight.w500, color: AppColors.muted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
