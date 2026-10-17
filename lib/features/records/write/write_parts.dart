import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/local_date.dart';
import '../../../data/repositories/record_repository.dart';
import '../../home/home_controller.dart';
import '../../session/session_controller.dart';
import '../record_browser.dart';

/// 기록을 저장한 뒤 화면들이 다시 읽게 한다. 지갑과 스트릭은 세션을 다시 읽어 맞춘다.
Future<void> afterRecordSaved(WidgetRef ref) async {
  ref.read(recordRevisionProvider.notifier).bump();
  ref.invalidate(homeSnapshotProvider);
  await ref.read(sessionProvider.notifier).reload();
}

DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime yesterday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - 1);
}

/// 'YYYY-MM-DD' 를 받아 오늘이나 어제면 그 날, 아니면 오늘을 돌려준다.
DateTime editableDayFrom(String? raw) {
  if (raw == null) return today();
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || !isEditableDay(parsed)) return today();
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// 카메라 또는 갤러리를 고르게 하고 고른 사진의 경로를 돌려준다.
Future<String?> pickPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    // 화면 폭 시트이므로 글자를 페이지 여백 안에 둔다.
    builder: (context) => ListTileTheme.merge(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return null;
  return pickImagePath(source);
}

/// [어제 / 오늘] 고르기. 기록은 이 이틀만 쓰고 고칠 수 있다.
class DayChoice extends StatelessWidget {
  const DayChoice({super.key, required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  String _label(String prefix, DateTime date) => '$prefix ${date.month}.${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final before = yesterday();
    final now = today();
    return PillTabs<DateTime>(
      options: [(before, _label('어제', before), null), (now, _label('오늘', now), null)],
      value: value,
      onChanged: onChanged,
    );
  }
}

/// 사진 한 장 칸. 새로 고른 파일, 이미 올린 사진, 빈 칸 중 하나를 보여 준다.
/// [ghostUrl]이 있으면 지난 사진을 반투명하게 겹쳐 자세와 거리를 맞춰 볼 수 있다.
class PhotoField extends StatelessWidget {
  const PhotoField({
    super.key,
    required this.aspectRatio,
    required this.emptyLabel,
    required this.onPick,
    required this.onRemove,
    this.pickedPath,
    this.url,
    this.cacheKey,
    this.ghostUrl,
    this.ghostCacheKey,
    this.ghostOpacity = 0,
  });

  final double aspectRatio;
  final String emptyLabel;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final String? pickedPath;
  final String? url;
  final String? cacheKey;
  final String? ghostUrl;
  final String? ghostCacheKey;
  final double ghostOpacity;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.tile);
    final hasPhoto = pickedPath != null || url != null;
    // 빈 칸은 사진 비율 대신 낮게 두어 아래 입력 칸이 한 화면에 보이게 한다.
    if (!hasPhoto) {
      return SizedBox(
        height: 180,
        child: Material(
          color: AppColors.canvas,
          shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.line)),
          child: InkWell(
            customBorder: RoundedRectangleBorder(borderRadius: radius),
            onTap: onPick,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: AppColors.chipFill, shape: BoxShape.circle),
                  child: const Icon(Icons.add_a_photo_outlined, color: AppColors.accent),
                ),
                const SizedBox(height: 10),
                Text(emptyLabel, style: AppText.title),
                const SizedBox(height: 2),
                const Text('카메라 또는 갤러리', style: AppText.caption),
              ],
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppColors.ink,
              child: pickedPath != null
                  ? Image.file(File(pickedPath!), fit: BoxFit.cover)
                  : CachedNetworkImage(imageUrl: url!, cacheKey: cacheKey, fit: BoxFit.cover),
            ),
            if (ghostUrl != null && ghostOpacity > 0)
              IgnorePointer(
                child: Opacity(
                  opacity: ghostOpacity,
                  child: CachedNetworkImage(imageUrl: ghostUrl!, cacheKey: ghostCacheKey, fit: BoxFit.cover),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  _OverlayButton(icon: Icons.refresh, label: '다시 고르기', onTap: onPick),
                  const SizedBox(width: 6),
                  _OverlayButton(icon: Icons.delete_outline, label: '빼기', danger: true, onTap: onRemove),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: danger ? const Color(0xFFFF6568) : Colors.white),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 아래에 붙는 저장 버튼. 저장 중에는 누를 수 없다.
class SaveBar extends StatelessWidget {
  const SaveBar({super.key, required this.label, required this.onPressed, this.saving = false, this.note});

  final String label;
  final VoidCallback? onPressed;
  final bool saving;

  /// 버튼 위의 작은 안내 (예: 식단 점수는 하루 한 번).
  final String? note;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (note != null) ...[
                Text(note!, textAlign: TextAlign.center, style: AppText.caption),
                const SizedBox(height: 6),
              ],
              FilledButton(onPressed: saving ? null : onPressed, child: Text(saving ? '저장 중...' : label)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 제목이 있는 입력 묶음.
class WriteSection extends StatelessWidget {
  const WriteSection({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: AppText.title)),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.gap),
        child,
      ],
    );
  }
}
