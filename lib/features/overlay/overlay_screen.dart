import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/error_message.dart';
import '../../data/models/daily_record.dart';
import '../home/home_controller.dart';

class OverlayScreen extends ConsumerStatefulWidget {
  const OverlayScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends ConsumerState<OverlayScreen> {
  List<DailyRecord> _photos = [];
  DailyRecord? _a;
  DailyRecord? _b;
  var _opacity = 0.5;
  var _blink = false;
  var _showB = true;
  var _loading = true;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final List<DailyRecord> records;
    try {
      records = await ref.read(recordRepositoryProvider).fetchForUser(widget.userId);
    } catch (error) {
      _failed(error);
      return;
    }
    if (!mounted) return;
    final photos = records.where((r) => r.bodyPhotoUrl != null).toList();
    setState(() {
      _photos = photos;
      _a = photos.length > 1 ? photos.last : (photos.isEmpty ? null : photos.first);
      _b = photos.isEmpty ? null : photos.first;
      _loading = false;
    });
  }

  void _failed(Object error) {
    if (!mounted) return;
    setState(() => _loading = false);
    showErrorSnack(context, error);
  }

  void _toggleBlink(bool value) {
    _blinkTimer?.cancel();
    setState(() {
      _blink = value;
      _showB = true;
    });
    if (value) {
      _blinkTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
        if (mounted) setState(() => _showB = !_showB);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recordRevisionProvider, (previous, next) {
      if (previous != next) _load();
    });
    return Scaffold(
      appBar: AppBar(title: const Text('겹쳐보기')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _photos.length < 2
          ? const Center(child: Text('눈바디가 두 장 이상이면 겹쳐볼 수 있습니다.'))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_a?.bodyPhotoUrl != null)
                          CachedNetworkImage(
                            imageUrl: _a!.bodyPhotoUrl!,
                            cacheKey: _a!.bodyPhotoCacheKey,
                            fit: BoxFit.cover,
                          ),
                        if (_b?.bodyPhotoUrl != null)
                          Opacity(
                            opacity: _blink ? (_showB ? 1 : 0) : _opacity,
                            child: CachedNetworkImage(
                              imageUrl: _b!.bodyPhotoUrl!,
                              cacheKey: _b!.bodyPhotoCacheKey,
                              fit: BoxFit.cover,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${_a?.recordDate ?? ''}  ↔  ${_b?.recordDate ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Slider(value: _opacity, onChanged: _blink ? null : (value) => setState(() => _opacity = value)),
                SwitchListTile(title: const Text('깜빡이며 비교'), value: _blink, onChanged: _toggleBlink),
                FilledButton(
                  onPressed: () => setState(() {
                    final temp = _a;
                    _a = _b;
                    _b = temp;
                  }),
                  child: const Text('사진 바꾸기'),
                ),
                const SizedBox(height: 16),
                const Text('눈바디만 고릅니다. 식단 사진은 넣지 않습니다.', style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final photo in _photos)
                      ActionChip(
                        label: Text(photo.recordDate),
                        onPressed: () {
                          setState(() {
                            if (_a?.id == photo.id) {
                              _a = null;
                            } else if (_b?.id == photo.id) {
                              _b = null;
                            } else if (_a == null) {
                              _a = photo;
                            } else {
                              _b = photo;
                            }
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
