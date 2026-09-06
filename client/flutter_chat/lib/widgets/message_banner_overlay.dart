import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notification_provider.dart';
import '../router.dart';

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
  ProviderSubscription<List<IncomingMessage>>? _msgSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 监听新增通知；处于后台/息屏时播放提示音。
    _msgSub = ref.listenManual(messageNotificationsProvider, (prev, next) {
      if (!mounted || _resumed) return;
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
    _msgSub?.close();
    _msgSub = null;
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
              Builder(
                builder: (_) {
                  // 在迴圈體內用 final 固定當前 item，避免閉包捕獲循環變量 i，
                  // 否則 rebuild 後 onDismiss 可能拿到錯誤索引或越界。
                  final message = items[i];
                  return _BannerItem(
                    key: ValueKey(message.id),
                    message: message,
                    onDismiss: () {
                      if (!mounted) return;
                      ref
                          .read(messageNotificationsProvider.notifier)
                          .remove(message.id);
                    },
                  );
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
    if (!mounted) return;
    final m = widget.message;
    final targetId = m.targetId;
    if (targetId.isEmpty) {
      developer.log('Banner message has empty targetId, skip navigation', name: 'banner');
      widget.onDismiss();
      return;
    }
    // 先導航，再把 dismiss 推到下一幀：go 會同步觸發 widget tree 重建，
    // 若緊接著同步調用 onDismiss（修改 provider），會觸發 Riverpod 的
    // "modify provider during build" 異常。用 addPostFrameCallback 錯開重建週期。
    final query = m.isGroup
        ? 'groupId=$targetId'
        : 'friendId=$targetId&name=${Uri.encodeComponent(m.senderName)}';
    // 横幅位於 MaterialApp.builder 的 Overlay 中，其 context 在 Router 之上，
    // 取不到 GoRouter（context.go 會拋 "No GoRouter found in context"）。
    // 改用 routerProvider 持有的 GoRouter 實例直接導航，繞開 context 限制。
    ref.read(routerProvider).go('/chat?$query');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onDismiss();
    });
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
