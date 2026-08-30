import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../providers/auth_provider.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  List<AuditLogDto> _items = [];
  int _total = 0;
  int _page = 1;
  final int _pageSize = 20;
  final String _q = '';
  bool _loading = false;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<AuthProvider>().api.get(
        '/api/admin/audit?q=${Uri.encodeComponent(_q)}&page=$_page&pageSize=$_pageSize',
      );
      if (mounted) {
        setState(() {
          _items = (data['items'] as List)
              .map((e) => AuditLogDto.fromJson(e))
              .toList();
          _total = data['total'];
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '加载失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_total / _pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '审计日志',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: '搜索动作 / 操作人',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) {
                    _page = 1;
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  _page = 1;
                  _load();
                },
                child: const Text('搜索'),
              ),
              const Spacer(),
              Text('共 $_total 条'),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.red.shade50,
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          Expanded(
            child: Card(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('时间')),
                          DataColumn(label: Text('操作人')),
                          DataColumn(label: Text('动作')),
                          DataColumn(label: Text('目标')),
                          DataColumn(label: Text('详情')),
                          DataColumn(label: Text('IP')),
                        ],
                        rows: _items
                            .map(
                              (a) => DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      a.at.toLocal().toString().split('.')[0],
                                    ),
                                  ),
                                  DataCell(Text(a.adminUserName)),
                                  DataCell(Text(a.action)),
                                  DataCell(Text(a.target ?? '-')),
                                  DataCell(Text(a.detail ?? '-')),
                                  DataCell(Text(a.ip ?? '-')),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _page > 1
                    ? () {
                        _page--;
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('第 $_page / ${totalPages == 0 ? 1 : totalPages} 页'),
              IconButton(
                onPressed: _page < totalPages
                    ? () {
                        _page++;
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
