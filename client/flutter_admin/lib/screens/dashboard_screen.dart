import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardStats? _stats;
  bool _loading = true;
  String? _error;

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
      final data = await context.read<AuthProvider>().api.get('/api/admin/dashboard/stats');
      _stats = DashboardStats.fromJson(data);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = '加載失敗：$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('重試')),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final s = _stats!;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('數據概覽', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _card(StatCard(title: '註冊用戶', value: '${s.totalUsers}', icon: Icons.people, color: AppTheme.primary)),
                _card(StatCard(title: '今日新增', value: '${s.newUsersToday}', icon: Icons.person_add, color: Colors.green)),
                _card(StatCard(title: '在線用戶', value: '${s.onlineUsers}', icon: Icons.circle, color: Colors.teal)),
                _card(StatCard(title: '封禁用戶', value: '${s.bannedUsers}', icon: Icons.block, color: Colors.red)),
                _card(StatCard(title: '總消息', value: '${s.totalMessages}', icon: Icons.message, color: Colors.orange)),
                _card(StatCard(title: '今日消息', value: '${s.messagesToday}', icon: Icons.chat_bubble, color: Colors.purple)),
                _card(StatCard(title: '群組數', value: '${s.totalGroups}', icon: Icons.group_work, color: Colors.indigo)),
                _card(StatCard(title: '好友關係', value: '${s.totalFriendships}', icon: Icons.handshake, color: Colors.blue)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _chartCard('近 14 天註冊趨勢', _buildLine(s.signups))),
                const SizedBox(width: 16),
                Expanded(child: _chartCard('近 14 天消息量', _buildBar(s.messages))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Widget child) => SizedBox(width: 230, child: child);

  Widget _chartCard(String title, Widget chart) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              SizedBox(height: 220, child: chart),
            ],
          ),
        ),
      );

  Widget _buildLine(List<DailyCount> data) {
    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.count.toDouble())).toList();
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primary,
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: AppTheme.primary.withAlpha(30)),
          ),
        ],
        titlesData: _titles(data.length),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, horizontalInterval: 1),
      ),
    );
  }

  Widget _buildBar(List<DailyCount> data) {
    final groups = data.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(toY: e.value.count.toDouble(), color: Colors.orange, width: 10, borderRadius: BorderRadius.circular(3)),
        ])).toList();
    return BarChart(
      BarChartData(
        barGroups: groups,
        titlesData: _titles(data.length),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, horizontalInterval: 1),
      ),
    );
  }

  FlTitlesData _titles(int n) => FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 2,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= n) return const SizedBox.shrink();
              return Text('${i + 1}', style: const TextStyle(fontSize: 10, color: AppTheme.textSub));
            },
          ),
        ),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: AppTheme.textSub)))),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      );
}
