import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/config_link_provider.dart';

/// 掃一掃頁面。
///
/// 支援三類掃描結果：
///   1. 配置鏈接 `fairchat://config?...` -> 彈出確認對話框導入配置；
///   2. http(s) 網頁鏈接            -> 調起外部瀏覽器打開；
///   3. 其他純文本                  -> 以對話框展示文本內容。
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  var _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final code = capture.barcodes.where((b) => b.rawValue != null).firstOrNull;
    final value = code?.rawValue;
    if (value == null || value.isEmpty) return;

    // 同一次掃描只處理第一個有效結果，避免重複彈窗。
    setState(() => _handled = true);

    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme == 'fairchat' && uri.host == 'config') {
      // 1) 配置鏈接：複用全局確認對話框。
      await ref.read(configLinkProvider.notifier).handleLink(uri);
      if (mounted) context.pop();
      return;
    }

    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      // 2) 網頁鏈接：外部瀏覽器打開。
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        if (!ok) {
          _showText(context.tr('无法打开'), value);
        } else {
          context.pop();
        }
      }
      return;
    }

    // 3) 純文本：展示內容。
    if (mounted) _showText(context.tr('扫码结果'), value);
  }

  void _showText(String title, String content) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(content),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(c).pop();
              // 關閉對話框後允許繼續掃描。
              if (mounted) setState(() => _handled = false);
            },
            child: Text(context.tr('确定')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = L10n.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('扫一扫')),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_android_outlined),
            tooltip: loc.t('切换摄像头'),
            onPressed: () => _controller.switchCamera(),
          ),
          IconButton(
            icon: const Icon(Icons.flash_on_outlined),
            tooltip: loc.t('闪光灯'),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // 掃描框遮罩提示
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.primary, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    loc.t('将二维码放入框内，即可自动识别'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
