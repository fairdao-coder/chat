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
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primarySoft,
                              child: c.icon?.isNotEmpty == true
                                  ? Text(c.icon!, style: const TextStyle(fontSize: 16))
                                  : const Icon(Icons.link, size: 18),
                            ),
                            title: Text(c.title),
                            subtitle: c.link?.isNotEmpty == true
                                ? Text(c.link!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12))
                                : const Text('未設置鏈接',
                                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!c.enabled)
                                  const Chip(
                                    label: Text('已隱藏', style: TextStyle(fontSize: 11)),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Color(0xFFEEEEEE),
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
  late final TextEditingController _link;
  late final TextEditingController _sort;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _title = TextEditingController(text: c?.title ?? '');
    _icon = TextEditingController(text: c?.icon ?? '');
    _link = TextEditingController(text: c?.link ?? '');
    _sort = TextEditingController(text: (c?.sort ?? 0).toString());
    _enabled = c?.enabled ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _icon.dispose();
    _link.dispose();
    _sort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? '新增欄目' : '編輯欄目'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: '欄目名稱 *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '請輸入欄目名稱' : null,
                ),
                TextFormField(
                  controller: _icon,
                  decoration: const InputDecoration(
                    labelText: '圖標（可選，單個字符/emoji）',
                    hintText: '如 🔗 或 公',
                  ),
                ),
                TextFormField(
                  controller: _link,
                  decoration: const InputDecoration(
                    labelText: '鏈接地址',
                    hintText: 'https://example.com',
                  ),
                  keyboardType: TextInputType.url,
                ),
                TextFormField(
                  controller: _sort,
                  decoration: const InputDecoration(labelText: '排序（越小越靠前）'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '請輸入排序';
                    if (int.tryParse(v.trim()) == null) return '需為整數';
                    return null;
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('啟用（在用戶端顯示）'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v ?? true),
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
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'title': _title.text.trim(),
              'icon': _icon.text.trim(),
              'link': _link.text.trim(),
              'sort': int.parse(_sort.text.trim()),
              'enabled': _enabled,
            });
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
