import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/auth_provider.dart';
import '../api/api_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().login(_userCtrl.text.trim(), _passCtrl.text);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '網絡錯誤：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 760;
    final card = Container(
      width: 380,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 28, offset: Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.admin_panel_settings, size: 34, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text('聊天後臺管理系統',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
          const SizedBox(height: 4),
          const Text('Chat Admin Console', style: TextStyle(color: AppTheme.textSub)),
          const SizedBox(height: 28),
          TextField(
            controller: _userCtrl,
            decoration: const InputDecoration(labelText: '管理員賬號', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: '密碼', prefixIcon: Icon(Icons.lock_outline)),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ),
          if (_error != null) const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('登 錄'),
            ),
          ),
          const SizedBox(height: 16),
          const Text('默認賬號 admin / admin123', style: TextStyle(color: AppTheme.textSub, fontSize: 12)),
        ],
      ),
    );

    if (!isWide) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: card,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.admin_panel_settings, size: 56, color: Colors.white),
                      const SizedBox(height: 20),
                      const Text('歡迎回來',
                          style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text('統一管理用戶、角色、發現頁與系統功能配置。',
                          style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _FeatureChip(Icons.people, '用戶管理'),
                          _FeatureChip(Icons.badge, '角色權限'),
                          _FeatureChip(Icons.explore, '發現頁'),
                          _FeatureChip(Icons.tune, '系統配置'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              color: AppTheme.bg,
              child: Center(
                child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: card),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
