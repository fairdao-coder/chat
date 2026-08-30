import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/brand.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();
  bool _isRegister = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _nickCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    if (user.isEmpty || pass.isEmpty) {
      _toast(context.tr('请输入用户名和密码'));
      return;
    }
    if (_isRegister && _nickCtrl.text.trim().isEmpty) {
      _toast(context.tr('请输入昵称'));
      return;
    }
    final auth = ref.read(authProvider.notifier);
    final ok = _isRegister
        ? await auth.register(user, pass, _nickCtrl.text.trim())
        : await auth.login(user, pass);
    if (!ok && mounted) {
      _toast(ref.read(authProvider).error ?? context.tr('操作失败'));
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).isLoading;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const BrandMark(size: 76),
                  const SizedBox(height: 18),
                  Text(
                    'FairChat',
                    style: textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('连接每一次对话'),
                    style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<bool>(
                            selected: {_isRegister},
                            onSelectionChanged: (s) =>
                                setState(() => _isRegister = s.first),
                            segments: [
                              ButtonSegment(
                                value: false,
                                label: Text(context.tr('登录')),
                                icon: const Icon(Icons.login),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(context.tr('注册')),
                                icon: const Icon(Icons.person_add_alt_1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _userCtrl,
                            decoration: InputDecoration(
                              labelText: context.tr('用户名'),
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passCtrl,
                            decoration: InputDecoration(
                              labelText: context.tr('密码'),
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                          ),
                          if (_isRegister) ...[
                            const SizedBox(height: 14),
                            TextField(
                              controller: _nickCtrl,
                              decoration: InputDecoration(
                                labelText: context.tr('昵称'),
                                prefixIcon: const Icon(Icons.badge_outlined),
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: loading ? null : _submit,
                            child: loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(_isRegister
                                    ? context.tr('注册并登录')
                                    : context.tr('登录')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => setState(() => _isRegister = !_isRegister),
                    child: Text(
                      _isRegister
                          ? context.tr('已有账号？去登录')
                          : context.tr('还没有账号？去注册'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
