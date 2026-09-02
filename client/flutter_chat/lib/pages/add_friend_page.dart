import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../l10n/app_localizations.dart';
import '../models/user_dto.dart';
import '../providers/core_providers.dart';
import '../widgets/app_avatar.dart';
import '../widgets/empty_state.dart';

class AddFriendPage extends ConsumerStatefulWidget {
  const AddFriendPage({super.key});

  @override
  ConsumerState<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends ConsumerState<AddFriendPage> {
  final _ctrl = TextEditingController();
  List<UserDto> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  final Set<String> _sent = {};

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    try {
      _results = await ref.read(apiProvider).searchUsers(q);
    } on ApiException catch (e) {
      _toast(e.message);
      _results = [];
    } catch (e) {
      _toast(e.toString());
      _results = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(UserDto u) async {
    if (_sent.contains(u.id)) return;
    try {
      await ref.read(apiProvider).sendFriendRequest(u.id);
      // await 之後 widget 可能已被卸載（用戶已返回），使用 context 前必須檢查。
      if (!mounted) return;
      setState(() => _sent.add(u.id));
      _toast('${context.tr('已向')} ${u.nickName} ${context.tr('发送好友请求')}');
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString());
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('添加好友'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          hintText: context.tr('搜索用户名 / 昵称'),
                          hintStyle: TextStyle(color: cs.onSurfaceVariant),
                          prefixIcon: Icon(Icons.search,
                              color: cs.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: cs.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        style: TextStyle(color: cs.onSurface),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _search,
                      icon: const Icon(Icons.search),
                      label: Text(context.tr('搜索')),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? EmptyState(
                    icon: Icons.search,
                    title: _ctrl.text.isEmpty
                        ? context.tr('开始搜索')
                        : context.tr('未找到用户'),
                    subtitle: _ctrl.text.isEmpty
                        ? context.tr('输入用户名或昵称，找到你想添加的人')
                        : context.tr('换个关键词试试'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 4),
                    itemBuilder: (c, i) {
                      final u = _results[i];
                      final sent = _sent.contains(u.id);
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                          child: Row(
                            children: [
                              AppAvatar(
                                imageUrl: u.avatarUrl,
                                name: u.nickName,
                                size: 48,
                                online: u.isOnline ? true : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u.nickName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '@${u.userName}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              sent
                                  ? OutlinedButton(
                                      onPressed: null,
                                      child: Text(context.tr('已发送')),
                                    )
                                  : FilledButton(
                                      onPressed: () => _add(u),
                                      child: Text(context.tr('添加')),
                                    ),
                            ],
                          ),
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
