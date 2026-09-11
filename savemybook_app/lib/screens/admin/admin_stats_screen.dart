import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  static const _ranges = [(days: 7, label: '近 7 天'), (days: 30, label: '近 30 天')];

  final ApiService _api = ApiService();
  AdminStats _stats = AdminStats.empty;
  int _days = 7;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final stats = await _api.fetchAdminStats(days: _days);
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          const AppHeader(title: '營運報表', icon: Icons.insights_rounded),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                        children: [
                          _buildRangePicker(c),
                          const SizedBox(height: 16),
                          _buildSummary(c),
                          const SizedBox(height: 16),
                          _buildChart(c, '每日訂單量', (p) => p.orders.toDouble(), c.accent),
                          const SizedBox(height: 16),
                          _buildChart(c, '每日成交金額', (p) => p.revenue, c.success),
                          const SizedBox(height: 16),
                          _buildChart(c, '每日新增會員', (p) => p.newUsers.toDouble(), c.warning),
                          const SizedBox(height: 16),
                          _buildTopCategories(c),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangePicker(AppColors c) {
    return Row(
      children: [
        for (final r in _ranges) ...[
          GestureDetector(
            onTap: () {
              if (_days == r.days) return;
              setState(() => _days = r.days);
              _load();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _days == r.days ? c.accent : c.categoryChip,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                r.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: _days == r.days ? FontWeight.bold : FontWeight.w500,
                  color: _days == r.days ? Colors.white : c.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _buildSummary(AppColors c) {
    final totalOrders = _stats.series.fold<int>(0, (sum, p) => sum + p.orders);
    final totalUsers = _stats.series.fold<int>(0, (sum, p) => sum + p.newUsers);
    final totalBooks = _stats.series.fold<int>(0, (sum, p) => sum + p.newBooks);

    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatTile(
                label: '新增訂單',
                value: AnimatedCount(
                  value: totalOrders.toDouble(),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.accent),
                ),
              ),
              const VerticalDivider1(),
              StatTile(
                label: '新增會員',
                value: AnimatedCount(
                  value: totalUsers.toDouble(),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.accent),
                ),
              ),
              const VerticalDivider1(),
              StatTile(
                label: '新上架書籍',
                value: AnimatedCount(
                  value: totalBooks.toDouble(),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.accent),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.paid_outlined, color: c.success),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '已完成交易額',
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    AnimatedCount(
                      value: _stats.completedRevenue,
                      prefix: '\$',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_stats.completedOrderCount} 筆',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 以 Container 高度直接畫長條圖，不引進圖表套件。
  Widget _buildChart(
    AppColors c,
    String title,
    double Function(AdminStatPoint) pick,
    Color color,
  ) {
    final points = _stats.series;
    if (points.isEmpty) return const SizedBox.shrink();

    final values = points.map(pick).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '最高 ${maxValue.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 11, color: c.textHint),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < points.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (values[i] > 0)
                            Text(
                              values[i].toStringAsFixed(0),
                              style: TextStyle(fontSize: 9, color: c.textHint),
                            ),
                          const SizedBox(height: 2),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: values[i] / safeMax),
                            duration: Duration(milliseconds: 500 + i * 30),
                            curve: Curves.easeOutCubic,
                            builder: (_, value, _) => Container(
                              height: (value * 76).clamp(2.0, 76.0),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: values[i] > 0 ? 0.85 : 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _dayLabel(points[i].date),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(fontSize: 8, color: c.textHint),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dayLabel(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length < 3) return isoDate;
    // 30 天的時候標籤會擠在一起，只留日期。
    return _days > 14 ? parts[2] : '${int.parse(parts[1])}/${int.parse(parts[2])}';
  }

  Widget _buildTopCategories(AppColors c) {
    if (_stats.topCategories.isEmpty) return const SizedBox.shrink();
    final max = _stats.topCategories.first.count;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '熱門分類（依上架數）',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          const SizedBox(height: 14),
          for (final item in _stats.topCategories) ...[
            Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textPrimary),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: max == 0 ? 0 : item.count / max),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: c.inputFill,
                        valueColor: AlwaysStoppedAnimation(c.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${item.count}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.accent),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
