import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_skin_provider.dart';
import '../theme.dart';

/// 系統功能開關：是否顯示在線狀態、啟用語音/視頻通話、允許發送文件/語音。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SystemSettingsDto? _settings;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _canWrite => context.read<AuthProvider>().hasPerm('settings.write');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AuthProvider>().api.getSettings();
      if (mounted) setState(() => _settings = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '加載失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_settings == null) return;
    setState(() => _saving = true);
    try {
      final updated = await context.read<AuthProvider>().api.updateSettings(_settings!);
      if (mounted) {
        setState(() => _settings = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存'), backgroundColor: AppTheme.primary),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失敗：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggle(bool value, void Function(bool) set) {
    if (!_canWrite) return;
    setState(() => set(value));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: AppTheme.textSub)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('重試'),
            ),
          ],
        ),
      );
    }
    if (_settings == null) return const SizedBox.shrink();

    // 本地外觀（不影響後端設置）。
    final skin = context.watch<ThemeSkinProvider>();
    final skinCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.brush_outlined, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text('色彩皮膚', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(skin.skin == ThemeSkin.sage ? '鼠尾草綠' : '藍',
                    style: TextStyle(color: AppTheme.textSub)),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeSkin>(
              selected: {skin.skin},
              onSelectionChanged: (s) => skin.set(s.first),
              segments: const [
                ButtonSegment(value: ThemeSkin.blue, label: Text('藍'), icon: Icon(Icons.water_drop)),
                ButtonSegment(value: ThemeSkin.sage, label: Text('鼠尾草綠'), icon: Icon(Icons.eco)),
              ],
            ),
          ],
        ),
      ),
    );

    final items = <_SettingItem>[
      _SettingItem(
        icon: Icons.visibility,
        title: '顯示在線狀態',
        desc: '在用戶頭像與聊天列表展示在線/離線標識',
        value: _settings!.showOnlineStatus,
        onChanged: (v) => _toggle(v, (val) => _settings = _settings!.copyWith(showOnlineStatus: val)),
      ),
      _SettingItem(
        icon: Icons.call,
        title: '啟用語音通話',
        desc: '允許用戶發起一對一語音通話',
        value: _settings!.enableVoiceCall,
        onChanged: (v) => _toggle(v, (val) => _settings = _settings!.copyWith(enableVoiceCall: val)),
      ),
      _SettingItem(
        icon: Icons.videocam,
        title: '啟用視頻通話',
        desc: '允許用戶發起一對一視頻通話',
        value: _settings!.enableVideoCall,
        onChanged: (v) => _toggle(v, (val) => _settings = _settings!.copyWith(enableVideoCall: val)),
      ),
      _SettingItem(
        icon: Icons.attach_file,
        title: '允許發送文件',
        desc: '在聊天輸入框顯示文件發送入口',
        value: _settings!.allowFile,
        onChanged: (v) => _toggle(v, (val) => _settings = _settings!.copyWith(allowFile: val)),
      ),
      _SettingItem(
        icon: Icons.mic,
        title: '允許發送語音',
        desc: '在聊天輸入框顯示語音錄制入口',
        value: _settings!.allowVoice,
        onChanged: (v) => _toggle(v, (val) => _settings = _settings!.copyWith(allowVoice: val)),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '系統功能配置',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textMain),
              ),
              const SizedBox(height: 6),
              const Text(
                '控制客戶端的在線狀態與通信能力開關。',
                style: TextStyle(color: AppTheme.textSub),
              ),
              const SizedBox(height: 20),
              if (!_canWrite)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('當前角色僅有只讀權限，無法修改配置。',
                            style: TextStyle(color: Colors.orange)),
                      ),
                    ],
                  ),
                ),
              skinCard,
              Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                          _SettingRow(item: items[i], enabled: _canWrite),
                        ],
                      ],
                    ),
                  ),
              const SizedBox(height: 24),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _canWrite && !_saving ? _save : null,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? '保存中...' : '保存配置'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重置'),
                  ),
                ],
              ),
              if (_settings!.updatedAt != null) ...[
                const SizedBox(height: 16),
                Text(
                  '最後更新：${_settings!.updatedAt!.toLocal().toString().replaceFirst(RegExp(r'\.\d+$'), '')}',
                  style: const TextStyle(color: AppTheme.textSub, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String title;
  final String desc;
  final bool value;
  final void Function(bool) onChanged;
  const _SettingItem({
    required this.icon,
    required this.title,
    required this.desc,
    required this.value,
    required this.onChanged,
  });
}

class _SettingRow extends StatelessWidget {
  final _SettingItem item;
  final bool enabled;
  const _SettingRow({required this.item, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: AppTheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(item.desc, style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: item.value,
            onChanged: enabled ? item.onChanged : null,
            activeTrackColor: AppTheme.primary,
            activeThumbColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}
