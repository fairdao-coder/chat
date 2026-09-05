import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/user_dto.dart';
import '../providers/core_providers.dart';
import '../widgets/app_avatar.dart';

/// 「聯繫客服」底部彈窗：拉取當前在線客服帳號，用戶手動選擇其一進入私聊。
/// 客服帳號免好友關係即可對話（服務端對 ServiceAgents 表中的客服接收方豁免好友校驗）。
class ServiceAgentsSheet {
  /// 展示在線客服列表；用戶選定後跳轉到對應私聊頁。返回選中的客服，未選返回 null。
  static Future<UserDto?> show(BuildContext context) async {
    final result = await showModalBottomSheet<UserDto>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => const _ServiceAgentsBody(),
    );
    return result;
  }
}

class _ServiceAgentsBody extends ConsumerStatefulWidget {
  const _ServiceAgentsBody();

  @override
  ConsumerState<_ServiceAgentsBody> createState() => _ServiceAgentsBodyState();
}

class _ServiceAgentsBodyState extends ConsumerState<_ServiceAgentsBody> {
  List<UserDto> _agents = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiProvider);
      final list = await api.getServiceAgents();
      if (mounted) {
        setState(() {
          _agents = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = context.tr;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.support_agent_rounded, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      t('联系客服'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(_error!, style: TextStyle(color: cs.error)),
                      TextButton(
                        onPressed: () {
                          setState(() => _loading = true);
                          _load();
                        },
                        child: Text(t('重试')),
                      ),
                    ],
                  ),
                )
              else if (_agents.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    t('当前没有客服在线'),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _agents.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final a = _agents[i];
                      return ListTile(
                        leading: AppAvatar(
                          imageUrl: a.avatarUrl,
                          name: a.nickName,
                          online: a.isOnline,
                          size: 46,
                        ),
                        title: Text(a.nickName),
                        subtitle: Text('@${a.userName}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          Navigator.of(context).pop(a);
                          // 跳轉私聊；service=1 標記讓 ChatPage 隱藏「加好友」並顯示客服標識。
                          final profile =
                              await ref.read(apiProvider).getUserProfile(a.id);
                          if (context.mounted) {
                            context.push(
                              '/chat?friendId=${a.id}&name=${Uri.encodeComponent(a.nickName)}&service=${profile.isService ? 1 : 0}',
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
