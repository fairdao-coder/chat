import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_avatar.dart';

/// 「分享我的名片」頁面：將當前用戶的「發起對話」鏈接編碼為 QR，
/// 並提供可複製的 Web 分享鏈接，供他人打開後直接進入與你的私聊。
///
/// 鏈接格式：
///   - App 深鏈：fairchat://chat/<id>（手機端掃碼 / 點擊直接跳轉）
///   - Web 分享：<origin>/#/?chat=<id>（瀏覽器打開，自動識別並跳轉）
class ShareProfilePage extends ConsumerStatefulWidget {
  const ShareProfilePage({super.key});

  @override
  ConsumerState<ShareProfilePage> createState() => _ShareProfilePageState();
}

class _ShareProfilePageState extends ConsumerState<ShareProfilePage> {
  late final String _deepLink;
  late final String _webLink;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    final id = user?.id ?? '';
    _deepLink = 'fairchat://chat/$id';
    // Web 分享鏈接：沿用當前頁面 origin，確保打開後由 config_link_provider 識別。
    final origin = Uri.base.origin;
    _webLink = '$origin/#/?chat=$id';
  }

  Future<void> _copy(String value, String labelKey) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(labelKey))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final cs = Theme.of(context).colorScheme;
    final link = kIsWeb ? _webLink : _deepLink;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('分享我的名片'))),
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
                  child: QrImageView(
                    data: _deepLink,
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
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr('扫码即可发起对话'),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 24),
              SelectableText(
                link,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.copy_outlined),
                label: Text(context.tr('复制分享链接')),
                onPressed: () => _copy(link, '已复制链接'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
