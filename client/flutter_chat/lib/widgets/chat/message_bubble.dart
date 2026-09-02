import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/enums.dart';
import '../../models/message_dto.dart';
import '../../utils/url.dart';
import '../../pages/image_viewer_page.dart';
import 'voice_bubble.dart';

/// 单条消息气泡：按消息类型渲染文本 / 图片 / 文件 / 语音。
class MessageBubble extends StatelessWidget {
  final MessageDto message;
  final bool isMe;
  final void Function(String) onOpenUrl;
  final bool dark;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.onOpenUrl,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textColor = isMe
        ? Colors.white
        : (dark ? AppColors.bubbleTextPeerDark : AppColors.bubbleTextPeerLight);

    // 图片消息：圆角缩略图（自身即气泡）
    if (message.type == MessageType.image && message.mediaUrl != null) {
      final url = resolveUrl(message.mediaUrl);
      return Column(
        crossAxisAlignment: align,
        children: [
          if (!isMe && message.senderName.isNotEmpty) _senderName(context),
          GestureDetector(
            onTap: () => openImageViewer(context, url),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 200,
                maxHeight: 280,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  // 限制解码后的像素尺寸：原图动辄几千像素，
                  // 直接解码进内存会在长列表里引发 OOM。
                  memCacheWidth: 400,
                  placeholder: (c, _) => AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: dark
                          ? AppColors.darkSurfaceVariant
                          : const Color(0xFFEDF4F2),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  errorWidget: (c, _, __) => AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: dark
                          ? AppColors.darkSurfaceVariant
                          : const Color(0xFFEDF4F2),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image_outlined),
                            const SizedBox(height: 4),
                            Text(context.tr('加载失败·点击打开'),
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
        Container(
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
          child: body,
        ),
        const SizedBox(height: 4),
      ],
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
