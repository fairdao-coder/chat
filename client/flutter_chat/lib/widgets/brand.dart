import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// 品牌標識：青綠漸變圓角方塊 + 聊天氣泡圖標，帶柔和投影。
///
/// 配置鏈接（fairchat://config?logo=...）可指定網絡圖片替換內置圖形；
/// 加載失敗（離線、CORS、非圖片 URL）時自動回落到內置標識，不會出現空白。
class BrandMark extends StatelessWidget {
  final double size;

  /// 應用內 Logo 圖片 URL；空則使用內置漸變標識。
  final String? imageUrl;
  const BrandMark({super.key, this.size = 64, this.imageUrl});

  Widget _builtin() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        Icons.chat_bubble_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final radius = BorderRadius.circular(size * 0.3);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: hasImage
          ? ClipRRect(
              borderRadius: radius,
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => _builtin(),
                errorWidget: (_, __, ___) => _builtin(),
              ),
            )
          : _builtin(),
    );
  }
}
