import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as developer;

import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/enums.dart';
import '../../models/message_dto.dart';
import '../../providers/auth_provider.dart';
import '../../utils/url.dart';
import '../../pages/image_viewer_page.dart';
import 'voice_bubble.dart';

/// 单条消息气泡：按消息类型渲染文本 / 图片 / 文件 / 语音，
/// 支持撤回态渲染与引用（回复）摘要，长按触发操作菜单（由父级处理）。
class MessageBubble extends ConsumerWidget {
  final MessageDto message;
  final bool isMe;
  final void Function(String) onOpenUrl;
  final bool dark;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.onOpenUrl,
    required this.dark,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 已撤回：居中灰色系統提示，不渲染原氣泡。
    if (message.recalled) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isMe
                  ? context.tr('你撤回了一条消息')
                  : '${message.senderName} ${context.tr('撤回了一条消息')}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textColor = isMe
        ? Colors.white
        : (dark ? AppColors.bubbleTextPeerDark : AppColors.bubbleTextPeerLight);

    // 图片消息：圆角缩略图（自身即气泡）
    if (message.type == MessageType.image && message.mediaUrl != null) {
      final url = resolveUrl(message.mediaUrl);
      final token = ref.watch(authProvider).token;
      final headers = token != null && token.isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : const <String, String>{};

      return Column(
        crossAxisAlignment: align,
        children: [
          if (!isMe && message.senderName.isNotEmpty) _senderName(context),
          GestureDetector(
            onTap: () => openImageViewer(context, url),
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 200,
                maxHeight: 280,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildImage(url, headers),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    // 语音消息：播放 / 暂停 + 进度条 + 时长
    if (message.type == MessageType.voice && message.mediaUrl != null) {
      final dur = int.tryParse(message.content) ?? 0;
      return _wrap(
        context,
        VoiceBubble(
          url: resolveUrl(message.mediaUrl!),
          seconds: dur,
          isMe: isMe,
          textColor: textColor,
        ),
        align,
        textColor,
      );
    }

    final Widget body;
    if (message.type == MessageType.file && message.mediaUrl != null) {
      final url = resolveUrl(message.mediaUrl);
      final name = message.mediaUrl!.split('/').last;
      body = GestureDetector(
        onTap: () => onOpenUrl(url),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined, color: textColor, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  color: textColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      body =
          Text(message.content, style: TextStyle(color: textColor, fontSize: 15));
    }

    return _wrap(context, body, align, textColor);
  }

  /// 圖片加載：
  /// - Web 端用 [Image.network]（Flutter Web 下 CachedNetworkImage 不支持自訂 Header，
  ///   且 CanvasKit 對圖片 CORS 敏感，瀏覽器會自動處理 <img> 的跨域）。
  /// - 移動端用 [CachedNetworkImage]，帶上 Bearer token，並記錄真實錯誤信息。
  /// 點擊錯誤區塊會強制重新載入。
  Widget _buildImage(String url, Map<String, String> headers) {
    final bgColor = dark
        ? AppColors.darkSurfaceVariant
        : const Color(0xFFEDF4F2);
    final errorChild = AspectRatio(
      aspectRatio: 1,
      child: Container(
        color: bgColor,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined),
              SizedBox(height: 4),
              Text('加载失败·点击打开', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );

    if (kIsWeb) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        headers: headers,
        loadingBuilder: (c, child, prog) => prog == null
            ? child
            : AspectRatio(
                aspectRatio: 1,
                child: Container(
                  color: bgColor,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
        errorBuilder: (c, _, __) {
          developer.log('Web Image.network load failed url=$url',
              name: 'chat');
          return errorChild;
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      httpHeaders: headers,
      // 限制解码后的像素尺寸：原图动辄几千像素，
      // 直接解码进内存会在长列表里引发 OOM。
      memCacheWidth: 400,
      placeholder: (c, _) => AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: bgColor,
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
      errorWidget: (c, url, err) {
        developer.log('CachedNetworkImage load failed url=$url error=$err',
            name: 'chat');
        return errorChild;
      },
    );
  }

  Widget _wrap(BuildContext context, Widget body, CrossAxisAlignment align,
      Color textColor) {
    final radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(5),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(5),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          );

    return Column(
      crossAxisAlignment: align,
      children: [
        if (!isMe && message.senderName.isNotEmpty) _senderName(context),
        GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              gradient: isMe ? AppColors.bubbleMine : null,
              color: isMe
                  ? null
                  : (dark ? AppColors.bubblePeerDark : AppColors.bubblePeerLight),
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: isMe
                      ? AppColors.brand.withValues(alpha: 0.28)
                      : Colors.black.withValues(alpha: dark ? 0.25 : 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.replyToId != null)
                  _replyPreview(context, textColor),
                body,
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  /// 引用（回覆）摘要塊：左側豎線 + 原發送者 + 摘要。
  /// 原消息已撤回時摘要為 null，顯示「原消息已撤回」。
  Widget _replyPreview(BuildContext context, Color textColor) {
    final cs = Theme.of(context).colorScheme;
    final previewText = message.replyPreview ?? context.tr('原消息已撤回');
    final label = message.replySenderName == null
        ? previewText
        : '${message.replySenderName}: $previewText';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: cs.onSurfaceVariant.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            width: 3,
            color: isMe ? Colors.white.withValues(alpha: 0.7) : cs.primary,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          color: isMe ? Colors.white.withValues(alpha: 0.9) : cs.onSurfaceVariant,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _senderName(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 3),
        child: Text(
          message.senderName,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}
