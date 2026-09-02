import 'package:flutter/material.dart';
import '../theme.dart';

/// 後臺管理導航目的地定義（公開類型，供 HomeScreen 構造）。
class Dest {
  final String title;
  final IconData icon;
  final String perm;
  final Widget screen;
  const Dest(this.title, this.icon, this.perm, this.screen);
}

class AppDrawer extends StatelessWidget {
  final List<Dest> dests;
  final int currentIndex;
  final void Function(int) onSelect;

  const AppDrawer({
    super.key,
    required this.dests,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topRight: Radius.circular(18), bottomRight: Radius.circular(18)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
            decoration: BoxDecoration(gradient: AppTheme.activeGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.admin_panel_settings, size: 28, color: Colors.white),
                ),
                const SizedBox(height: 14),
                const Text('後臺管理',
                    style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Chat Admin Console',
                    style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 0.4)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: dests.length,
              itemBuilder: (context, i) {
                final active = i == currentIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Material(
                    color: active ? AppTheme.primarySoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        onSelect(i);
                        if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        child: Row(
                          children: [
                            Icon(dests[i].icon,
                                color: active ? AppTheme.primary : AppTheme.textSub, size: 22),
                            const SizedBox(width: 14),
                            Text(dests[i].title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                                  color: active ? AppTheme.primary : AppTheme.textMain,
                                )),
                            const Spacer(),
                            if (active)
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppTheme.activePrimary, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppTheme.textSub),
                SizedBox(width: 6),
                Text('Chat Admin · ASP.NET Core 10',
                    style: TextStyle(color: AppTheme.textSub, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
