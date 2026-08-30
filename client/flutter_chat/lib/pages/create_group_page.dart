import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/api_client.dart';
import '../l10n/app_localizations.dart';
import '../models/user_dto.dart';
import '../providers/conversations_provider.dart';
import '../providers/core_providers.dart';
import '../widgets/app_avatar.dart';

class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final _nameCtrl = TextEditingController();
  List<UserDto> _friends = [];
  final Set<String> _selected = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _friends = await ref.read(apiProvider).getFriends();
      if (mounted) setState(() {});
    } catch (e) {
      _toast('${context.tr('加载好友失败')}: $e');
    }
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast(context.tr('请输入群名称'));
      return;
    }
    if (_selected.isEmpty) {
      _toast(context.tr('请至少选择一名成员'));
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(apiProvider).createGroup(name, _selected.toList());
      ref.invalidate(conversationsProvider);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(String id, bool v) => setState(() {
        if (v) {
          _selected.add(id);
        } else {
          _selected.remove(id);
        }
      });

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('创建群聊'))),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('群名称'),
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      hintText: context.tr('例如：项目交流群'),
                      prefixIcon: const Icon(Icons.group_add),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${context.tr('已选')} ${_selected.length} ${context.tr('人')}',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selected.map((id) {
                      final f = _friends.firstWhere(
                        (x) => x.id == id,
                        orElse: () => _friends.first,
                      );
                      return Chip(
                        avatar: CircleAvatar(
                          radius: 12,
                          backgroundColor: cs.primary.withValues(alpha: 0.18),
                          child: Text(
                            f.nickName.isNotEmpty
                                ? f.nickName.trim()[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                            ),
                          ),
                        ),
                        label: Text(f.nickName),
                        onDeleted: () => _toggle(id, false),
                        deleteIconColor: cs.onSurfaceVariant,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${context.tr('选择成员')}（${_selected.length}/${_friends.length}）',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _friends.length,
              itemBuilder: (c, i) {
                final f = _friends[i];
                final sel = _selected.contains(f.id);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: sel ? cs.primary.withValues(alpha: 0.08) : null,
                  child: ListTile(
                    leading: AppAvatar(
                      imageUrl: f.avatarUrl,
                      name: f.nickName,
                      size: 46,
                      online: f.isOnline ? true : null,
                    ),
                    title: Text(f.nickName),
                    subtitle: Text('@${f.userName}'),
                    trailing: Checkbox(
                      value: sel,
                      onChanged: (v) => _toggle(f.id, v ?? false),
                    ),
                    onTap: () => _toggle(f.id, !sel),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _create,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(context.tr('创建群聊')),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
