import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/notification_provider.dart';

/// 屏幕顶部消息通知横幅层。监听 [messageNotificationsProvider]，对任意「非当前会话」
/// 收到的消息在顶部滑入闪现 10 秒；可点按跳转至对应会话。
///
/// 息屏/后台（AppLifecycleState 非 resumed）时收到新通知额外播放系统提示音。
class MessageBannerOverlay extends ConsumerStatefulWidget {
  const MessageBannerOverlay({super.key});

  @override
  ConsumerState<MessageBannerOverlay> createState() => _MessageBannerOverlayState();
}

class _MessageBannerOverlayState extends ConsumerState<MessageBannerOverlay>
    with WidgetsBindingObserver {
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 监听新增通知；处于后台/息屏时播放提示音。
    ref.listenManual(messageNotificationsProvider, (prev, next) {
      if (_resumed) return;
      final prevList = prev ?? const <IncomingMessage>[];
      final added = next.where((m) => !prevList.any((p) => p.id == m.id));
      if (added.isNotEmpty) {
        // 仅对「新增」的首条播一次，避免批量推送时连响。
        SystemSound.play(SystemSoundType.alert);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // resumed = 前台可见；paused/inactive/detached = 已息屏或切到后台。
    _resumed = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(messageNotificationsProvider);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++)
              _BannerItem(
                key: ValueKey(items[i].id),
                message: items[i],
                onDismiss: () {
                  if (mounted) {
                    ref
                        .read(messageNotificationsProvider.notifier)
                        .remove(items[i].id);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _BannerItem extends ConsumerStatefulWidget {
  final IncomingMessage message;
  final VoidCallback onDismiss;
  const _BannerItem({required Key key, required this.message, required this.onDismiss});

  @override
  ConsumerState<_BannerItem> createState() => _BannerItemState();
}

class _BannerItemState extends ConsumerState<_BannerItem> {
  bool _shown = false;
  Timer? _autoHide;

  @override
  void initState() {
    super.initState();
    // 进入动画 + 10 秒后自动消失。必须判 mounted，防止 item 已被 dispose 后 timer 回调仍触发 onDismiss。
    _autoHide = Timer(const Duration(seconds: 10), () {
      if (mounted) widget.onDismiss();
    });
    // 下一帧触发滑入动画。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    super.dispose();
  }

  void _open() {
    final m = widget.message;
    widget.onDismiss();
    final query = m.isGroup ? 'groupId=${m.targetId}' : 'friendId=${m.targetId}';
    context.go('/chat?$query');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = widget.message;
    final avatar = m.senderAvatar;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, _shown ? 0 : -120, 0),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: cs.surfaceContainerHighest,
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (avatar != null)
                  CircleAvatar(backgroundImage: NetworkImage(avatar), radius: 20)
                else
                  CircleAvatar(
                    radius: 20,
                    child: Text(m.senderName.isNotEmpty ? m.senderName[0] : '?'),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onDismiss,
                  tooltip: '关闭',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
