import 'package:flutter/material.dart';

import '../theme.dart';

/// 分組卡片：為表單欄位提供標題與內邊距，減少擁擠感。
class FieldGroup extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Widget> children;

  const FieldGroup({
    super.key,
    required this.icon,
    required this.label,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECEEF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSub,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFECEEF3)),
          ...children,
        ],
      ),
    );
  }
}

/// 輕提示卡片。
class TipCard extends StatelessWidget {
  final List<Widget> children;

  const TipCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF3FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD6E0FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// 提示卡片內的一行。
class TipRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const TipRow(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textMain, height: 1.4),
          ),
        ),
      ],
    );
  }
}
