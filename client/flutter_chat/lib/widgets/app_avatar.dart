import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../utils/url.dart';

/// 統一頭像組件：支持網絡圖 / 首字母佔位、群聊圖標、在線狀態小圓點。
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool? online; // null = 不顯示狀態
  final bool isGroup;

  const AppAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 48,
    this.online,
    this.isGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final initial = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final img = imageUrl != null ? resolveUrl(imageUrl) : null;

    final placeholderBg = isGroup
        ? (dark ? AppColors.darkSurfaceVariant : const Color(0xFFE3F2EF))
        : (dark
            ? AppColors.brand.withValues(alpha: 0.22)
            : AppColors.brandSoft.withValues(alpha: 0.16));
    final placeholderFg = isGroup
        ? (dark ? AppColors.brandBright : AppColors.brand)
        : (dark ? AppColors.brandBright : AppColors.brand);

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: placeholderBg,
        borderRadius: BorderRadius.circular(size * 0.32),
        image: img != null
            ? DecorationImage(image: NetworkImage(img), fit: BoxFit.cover)
            : null,
      ),
      child: img != null
          ? null
          : Center(
              child: isGroup
                  ? Icon(Icons.group_rounded, size: size * 0.5, color: placeholderFg)
                  : Text(
                      initial,
                      style: TextStyle(
                        fontSize: size * 0.4,
                        fontWeight: FontWeight.w700,
                        color: placeholderFg,
                      ),
                    ),
            ),
    );

    if (online == null || isGroup) return avatar;

    final dot = size * 0.28;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: online! ? AppColors.online : AppColors.offline,
                shape: BoxShape.circle,
                border: Border.all(
                  color: dark ? AppColors.darkSurface : Colors.white,
                  width: size * 0.06,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
