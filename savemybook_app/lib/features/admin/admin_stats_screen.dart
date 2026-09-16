import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import 'admin_layout.dart';
import '../../utils/motion.dart';
import '../../i18n/strings.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  List<({int days, String label})> get _ranges =>
      [(days: 7, label: S.last7Days), (days: 30, label: S.last30Days)];

  final ApiService _api = ApiService();
  AdminStats _stats = AdminStats.empty;
  int _days = 7;
  bool _isLoading = true;
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    final seq = ++_loadSeq;
    if (showLoading) setState(() => _isLoading = true);
    final stats = await _api.fetchAdminStats(days: _days);
    if (!mounted || seq != _loadSeq) return;
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
      body: AdminLayout(
        builder: (context, frame) => Column(
          children: [
            AppHeader(title: S.reports, icon: Icons.insights_rounded),
            Padding(
              padding: frame.inset(const EdgeInsets.fromLTRB(20, 16, 20, 0), maxWidth: 1200),
              child: Align(alignment: Alignment.centerLeft, child: _buildRangePicker(c)),
            ),
            Expanded(
              child: SwitchIn(
                child: _isLoading
                    ? const LoadingView.list()
                    : RefreshIndicator(
                        key: ValueKey('stats_$_days'),
                        color: c.accent,
                        onRefresh: () => _load(showLoading: false),
                        child: _stats.series.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 60),
                                  EmptyView(
                                    icon: Icons.insights_rounded,
                                    message: S.couldnTLoadStatisticsRightNow,
                                    actionLabel: S.refresh,
                                    onAction: _load,
                                  ),
                                ],
                              )
                            : ListView(
                                padding: frame.inset(const EdgeInsets.fromLTRB(20, 16, 20, 40), maxWidth: 1200),
                                children: frame.isWide ? _buildWide(c) : [
                                  for (final (i, section) in [
                                    _buildSummary(c),
                                    _buildChart(c, S.ordersPerDay, (p) => p.orders.toDouble(), c.accent),
                                    _buildChart(c, S.revenuePerDay, (p) => p.revenue, c.success),
                                    _buildChart(c, S.newMembersPerDay, (p) => p.newUsers.toDouble(), c.warning),
                                    _buildTopCategories(c),
                                  ].indexed)
                                    Padding(
                                      padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
                                      child: RevealOnScroll(index: i, child: section),
                                    ),
                                ],
                              ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWide(AppColors c) {
    return [
      RevealOnScroll(child: _buildSummary(c, wide: true)),
      const SizedBox(height: 16),
      RevealOnScroll(
        index: 1,
        child: AdminColumns(
          columns: [
            [
              _buildChart(c, S.ordersPerDay, (p) => p.orders.toDouble(), c.accent, height: 170),
              _buildChart(c, S.newMembersPerDay, (p) => p.newUsers.toDouble(), c.warning, height: 170),
            ],
            [
              _buildChart(c, S.revenuePerDay, (p) => p.revenue, c.success, height: 170),
              _buildTopCategories(c),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _buildRangePicker(AppColors c) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final r in _ranges)
          PressableScale(
            scale: 0.94,
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
                borderRadius: BorderRadius.circular(16),
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
      ],
    );
  }

  Widget _buildSummary(AppColors c, {bool wide = false}) {
    final totalOrders = _stats.series.fold<int>(0, (sum, p) => sum + p.orders);
    final totalUsers = _stats.series.fold<int>(0, (sum, p) => sum + p.newUsers);
    final totalBooks = _stats.series.fold<int>(0, (sum, p) => sum + p.newBooks);

    final cards = [
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: StatTile(
                label: S.newOrders,
                value: AnimatedCount(
                  value: totalOrders.toDouble(),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.accent),
                ),
              ),
            ),
            const VerticalDivider1(),
            Expanded(
              child: StatTile(
                label: S.newMembers,
                value: AnimatedCount(
                  value: totalUsers.toDouble(),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.accent),
                ),
              ),
            ),
            const VerticalDivider1(),
            Expanded(
              child: StatTile(
                label: S.newListings,
                value: AnimatedCount(
                  value: totalBooks.toDouble(),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.accent),
                ),
              ),
            ),
          ],
        ),
      ),
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
                    S.completedRevenue,
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedCount(
                      value: _stats.completedRevenue.roundToDouble(),
                      prefix: '\$',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                S.p0Orders(_stats.completedOrderCount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    ];
    if (wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: cards[0]),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: cards[1]),
          ],
        ),
      );
    }
    return Column(children: [cards[0], const SizedBox(height: 12), cards[1]]);
  }

  static String _compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k';
    return value.toStringAsFixed(0);
  }

  Widget _buildChart(
    AppColors c,
    String title,
    double Function(AdminStatPoint) pick,
    Color color, {
    double height = 110,
  }) {
    final points = _stats.series;
    if (points.isEmpty) return const SizedBox.shrink();

    final values = points.map(pick).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final dense = points.length > 14;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                S.peakP0(_compact(maxValue)),
                style: TextStyle(fontSize: 11, color: c.textHint),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < points.length; i++)
                  Expanded(
                    child: Tooltip(
                      message: '${_dayLabel(points[i].date, full: true)}：${values[i].toStringAsFixed(0)}',
                      triggerMode: TooltipTriggerMode.tap,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: dense ? 1 : 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              height: 12,
                              child: !dense && values[i] > 0
                                  ? FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _compact(values[i]),
                                        maxLines: 1,
                                        style: TextStyle(fontSize: 9, color: c.textHint),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 2),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: values[i] / safeMax),
                              duration: Duration(milliseconds: 500 + i * 30),
                              curve: Curves.easeOutCubic,
                              builder: (_, value, _) => AnimatedContainer(
                                duration: Motion.base,
                                curve: Motion.standard,
                                height: (value * (height - 38)).clamp(2.0, height - 38),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: values[i] > 0 ? 0.85 : 0.2),
                                  borderRadius: BorderRadius.circular(dense ? 3 : 6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 12,
                              child: !dense || i % 5 == 0 || i == points.length - 1
                                  ? FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _dayLabel(points[i].date),
                                        maxLines: 1,
                                        style: TextStyle(fontSize: 9, color: c.textHint),
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
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

  String _dayLabel(String isoDate, {bool full = false}) {
    final parts = isoDate.split('-');
    if (parts.length < 3) return isoDate;
    final month = int.tryParse(parts[1]) ?? 0;
    final day = int.tryParse(parts[2]) ?? 0;
    return full || _days <= 14 ? '$month/$day' : '$day';
  }

  Widget _buildTopCategories(AppColors c) {
    if (_stats.topCategories.isEmpty) return const SizedBox.shrink();
    final max = _stats.topCategories.first.count;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.topCategoriesByListings,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          const SizedBox(height: 14),
          for (final item in _stats.topCategories) ...[
            Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textPrimary),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
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
                SizedBox(
                  width: 44,
                  child: Text(
                    _compact(item.count.toDouble()),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.accent),
                  ),
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
