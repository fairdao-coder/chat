import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

/// 發現頁欄目管理：列出欄目，支持新增 / 編輯 / 刪除。
/// 欄目的 Link 為鏈接地址，App 端點擊後會在 WebView 中打開。
class DiscoverColumnsScreen extends StatefulWidget {
  const DiscoverColumnsScreen({super.key});

  @override
  State<DiscoverColumnsScreen> createState() => _DiscoverColumnsScreenState();
}

class _DiscoverColumnsScreenState extends State<DiscoverColumnsScreen> {
  List<DiscoverColumnDto> _items = [];
  bool _loading = false;
  String? _error;

  bool get _canWrite => context.read<AuthProvider>().hasPerm('discover.write');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<AuthProvider>().api.listDiscover();
      if (mounted) setState(() => _items = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '加載失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(DiscoverColumnDto? col) async {
    final api = context.read<AuthProvider>().api;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ColumnDialog(initial: col),
    );
    if (result == null) return;

    try {
      if (col == null) {
        await api.createDiscover(result);
      } else {
        await api.updateDiscover(col.id, result);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(col == null ? '已新增' : '已保存')));
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失敗：${e.message}')));
      }
    }
  }

  Future<void> _delete(DiscoverColumnDto col) async {
    final api = context.read<AuthProvider>().api;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定刪除欄目「${col.title}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await api.deleteDiscover(col.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除')));
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('刪除失敗：${e.message}')));
      }
    }
  }

  /// 構造 PUT 全量請求體：後端 UpsertDiscoverColumnRequest 要求 Title 等必填字段，
  /// 快速開關操作需攜帶完整字段，僅覆蓋被切換的開關。
  Map<String, dynamic> _fullPayload(
    DiscoverColumnDto col, {
    bool? enabled,
    bool? pinned,
  }) =>
      {
        'title': col.title,
        'icon': col.icon,
        'kind': col.kind,
        'content': col.content,
        'sort': col.sort,
        'enabled': enabled ?? col.enabled,
        'pinned': pinned ?? col.pinned,
      };

  /// 快速啟用 / 停用欄目。
  Future<void> _toggleEnabled(DiscoverColumnDto col) async {
    if (!_canWrite) return;
    final api = context.read<AuthProvider>().api;
    final next = !col.enabled;
    final idx = _items.indexWhere((e) => e.id == col.id);
    // 乐观更新，提升交互反馈速度。
    if (mounted && idx >= 0) {
      setState(() => _items[idx] = col.copyWith(enabled: next));
    }
    try {
      await api.updateDiscover(col.id, _fullPayload(col, enabled: next));
    } on ApiException catch (e) {
      if (mounted) {
        if (idx >= 0) setState(() => _items[idx] = col);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失敗：${e.message}')));
      }
    } catch (e) {
      if (mounted) {
        if (idx >= 0) setState(() => _items[idx] = col);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失敗：$e')));
      }
    }
  }

  /// 快速固定 / 取消固定欄目。
  Future<void> _togglePinned(DiscoverColumnDto col) async {
    if (!_canWrite) return;
    final api = context.read<AuthProvider>().api;
    final next = !col.pinned;
    final idx = _items.indexWhere((e) => e.id == col.id);
    if (mounted && idx >= 0) {
      setState(() => _items[idx] = col.copyWith(pinned: next));
    }
    try {
      await api.updateDiscover(col.id, _fullPayload(col, pinned: next));
    } on ApiException catch (e) {
      if (mounted) {
        if (idx >= 0) setState(() => _items[idx] = col);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失敗：${e.message}')));
      }
    } catch (e) {
      if (mounted) {
        if (idx >= 0) setState(() => _items[idx] = col);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失敗：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('發現頁欄目',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_canWrite)
                FilledButton.icon(
                  onPressed: () => _edit(null),
                  icon: const Icon(Icons.add),
                  label: const Text('新增欄目'),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: '刷新',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('暫無欄目'))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final c = _items[i];
                          final kindLabel = _kindLabel(c.kind);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primarySoft,
                              child: c.icon?.isNotEmpty == true
                                  ? Text(c.icon!, style: const TextStyle(fontSize: 16))
                                  : Icon(_kindIcon(c.kind), size: 18),
                            ),
                            title: Row(
                              children: [
                                Text(c.title),
                                if (c.pinned) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.push_pin, size: 11, color: Colors.amber.shade800),
                                        const SizedBox(width: 3),
                                        Text('固定',
                                            style: TextStyle(
                                                fontSize: 10, color: Colors.amber.shade800)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              '$kindLabel · ${c.content ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!c.enabled)
                                  const Chip(
                                    label: Text('已隱藏', style: TextStyle(fontSize: 11)),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Color(0xFFEEEEEE),
                                  ),
                                if (_canWrite)
                                  IconButton(
                                    icon: Icon(
                                      c.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                                      color: c.pinned ? Colors.amber.shade700 : Colors.grey,
                                    ),
                                    tooltip: c.pinned ? '取消固定' : '固定到底部導航',
                                    onPressed: () => _togglePinned(c),
                                  ),
                                if (_canWrite)
                                  IconButton(
                                    icon: Icon(
                                      c.enabled ? Icons.visibility : Icons.visibility_off,
                                      color: c.enabled ? AppTheme.primary : Colors.grey,
                                    ),
                                    tooltip: c.enabled ? '停用' : '啟用',
                                    onPressed: () => _toggleEnabled(c),
                                  ),
                                if (_canWrite) ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _edit(c),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    onPressed: () => _delete(c),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// 欄目類型選項。
const Map<String, String> _kinds = {
  'tab': '底部固定 Tab',
  'link': '外部鏈接（WebView）',
  'route': '內部路由',
  'action': '內置動作',
  'mini': '小應用 / H5 本地包',
};

/// 內置動作選項。
const Map<String, String> _actions = {
  'scan': '掃一掃',
  'addFriend': '添加好友',
  'createGroup': '創建群聊',
  'friendRequests': '好友請求',
};

/// 底部 Tab 跳轉目標選項。
const Map<String, String> _tabTargets = {
  'chat': '信息（會話列表）',
  'contacts': '通訊錄',
  'discover': '發現',
  'me': '我',
};

String _kindLabel(String k) => _kinds[k] ?? k;
IconData _kindIcon(String k) {
  switch (k) {
    case 'route':
      return Icons.open_in_new;
    case 'action':
      return Icons.flash_on_outlined;
    case 'mini':
      return Icons.apps_outlined;
    case 'tab':
      return Icons.push_pin_outlined;
    default:
      return Icons.link;
  }
}

/// 不同類型下 Content 欄位的輸入提示。
String? _contentHint(String kind) {
  switch (kind) {
    case 'route':
      return '/add-friend';
    case 'action':
      return null; // action 用下拉選擇
    case 'tab':
      return null; // tab 用下拉選擇
    case 'mini':
      return '包名如 vote；html: 開頭=內聯 HTML（禁腳本）；script: 開頭=內聯 HTML（允許 JS）';
    default:
      return 'https://example.com';
  }
}

String _contentLabel(String kind) {
  switch (kind) {
    case 'route':
      return '內部路由';
    case 'action':
      return '內置動作';
    case 'tab':
      return 'Tab 目標';
    case 'mini':
      return '小應用 / 包名';
    default:
      return '鏈接地址';
  }
}

/// 新增 / 編輯欄目的對話框。
class _ColumnDialog extends StatefulWidget {
  final DiscoverColumnDto? initial;
  const _ColumnDialog({this.initial});

  @override
  State<_ColumnDialog> createState() => _ColumnDialogState();
}

class _ColumnDialogState extends State<_ColumnDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _icon;
  late final TextEditingController _content;
  late final TextEditingController _sort;
  String _kind = 'link';
  String? _action;
  String? _tabTarget;
  bool _enabled = true;
  bool _pinned = false;

  /// 小應用 / 包名類型可能填寫較長的內聯 HTML，需要用多行輸入框。
  bool get _isMultilineContent => _kind == 'mini';

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _title = TextEditingController(text: c?.title ?? '');
    _icon = TextEditingController(text: c?.icon ?? '');
    _content = TextEditingController(text: c?.content ?? '');
    _sort = TextEditingController(text: (c?.sort ?? 0).toString());
    _kind = c?.kind ?? 'link';
    _action = c?.content ?? 'scan';
    _tabTarget =
        (c?.kind == 'tab' && (c?.content?.isNotEmpty ?? false)) ? c!.content : 'chat';
    _enabled = c?.enabled ?? true;
    _pinned = c?.pinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _icon.dispose();
    _content.dispose();
    _sort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? '新增欄目' : '編輯欄目'),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          // 小應用類型為多行輸入，需限制高度避免溢出屏幕。
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldGroup(
                  icon: Icons.text_fields,
                  label: '基本信息',
                  children: [
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: '欄目名稱',
                        hintText: '如：百度一下',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '請輸入欄目名稱' : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _icon,
                      decoration: const InputDecoration(
                        labelText: '圖標',
                        hintText: '單個字符或 emoji，如 🔗 / 公',
                        prefixIcon: Icon(Icons.emoji_symbols_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _FieldGroup(
                  icon: Icons.category_outlined,
                  label: '類型與內容',
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _kind,
                      decoration: const InputDecoration(
                        labelText: '欄目類型',
                        prefixIcon: Icon(Icons.segment),
                      ),
                      items: _kinds.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Row(
                                  children: [
                                    Icon(_kindIcon(e.key),
                                        size: 18, color: AppTheme.primary),
                                    const SizedBox(width: 10),
                                    Text(e.value),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _kind = v ?? 'link'),
                    ),
                    const SizedBox(height: 18),
                    if (_kind == 'action')
                      DropdownButtonFormField<String>(
                        initialValue: _action,
                        decoration: const InputDecoration(
                          labelText: '內置動作',
                          prefixIcon: Icon(Icons.flash_on_outlined),
                        ),
                        items: _actions.entries
                            .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.radio_button_unchecked,
                                          size: 16, color: AppTheme.primary),
                                      const SizedBox(width: 10),
                                      Text(e.value),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _action = v),
                      )
                    else if (_kind == 'tab')
                      DropdownButtonFormField<String>(
                        initialValue: _tabTarget,
                        decoration: const InputDecoration(
                          labelText: 'Tab 目標',
                          prefixIcon: Icon(Icons.push_pin_outlined),
                        ),
                        items: _tabTargets.entries
                            .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.tab_outlined,
                                          size: 16, color: AppTheme.primary),
                                      const SizedBox(width: 10),
                                      Text(e.value),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _tabTarget = v),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _content,
                            decoration: InputDecoration(
                              labelText: _contentLabel(_kind),
                              hintText: _contentHint(_kind),
                              hintMaxLines: 3,
                              alignLabelWithHint: _isMultilineContent,
                              prefixIcon: _isMultilineContent
                                  ? const Icon(Icons.code)
                                  : const Icon(Icons.link_outlined),
                            ),
                            // 小應用 / 包名可能填寫較長的內聯 HTML，改為多行輸入。
                            minLines: _isMultilineContent ? 5 : 1,
                            maxLines: _isMultilineContent ? 12 : 1,
                            keyboardType: _isMultilineContent
                                ? TextInputType.multiline
                                : TextInputType.url,
                            textInputAction: _isMultilineContent
                                ? TextInputAction.newline
                                : TextInputAction.next,
                            textAlignVertical: TextAlignVertical.top,
                          ),
                          if (_isMultilineContent) ...[
                            const SizedBox(height: 10),
                            _TipCard(children: [
                              _TipRow(Icons.info_outline,
                                  'html: 開頭 = 內聯 HTML（禁止腳本，表單 target=_blank）'),
                              const SizedBox(height: 6),
                              _TipRow(Icons.warning_amber_outlined,
                                  'script: 開頭 = 允許 JS 腳本，請謹慎使用'),
                            ]),
                          ],
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _FieldGroup(
                  icon: Icons.settings_outlined,
                  label: '其他設置',
                  children: [
                    TextFormField(
                      controller: _sort,
                      decoration: const InputDecoration(
                        labelText: '排序權重',
                        hintText: '數字越小越靠前',
                        prefixIcon: Icon(Icons.format_list_numbered),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '請輸入排序';
                        if (int.tryParse(v.trim()) == null) return '需為整數';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CheckboxListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: const Text('固定到底部導航'),
                        subtitle: const Text(
                          '開啟後將作為客戶端底部 Tab 顯示',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSub),
                        ),
                        secondary: const Icon(Icons.push_pin,
                            color: Colors.amber),
                        value: _pinned,
                        onChanged: (v) => setState(() => _pinned = v ?? false),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CheckboxListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: const Text('啟用欄目'),
                        subtitle: const Text(
                          '關閉後該欄目不會在用戶端顯示',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSub),
                        ),
                        secondary: const Icon(Icons.visibility,
                            color: AppTheme.primary),
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v ?? true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'title': _title.text.trim(),
              'icon': _icon.text.trim(),
              'kind': _kind,
              'content': _kind == 'action'
                  ? _action
                  : (_kind == 'tab' ? _tabTarget : _content.text.trim()),
              'sort': int.parse(_sort.text.trim()),
              'enabled': _enabled,
              'pinned': _pinned,
            });
          },
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('保存'),
        ),
      ],
    );
  }
}

/// 分組卡片：為表單欄位提供標題與內邊距，減少擁擠感。
class _FieldGroup extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Widget> children;
  const _FieldGroup({required this.icon, required this.label, required this.children});

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
class _TipCard extends StatelessWidget {
  final List<Widget> children;
  const _TipCard({required this.children});

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

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow(this.icon, this.text);

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
            style: const TextStyle(fontSize: 12, color: AppTheme.textMain, height: 1.4),
          ),
        ),
      ],
    );
  }
}
