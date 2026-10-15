import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../session/session_controller.dart';

class BodyEditScreen extends ConsumerStatefulWidget {
  const BodyEditScreen({super.key});

  @override
  ConsumerState<BodyEditScreen> createState() => _BodyEditScreenState();
}

class _BodyEditScreenState extends ConsumerState<BodyEditScreen> {
  final _height = TextEditingController();
  final _start = TextEditingController();
  final _target = TextEditingController();
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(sessionProvider).value?.profile;
    if (profile?.height != null) _height.text = '${profile!.height}';
    if (profile?.startWeight != null) _start.text = '${profile!.startWeight}';
    if (profile?.targetWeight != null) _target.text = '${profile!.targetWeight}';
  }

  @override
  void dispose() {
    _height.dispose();
    _start.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final height = double.tryParse(_height.text.trim());
    final start = double.tryParse(_start.text.trim());
    final target = double.tryParse(_target.text.trim());
    if (height == null || start == null || target == null) {
      setState(() => _error = '키, 시작 체중, 목표 체중은 비울 수 없습니다.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await ref.read(sessionProvider.notifier).updateBody(
      height: height,
      startWeight: start,
      targetWeight: target,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('신체 정보 수정')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('키와 체중은 차트와 BMI에 씁니다. 비울 수 없습니다.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          TextField(
            controller: _height,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '키 (cm)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _start,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '시작 체중 (kg)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '목표 체중 (kg)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '저장 중...' : '저장'),
          ),
        ],
      ),
    );
  }
}
