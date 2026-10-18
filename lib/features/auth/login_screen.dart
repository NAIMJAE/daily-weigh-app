import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_logo.dart';
import '../session/session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).login(_username.text, _password.text);
    } catch (error) {
      setState(() => _error = _friendly(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendly(Object error) {
    final text = error.toString();
    if (text.contains('Invalid login credentials')) {
      return '아이디 또는 비밀번호가 올바르지 않습니다.';
    }
    return '로그인에 실패했습니다.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            const _Brand(),
            const SizedBox(height: 28),
            if (!AppConfig.isConfigured)
              const _SetupBanner()
            else ...[
              TextField(
                controller: _username,
                decoration: const InputDecoration(labelText: '아이디'),
                textInputAction: TextInputAction.next,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                decoration: const InputDecoration(labelText: '비밀번호'),
                obscureText: true,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              FilledButton(onPressed: _loading ? null : _submit, child: Text(_loading ? '접속 중...' : '로그인하기')),
              const SizedBox(height: 16),
              TextButton(onPressed: () => context.go('/register'), child: const Text('계정이 없으면 회원가입')),
            ],
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppLogo(size: 64),
        const SizedBox(height: 12),
        const Text(AppConstants.appName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('아이디와 비밀번호로 들어옵니다.', style: TextStyle(color: AppColors.muted)),
      ],
    );
  }
}

class _SetupBanner extends StatelessWidget {
  const _SetupBanner();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Text(
        '앱 전용 Supabase URL과 anon 키를 assets/env/.env 에 넣으면 로그인이 켜집니다. 웹 프로젝트 키는 쓰지 마세요.',
        style: TextStyle(height: 1.45),
      ),
    );
  }
}
