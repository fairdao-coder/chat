import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// 品牌标识：青绿渐变圆角方块 + 聊天气泡图标，带柔和投影。
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        Icons.chat_bubble_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}
