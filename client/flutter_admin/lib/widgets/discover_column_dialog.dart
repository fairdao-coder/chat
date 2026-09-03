import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../theme.dart';
import 'discover_column_meta.dart';
import 'form_widgets.dart';

/// 欄目名稱支持的語言（與客戶端 AppLocalizations 的四種語言一致）。
/// 鍵為 BCP47 風格語言鍵，值為後台界面上的標籤。
const Map<String, String> kTitleI18nLanguages = {
  'zh-TW': '繁體中文',
  'zh-CN': '简体中文',
  'en': 'English',
  'es': 'Español',
};

/// 新增 / 編輯欄目的對話框。
///
/// 返回 `Map<String, dynamic>` 作為請求體；取消則返回 null。
class ColumnDialog extends StatefulWidget {
  final DiscoverColumnDto? initial;

  const ColumnDialog({super.key, this.initial});

  @override
  State<ColumnDialog> createState() => _ColumnDialogState();
}

class _ColumnDialogState extends State<ColumnDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _icon;
  late final TextEditingController _content;
  late final TextEditingController _sort;
  /// 多語言標題：語言鍵 -> 輸入框（繁中/簡中/英文/西語）。
  late final Map<String, TextEditingController> _i18n;
  String _kind = 'link';
  String? _action;
  String? _tabTarget;
  bool _enabled = true;
  bool _pinned = false;

  /// 小應用 / 包名類型可能填寫較長的內聯 HTML，需要用多行輸入框。
  bool get _isMultilineContent => _kind == 'mini';

  /// 收集多語言輸入，生成 JSON 字符串；全部留空時返回 null（客戶端回退到默認名稱）。
  String? _buildTitleI18n() {
    final map = <String, String>{};
    for (final e in kTitleI18nLanguages.entries) {
      final v = (_i18n[e.key]?.text ?? '').trim();
      if (v.isNotEmpty) map[e.key] = v;
    }
    return map.isEmpty ? null : jsonEncode(map);
  }

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _title = TextEditingController(text: c?.title ?? '');
    _icon = TextEditingController(text: c?.icon ?? '');
    _content = TextEditingController(text: c?.content ?? '');
    _sort = TextEditingController(text: (c?.sort ?? 0).toString());
    final existing = c?.i18nMap ?? {};
    _i18n = {
      for (final e in kTitleI18nLanguages.entries)
        e.key: TextEditingController(text: existing[e.key] ?? ''),
    };
    _kind = c?.kind ?? 'link';
    _action = c?.content ?? 'scan';
    // 若已固定且 content 為內置標識，回顯到「固定目標」下拉。
    _tabTarget =
        (c != null && (c.content?.isNotEmpty ?? false)) ? c.content : 'chat';
    _enabled = c?.enabled ?? true;
    _pinned = c?.pinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _icon.dispose();
    _content.dispose();
    _sort.dispose();
    for (final c in _i18n.values) {
      c.dispose();
    }
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
                FieldGroup(
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
                    const SizedBox(height: 6),
                    const Text(
                      '上方名稱為默認顯示；下面的譯文留空時，客戶端會自動回退到它。',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSub),
                    ),
                    const SizedBox(height: 14),
                    // 多語言標題：內置欄目即使不填也能隨 App 語言切換，
                    // 自定義欄目則靠這裡配置的譯文。
                    Row(
                      children: [
                        Icon(Icons.translate,
                            size: 16, color: AppTheme.activePrimary),
                        const SizedBox(width: 6),
                        const Text(
                          '多語言名稱',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final e in kTitleI18nLanguages.entries) ...[
                      TextFormField(
                        controller: _i18n[e.key],
                        decoration: InputDecoration(
                          labelText: e.value,
                          isDense: true,
                          prefixIcon: const Icon(Icons.language, size: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 8),
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
                FieldGroup(
                  icon: Icons.category_outlined,
                  label: '類型與內容',
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _kind,
                      decoration: const InputDecoration(
                        labelText: '欄目類型',
                        prefixIcon: Icon(Icons.segment),
                      ),
                      items: kColumnKinds.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Row(
                                  children: [
                                    Icon(columnKindIcon(e.key),
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
                    if (_pinned)
                      // 固定到底部導航：選擇內置目標（其標識寫入 content）。
                      DropdownButtonFormField<String>(
                        initialValue: _tabTarget,
                        decoration: const InputDecoration(
                          labelText: '固定目標（內置頁）',
                          prefixIcon: Icon(Icons.push_pin_outlined),
                        ),
                        items: kTabTargets.entries
                            .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Row(
                                    children: [
                                      Icon(Icons.tab_outlined,
                                          size: 16, color: AppTheme.activePrimary),
                                      const SizedBox(width: 10),
                                      Text(e.value),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _tabTarget = v),
                      )
                    else if (_kind == 'action')
                      DropdownButtonFormField<String>(
                        initialValue: _action,
                        decoration: const InputDecoration(
                          labelText: '內置動作',
                          prefixIcon: Icon(Icons.flash_on_outlined),
                        ),
                        items: kColumnActions.entries
                            .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Row(
                                    children: [
                                      Icon(Icons.radio_button_unchecked,
                                          size: 16, color: AppTheme.activePrimary),
                                      const SizedBox(width: 10),
                                      Text(e.value),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _action = v),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _content,
                            decoration: InputDecoration(
                              labelText: columnContentLabel(_kind),
                              hintText: columnContentHint(_kind),
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
                            TipCard(children: [
                              TipRow(Icons.info_outline,
                                  'html: 開頭 = 內聯 HTML（禁止腳本，表單 target=_blank）'),
                              const SizedBox(height: 6),
                              TipRow(Icons.warning_amber_outlined,
                                  'script: 開頭 = 允許 JS 腳本，請謹慎使用'),
                            ]),
                          ],
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                FieldGroup(
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
                          style:
                              TextStyle(fontSize: 12, color: AppTheme.textSub),
                        ),
                        secondary:
                            const Icon(Icons.push_pin, color: Colors.amber),
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
                          style:
                              TextStyle(fontSize: 12, color: AppTheme.textSub),
                        ),
                        secondary: Icon(Icons.visibility,
                            color: AppTheme.activePrimary),
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
              'titleI18n': _buildTitleI18n(),
              'icon': _icon.text.trim(),
              'kind': _kind,
              'content': _pinned
                  ? _tabTarget
                  : (_kind == 'action' ? _action : _content.text.trim()),
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
