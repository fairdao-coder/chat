import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/api_client.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/core_providers.dart';
import '../widgets/app_avatar.dart';

/// 「我的二維碼」頁面：將當前用戶的名片編碼為 QR，供他人掃描後發起好友請求。
/// 名片內容格式：fairchat://user/<id>（由後端 /api/users/me/card 給出）。
class MyQrPage extends ConsumerStatefulWidget {
  const MyQrPage({super.key});

  @override
  ConsumerState<MyQrPage> createState() => _MyQrPageState();
}

class _MyQrPageState extends ConsumerState<MyQrPage> {
  String? _card;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiProvider);
    try {
      final data = await api.getMyCard();
      if (mounted) setState(() => _card = data['card'] as String?);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = context.tr('网络错误，请重试'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('我的二维码'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (user != null) ...[
                AppAvatar(
                  imageUrl: user.avatarUrl,
                  name: user.nickName,
                  size: 72,
                ),
                const SizedBox(height: 14),
                Text(
                  user.nickName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '@${user.userName}',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
              ],
              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildQr(cs),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr('扫码添加我为好友'),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQr(ColorScheme cs) {
    if (_loading) {
      return const SizedBox(
        width: 220,
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _card == null) {
      return SizedBox(
        width: 220,
        height: 220,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 36),
              const SizedBox(height: 8),
              Text(_error ?? context.tr('加载失败')),
            ],
          ),
        ),
      );
    }
    return QrImageView(
      data: _card!,
      version: QrVersions.auto,
      size: 220,
      backgroundColor: cs.surfaceContainerHighest,
      eyeStyle: QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: cs.onSurface,
      ),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: cs.onSurface,
      ),
    );
  }
}
