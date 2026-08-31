import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
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
  MobileScannerController? _controller;
  var _handled = false;

  // 相机权限状态：null = 检查中，true = 已授权，false = 被拒。
  bool? _cameraGranted;

  // 相机初始化失败时的错误信息（简体中文 key，会自动 fallback）。
  String? _cameraError;

  // 最近一次底层错误对象，用于调试展示。
  Object? _lastScannerError;

  @override
  void initState() {
    super.initState();
    _requestCamera();
  }

  Future<void> _requestCamera() async {
    // 安卓 6+ 需要运行时申请相机权限；mobile_scanner 不会自动弹窗。
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (mounted) setState(() => _cameraGranted = true);
      await _startScanner();
      return;
    }
    final result = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraGranted = result.isGranted);
    if (result.isGranted) {
      await _startScanner();
    }
  }

  Future<void> _startScanner() async {
    // 在权限未授权前不要创建 controller，否则 mobile_scanner 会报
    // "An unexpected error occurred"。
    if (_cameraGranted != true) return;
    if (!mounted) return;
    _scannerLog('启动相机');
    // 先停止并释放旧 controller，再清状态；否则旧 session 未释放会导致
    // 新 controller 初始化失败（"An unexpected error occurred"）。
    _stopScanner();
    setState(() {
      _cameraError = null;
      _lastScannerError = null;
    });

    // 给页面切换 / 相机关闭预留一点时间，避免某些机型因
    // 旧 camera session 未完全释放而立即初始化失败。
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    try {
      final controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        formats: [BarcodeFormat.all],
      );
      _scannerLog('创建相机控制器');
      setState(() => _controller = controller);
    } catch (e) {
      _scannerLog('创建控制器异常: $e');
      if (mounted) setState(() => _cameraError = context.tr('相机启动失败'));
    }
  }

  void _stopScanner() {
    _scannerLog('停止相机');
    _controller?.stop().ignore();
    _controller?.dispose();
    _controller = null;
  }

  void _onScannerError(Object error, BuildContext context) {
    _scannerLog('相机错误: $error');
    if (!mounted) return;
    setState(() {
      _cameraError = context.tr('相机启动失败');
      _lastScannerError = error;
    });
  }

  void _scannerLog(String message) {
    // ignore: avoid_print
    debugPrint('[ScanPage] $message');
  }

  @override
  void dispose() {
    _stopScanner();
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

    Widget body;
    if (_cameraGranted == null) {
      // 权限检查中。
      body = const Center(child: CircularProgressIndicator());
    } else if (_cameraGranted == false) {
      // 未授权：提示并允许去系统设置开启。
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                loc.t('需要相机权限才能扫码'),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                loc.t('请在系统设置中允许本应用使用相机'),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.settings_outlined),
                label: Text(loc.t('去设置')),
                onPressed: () async {
                  await openAppSettings();
                  // 从设置返回后重新检查权限。
                  if (mounted) _requestCamera();
                },
              ),
            ],
          ),
        ),
      );
    } else if (_controller == null || _cameraError != null) {
      // 已授权但相机尚未启动成功：显示加载或错误重试。
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _cameraError == null ? Icons.camera_alt_outlined : Icons.error_outline,
                size: 56,
                color: _cameraError == null ? Colors.grey : cs.error,
              ),
              const SizedBox(height: 16),
              Text(
                _cameraError ?? loc.t('正在启动相机…'),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (_cameraError != null) ...[
                if (_lastScannerError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _lastScannerError.toString(),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.error),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: Text(loc.t('重试')),
                  onPressed: () async {
                    setState(() {
                      _cameraError = null;
                      _lastScannerError = null;
                    });
                    await _startScanner();
                  },
                ),
              ] else ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
              ],
            ],
          ),
        ),
      );
    } else {
      body = Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              // 出现底层错误时给出明确提示，而不是仅显示默认英文。
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _onScannerError(error, context);
              });
              return const SizedBox.shrink();
            },
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
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('扫一扫')),
        actions: [
          if (_cameraGranted == true && _controller != null) ...[
            IconButton(
              icon: const Icon(Icons.flip_camera_android_outlined),
              tooltip: loc.t('切换摄像头'),
              onPressed: () => _controller?.switchCamera(),
            ),
            IconButton(
              icon: const Icon(Icons.flash_on_outlined),
              tooltip: loc.t('闪光灯'),
              onPressed: () => _controller?.toggleTorch(),
            ),
          ],
        ],
      ),
      body: body,
    );
  }
}
