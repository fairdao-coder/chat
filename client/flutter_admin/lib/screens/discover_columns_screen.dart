import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/discover_column_dialog.dart';
import '../widgets/discover_column_meta.dart';

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

  /// 當前已固定的欄目數量。
  int get _pinnedCount => _items.where((e) => e.pinned).length;

  static const int _maxPinned = 5;

  /// 是否允許把 [col] 固定：新增（col 為 null）或本身是已固定欄目時不受限；
  /// 把「未固定 -> 固定」時，已固定數必須 < 上限。
  bool _canPin(DiscoverColumnDto? col) =>
      col?.pinned == true || _pinnedCount < _maxPinned;

  /// 固定欄目已達上限時的提示。
  void _pinLimitToast() =>
      _toast('固定欄目最多 $_maxPinned 個，請先取消其它欄目的固定');

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
      builder: (_) => ColumnDialog(initial: col),
    );
    if (result == null) return;

    // 新增且要固定、或編輯改為固定且達上限：提前攔截，避免無效請求。
    final wantPin = result['pinned'] == true;
    if (wantPin && !_canPin(col)) {
      _pinLimitToast();
      return;
    }

    try {
      if (col == null) {
        await api.createDiscover(result);
      } else {
        await api.updateDiscover(col.id, result);
      }
      if (mounted) {
        _toast(col == null ? '已新增' : '已保存');
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) _toast('操作失敗：${e.message}');
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
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
        _toast('已刪除');
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) _toast('刪除失敗：${e.message}');
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
        // 快速開關是全量 PUT，必須原樣帶回譯文，否則後端會把多語言名稱清空。
        'titleI18n': col.titleI18n,
        'icon': col.icon,
        'kind': col.kind,
        'content': col.content,
        'sort': col.sort,
        'enabled': enabled ?? col.enabled,
        'pinned': pinned ?? col.pinned,
      };

  /// 快速切換「啟用」/「固定」開關。
  ///
  /// 兩個開關的請求與回滾邏輯完全一致，原先是兩份近乎重複的實現，
  /// 合併後只需在一處維護樂觀更新與失敗回滾。
  Future<void> _toggle(
    DiscoverColumnDto col, {
    bool? enabled,
    bool? pinned,
  }) async {
    if (!_canWrite) return;
    // 切到「固定」且已達上限：直接攔截。
    if (pinned == true && !_canPin(col)) {
      _pinLimitToast();
      return;
    }
    final api = context.read<AuthProvider>().api;
    final idx = _items.indexWhere((e) => e.id == col.id);

    // 樂觀更新，提升交互反饋速度。
    final optimistic = col.copyWith(
      enabled: enabled ?? col.enabled,
      pinned: pinned ?? col.pinned,
    );
    if (mounted && idx >= 0) setState(() => _items[idx] = optimistic);

    try {
      await api.updateDiscover(
          col.id, _fullPayload(col, enabled: enabled, pinned: pinned));
    } catch (e) {
      if (!mounted) return;
      // 失敗回滾為原值，避免界面與服務端狀態不一致。
      if (idx >= 0) setState(() => _items[idx] = col);
      _toast('操作失敗：${e is ApiException ? e.message : e}');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                        itemBuilder: (_, i) => _ColumnTile(
                          column: _items[i],
                          canWrite: _canWrite,
                          onEdit: () => _edit(_items[i]),
                          onDelete: () => _delete(_items[i]),
                          onTogglePinned: () =>
                              _toggle(_items[i], pinned: !_items[i].pinned),
                          onToggleEnabled: () =>
                              _toggle(_items[i], enabled: !_items[i].enabled),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// 單個欄目行。
///
/// 列表項原先是嵌在 builder 裡的一大段 widget 樹，提取為獨立 widget 後
/// 列表重建時只重建行本身，也便於單獨預覽與測試。
class _ColumnTile extends StatelessWidget {
  final DiscoverColumnDto column;
  final bool canWrite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePinned;
  final VoidCallback onToggleEnabled;

  const _ColumnTile({
    required this.column,
    required this.canWrite,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePinned,
    required this.onToggleEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final c = column;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.primarySoft,
        child: c.icon?.isNotEmpty == true
            ? Text(c.icon!, style: const TextStyle(fontSize: 16))
            : Icon(columnKindIcon(c.kind), size: 18),
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
        '${columnKindLabel(c.kind)} · ${c.content ?? ''}',
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
          if (canWrite)
            IconButton(
              icon: Icon(
                c.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: c.pinned ? Colors.amber.shade700 : Colors.grey,
              ),
              tooltip: c.pinned ? '取消固定' : '固定到底部導航',
              onPressed: onTogglePinned,
            ),
          if (canWrite)
            IconButton(
              icon: Icon(
                c.enabled ? Icons.visibility : Icons.visibility_off,
                color: c.enabled ? AppTheme.primary : Colors.grey,
              ),
              tooltip: c.enabled ? '停用' : '啟用',
              onPressed: onToggleEnabled,
            ),
          if (canWrite) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}
