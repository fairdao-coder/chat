import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/core_providers.dart';

/// 全屏图片查看器：支持像微信一样的双指捏合缩放、双击放大/还原，以及保存图片。
class ImageViewerPage extends ConsumerStatefulWidget {
  final String url;
  final String heroTag;
  const ImageViewerPage({super.key, required this.url, this.heroTag = ''});

  @override
  ConsumerState<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends ConsumerState<ImageViewerPage> {
  final _transform = TransformationController();
  var _scale = 1.0;
  var _saving = false;

  String get _fileName =>
      widget.url.split('/').last.isNotEmpty ? widget.url.split('/').last : 'image.png';

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onDoubleTap() {
    final next = _scale == 1.0 ? 2.5 : 1.0;
    _transform.value = Matrix4.diagonal3Values(next, next, 1.0);
    _scale = next;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await ref.read(apiProvider).downloadBytes(widget.url);
      if (!mounted) return;
      if (kIsWeb) {
        // Web 端无法直接写相册，打开新标签页供用户另存。
        final uri = Uri.parse(widget.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, webOnlyWindowName: '_blank');
        } else {
          _toast(context.tr('保存失败'));
        }
        return;
      }
      final res = await ImageGallerySaver.saveImage(bytes,
          quality: 100, name: _fileName);
      if (!mounted) return;
      final ok = res is Map && res['isSuccess'] == true;
      _toast(ok ? context.tr('保存成功') : context.tr('保存失败'));
    } catch (_) {
      if (mounted) _toast(context.tr('保存失败'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 0.5,
        maxScale: 4.0,
        child: Hero(
          tag: widget.heroTag,
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            loadingBuilder: (c, child, prog) => prog == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (c, _, __) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined,
                      color: Colors.white70, size: 48),
                  const SizedBox(height: 8),
                  Text(context.tr('加载失败'),
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_outlined),
            tooltip: context.tr('保存图片'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Center(child: img),
    );
  }
}

/// 从聊天气泡打开全屏查看器。
void openImageViewer(BuildContext context, String resolvedUrl) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ImageViewerPage(
        url: resolvedUrl,
        heroTag: 'img_$resolvedUrl',
      ),
    ),
  );
}
