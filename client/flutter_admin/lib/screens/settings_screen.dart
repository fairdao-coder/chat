import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../l10n/app_strings.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../theme.dart';

/// 系統功能開關：是否顯示在線狀態、啟用語音/視頻通話、允許發送文件/語音。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SystemSettingsDto? _settings;
  /// 固定欄目列表（用於「默認打開欄目」下拉）。
  List<DiscoverColumnDto> _pinnedColumns = [];
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
      final api = context.read<AuthProvider>().api;
      final data = await api.getSettings();
      final all = await api.listDiscover();
      final pinned = all.where((c) => c.pinned).toList()
        ..sort((a, b) => a.sort.compareTo(b.sort));
      if (mounted) {
        setState(() {
          _settings = data;
          _pinnedColumns = pinned;
        });
      }
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
    final t = context.read<LocaleProvider>().t;
    setState(() => _saving = true);
    try {
      final updated = await context.read<AuthProvider>().api.updateSettings(_settings!);
      if (mounted) {
        setState(() => _settings = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t[K.saved]), backgroundColor: AppTheme.primary),
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
          SnackBar(content: Text('${t[K.saveFailed]}$e'), backgroundColor: Colors.red),
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
    // 界面語言：本地外觀 + 文案，不影響後端設置。
    // 需在所有 return 分支之前取，否則錯誤/加載分支拿不到 t。
    final loc = context.watch<LocaleProvider>();
    final t = loc.t;
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
              label: Text(t[K.retry]),
            ),
          ],
        ),
      );
    }
    if (_settings == null) return const SizedBox.shrink();


    // 界面語言切換：寫入 SharedPreferences，僅影響本機後臺界面。
    final languageCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.translate, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(t[K.language],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(loc.locale.nativeName, style: TextStyle(color: AppTheme.textSub)),
              ],
            ),
            const SizedBox(height: 6),
            Text(t[K.languageDesc],
                style: const TextStyle(color: AppTheme.textSub, fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final l in AppLocale.values)
                  ChoiceChip(
                    label: Text(l.nativeName),
                    selected: loc.locale == l,
                    onSelected: (_) => loc.set(l),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    // 默認打開欄目：從已固定欄目中選擇；保存時寫入 SystemSettings.DefaultColumnId。
    final defaultColumnCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.home_outlined, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text('默認打開欄目',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            const Text('客戶端啟動後自動進入該固定欄目；未配置則進入排序最靠前的固定欄目。',
                style: TextStyle(color: AppTheme.textSub, fontSize: 12)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _settings!.defaultColumnId,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.push_pin_outlined),
              ),
              hint: const Text('未配置（使用默認順序）'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('未配置')),
                for (final c in _pinnedColumns)
                  DropdownMenuItem<String?>(
                      value: c.id, child: Text(c.title)),
              ],
              onChanged: _canWrite
                  ? (v) => setState(() {
                        _settings!.defaultColumnId = v;
                      })
                  : null,
            ),
          ],
        ),
      ),
    );

    final iceServersCard = _IceServersCard(
      settings: _settings!,
      canWrite: _canWrite,
      onChanged: () => setState(() {}),
    );

    final items = <_SettingItem>[
      _SettingItem(
        icon: Icons.visibility,
        title: t[K.featOnline],
        desc: t[K.featOnlineDesc],
        value: _settings!.showOnlineStatus,
        onChanged: (v) => _toggle(v, (val) => _settings = _settings!.copyWith(showOnlineStatus: val)),
      ),
      _SettingItem(
        icon: Icons.call,
        title: t[K.featVoiceCall],
        desc: t[K.featVoiceCallDesc],
        value: _settings!.enableVoiceCall,
        onChanged: (v) => _toggle(v, (val) => _settings = _settings!.copyWith(enableVoiceCall: val)),
      ),
      _SettingItem(
        icon: Icons.videocam,
        title: t[K.featVideoCall],
        desc: t[K.featVideoCallDesc],
        value: _settings!.enableVideoCall,
        onChanged: (v) => _toggle(v, (val) => _settings = _settings!.copyWith(enableVideoCall: val)),
      ),
      _SettingItem(
        icon: Icons.attach_file,
        title: t[K.featFile],
        desc: t[K.featFileDesc],
        value: _settings!.allowFile,
        onChanged: (v) => _toggle(v, (val) => _settings = _settings!.copyWith(allowFile: val)),
      ),
      _SettingItem(
        icon: Icons.mic,
        title: t[K.featVoice],
        desc: t[K.featVoiceDesc],
        value: _settings!.allowVoice,
        onChanged: (v) => _toggle(v, (val) => _settings = _settings!.copyWith(allowVoice: val)),
      ),
      _SettingItem(
        icon: Icons.person_add,
        title: t[K.featRegister],
        desc: t[K.featRegisterDesc],
        value: _settings!.allowRegister,
        onChanged: (v) => _toggle(v, (val) => _settings = _settings!.copyWith(allowRegister: val)),
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
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(t[K.readOnly],
                            style: const TextStyle(color: Colors.orange)),
                      ),
                    ],
                  ),
                ),
              languageCard,
              defaultColumnCard,
              iceServersCard,
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
                    label: Text(_saving ? t[K.saving] : t[K.saveConfig]),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(t[K.reset]),
                  ),
                ],
              ),
              if (_settings!.updatedAt != null) ...[
                const SizedBox(height: 16),
                Text(
                  '${t[K.lastUpdated]}${_settings!.updatedAt!.toLocal().toString().replaceFirst(RegExp(r'\.\d+$'), '')}',
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

/// WebRTC ICE 服務器（STUN/TURN）編輯卡片。
///
/// 直接讀寫 [settings.iceServers]（即 [SystemSettingsDto.rtConfig]），
/// 保存時隨同其他設置一併提交。外部替換 [settings]（加載/重置/保存回傳）時，
/// 若 [rtConfig] 實際改變則重新同步，避免編輯中丟失焦點。
class _IceServersCard extends StatefulWidget {
  final SystemSettingsDto settings;
  final bool canWrite;
  final VoidCallback onChanged;
  const _IceServersCard({
    required this.settings,
    required this.canWrite,
    required this.onChanged,
  });

  @override
  State<_IceServersCard> createState() => _IceServersCardState();
}

class _IceServersCardState extends State<_IceServersCard> {
  late List<IceServerEntry> _servers;
  late List<TextEditingController> _urlCtrls;
  late List<TextEditingController> _userCtrls;
  late List<TextEditingController> _credCtrls;

  @override
  void initState() {
    super.initState();
    _servers = widget.settings.iceServers
        .map((e) => IceServerEntry(
              urls: List.from(e.urls),
              username: e.username,
              credential: e.credential,
              credentialType: e.credentialType,
            ))
        .toList();
    _buildControllers();
  }

  void _buildControllers() {
    _urlCtrls =
        _servers.map((e) => TextEditingController(text: e.urls.join(', '))).toList();
    _userCtrls =
        _servers.map((e) => TextEditingController(text: e.username ?? '')).toList();
    _credCtrls =
        _servers.map((e) => TextEditingController(text: e.credential ?? '')).toList();
  }

  void _disposeControllers() {
    for (final c in _urlCtrls) {
      c.dispose();
    }
    for (final c in _userCtrls) {
      c.dispose();
    }
    for (final c in _credCtrls) {
      c.dispose();
    }
  }

  @override
  void didUpdateWidget(covariant _IceServersCard old) {
    super.didUpdateWidget(old);
    // 外部資料（加載/重置/保存回傳）改變時重新同步；編輯過程中 rtConfig 原地變更不觸發。
    if (old.settings.rtConfig != widget.settings.rtConfig) {
      _disposeControllers();
      _servers = widget.settings.iceServers
          .map((e) => IceServerEntry(
                urls: List.from(e.urls),
                username: e.username,
                credential: e.credential,
                credentialType: e.credentialType,
              ))
          .toList();
      _buildControllers();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _sync() {
    widget.settings.iceServers = _servers;
    widget.onChanged();
  }

  void _setUrls(int i, String text) {
    _servers[i].urls = text
        .split(RegExp(r'[,\s;]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _sync();
  }

  void _add() {
    setState(() {
      _servers.add(IceServerEntry());
      _urlCtrls.add(TextEditingController());
      _userCtrls.add(TextEditingController());
      _credCtrls.add(TextEditingController());
    });
    _sync();
  }

  void _remove(int i) {
    setState(() {
      _servers.removeAt(i);
      _urlCtrls[i].dispose();
      _userCtrls[i].dispose();
      _credCtrls[i].dispose();
      _urlCtrls.removeAt(i);
      _userCtrls.removeAt(i);
      _credCtrls.removeAt(i);
    });
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dns_outlined, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(t[K.iceTitle],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t[K.iceDesc],
              style: const TextStyle(color: AppTheme.textSub, fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _servers.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              _serverEditor(i),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.canWrite ? _add : null,
              icon: const Icon(Icons.add),
              label: Text(t[K.iceAdd]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serverEditor(int i) {
    final t = context.watch<LocaleProvider>().t;
    final s = _servers[i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(t.tr(K.iceServer, {'n': '${i + 1}'}),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (widget.canWrite)
              IconButton(
                onPressed: () => _remove(i),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: t[K.delete],
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _urlCtrls[i],
          enabled: widget.canWrite,
          decoration: InputDecoration(
            labelText: t[K.iceUrls],
            prefixIcon: const Icon(Icons.link),
            hintText: 'stun:stun.l.google.com:19302 或 turn:turn.example.com:3478?transport=udp',
          ),
          onChanged: (v) => _setUrls(i, v),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _userCtrls[i],
                enabled: widget.canWrite,
                decoration: InputDecoration(
                  labelText: t[K.iceUsername],
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                onChanged: (v) {
                  s.username = v.trim().isEmpty ? null : v.trim();
                  _sync();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _credCtrls[i],
                enabled: widget.canWrite,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: t[K.iceCredential],
                  prefixIcon: const Icon(Icons.key_outlined),
                ),
                onChanged: (v) {
                  s.credential = v.trim().isEmpty ? null : v.trim();
                  _sync();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: s.credentialType,
          decoration: InputDecoration(
            labelText: t[K.iceCredType],
            prefixIcon: const Icon(Icons.badge_outlined),
          ),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(t[K.iceCredPassword])),
            DropdownMenuItem<String?>(value: 'password', child: Text('password')),
            DropdownMenuItem<String?>(value: 'oauth', child: Text('oauth')),
          ],
          onChanged: (v) {
            s.credentialType = v;
            _sync();
          },
        ),
      ],
    );
  }
}
