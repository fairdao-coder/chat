import 'package:flutter/material.dart';

import '../../config/app_colors.dart';

/// 标题栏下方的状态行：在线 / 离线 / 正在输入。
class PeerStatus extends StatelessWidget {
  final bool online;
  final bool typing;

  /// 后台是否开启在线状态展示；关闭且非输入中时整行隐藏。
  final bool showOnline;
  final String onlineLabel;
  final String offlineLabel;
  final String typingLabel;

  const PeerStatus({
    super.key,
    required this.online,
    required this.typing,
    required this.showOnline,
    required this.onlineLabel,
    required this.offlineLabel,
    required this.typingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 正在输入比在线状态更即时有用，优先展示（且不受在线状态开关影响）。
    if (typing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TypingDots(),
          const SizedBox(width: 6),
          Text(
            typingLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: AppColors.online,
            ),
          ),
        ],
      );
    }

    // 后台关闭在线状态展示时，非输入状态下整行隐藏。
    if (!showOnline) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(
            color: online ? AppColors.online : AppColors.offline,
            shape: BoxShape.circle,
          ),
        ),
        Text(
          online ? onlineLabel : offlineLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: online ? AppColors.online : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 「正在输入」的三点跳动动画。
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 8,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              // 三个点依次错开相位，形成波浪跳动。
              final phase = (_c.value - i * 0.15).clamp(0.0, 1.0);
              final scale =
                  0.6 + 0.4 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.online,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
