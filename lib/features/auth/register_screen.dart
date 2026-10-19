import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../legal/terms_screen.dart';
import '../session/session_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _username = TextEditingController();
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  var _loading = false;
  var _agreed = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _nickname.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_agreed) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .register(username: _username.text, nickname: _nickname.text, password: _password.text);
    } catch (error) {
      setState(() => _error = _friendly(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendly(Object error) {
    final text = error.toString();
    if (text.contains('already')) return '이미 사용 중인 아이디입니다.';
    return text.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('계정만 먼저 만듭니다. 키와 체중은 다음 화면에서 입력합니다.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 20),
          TextField(
            controller: _username,
            decoration: const InputDecoration(labelText: '아이디', hintText: '영문, 숫자 3자 이상'),
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nickname,
            decoration: const InputDecoration(labelText: '닉네임'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            decoration: const InputDecoration(labelText: '비밀번호', hintText: '6자리 이상'),
            obscureText: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _agreed,
            onChanged: (value) => setState(() => _agreed = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('만 14세 이상이며, 이용약관과 개인정보처리방침에 동의합니다.'),
          ),
          PolicyLinks(onTerms: () => context.push('/terms')),
          const SizedBox(height: 8),
          FilledButton(onPressed: _loading || !_agreed ? null : _submit, child: Text(_loading ? '가입 처리 중...' : '다음')),
          TextButton(onPressed: () => context.go('/login'), child: const Text('이미 계정이 있으면 로그인')),
        ],
      ),
    );
  }
}
