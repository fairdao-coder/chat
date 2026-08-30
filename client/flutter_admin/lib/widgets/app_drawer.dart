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
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: AppTheme.primary),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, size: 36, color: Colors.white),
                SizedBox(width: 12),
                Text('後臺管理', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          for (var i = 0; i < dests.length; i++)
            ListTile(
              leading: Icon(dests[i].icon, color: i == currentIndex ? AppTheme.primary : null),
              title: Text(dests[i].title),
              selected: i == currentIndex,
              selectedTileColor: AppTheme.primarySoft,
              onTap: () {
                onSelect(i);
                if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
              },
            ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Chat Admin · ASP.NET Core 10', style: TextStyle(color: AppTheme.textSub, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
