import 'package:flutter/material.dart';

import '../../i18n/strings.dart';
import '../../models/admin_models.dart';
import '../../models/support.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import 'admin_cabinet_device_screen.dart';
import 'admin_report_screen.dart';
import 'admin_workspace.dart';

typedef AdminSectionOpener = void Function(String id, {Widget? root, Widget? page});

class AdminDashboard extends StatefulWidget {
  final AdminOverview overview;
  final bool loading;

  final int generation;
  final Future<void> Function() onRefresh;
  final AdminSectionOpener onOpen;

  const AdminDashboard({
    super.key,
    required this.overview,
    required this.loading,
    required this.generation,
    required this.onRefresh,
    required this.onOpen,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ApiService _api = ApiService();
  List<DisputeCase> _disputes = [];
  List<SupportTicket> _tickets = [];
  List<Cabinet> _cabinets = [];
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _loadQueues();
  }

  @override
  void didUpdateWidget(AdminDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation) _loadQueues();
  }

  Future<void> _loadQueues() async {
    final seq = ++_loadSeq;
    final results = await Future.wait<Object>([
      _api.fetchAdminDisputes(),
      _api.fetchAdminTickets(status: 'open'),
      _api.fetchAdminCabinets(),
    ]);
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _disputes = [
        for (final d in results[0] as List<DisputeCase>)
          if (d.status != 'resolved') d,
      ];
      _tickets = results[1] as List<SupportTicket>;
      _cabinets = results[2] as List<Cabinet>;
    });
  }

  Future<void> _refresh() => Future.wait([widget.onRefresh(), _loadQueues()]);

  static List<String> _issues(Cabinet cabinet) {
    final device = cabinet.device;
    final maintenanceSlots = cabinet.slotSummary['maintenance'] ?? 0;
    return [
      if (device != null && !device.isPending && !device.online) S.deviceOffline,
      if (cabinet.isMaintenance) S.slotMaintenance else if (maintenanceSlots > 0) '${S.slotMaintenance} $maintenanceSlots',
      if (cabinet.slots.any((s) => s.needsCheck)) S.doorNeedsChecking,
      if (cabinet.slots.any((s) => (s.faultCode ?? '').isNotEmpty)) S.fault,
    ];
  }

  void _openCases() {
    final o = widget.overview;
    if (o.pendingDisputeCount > 0 || o.pendingModerationCount == 0) {
      widget.onOpen(AdminSections.disputes);
    } else {
      widget.onOpen(AdminSections.moderation, root: AdminReportScreen(initialTab: AdminReportScreen.initialTabFor(o)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          TabletToolbar(
            title: S.home,
            actions: [HeaderIconButton(icon: Icons.refresh_rounded, tooltip: S.refresh, onTap: _refresh)],
          ),
          Expanded(
            child: SwitchIn(
              child: widget.loading
                  ? const LoadingView.menu()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _refresh,
                      child: LayoutBuilder(builder: (context, constraints) => _buildContent(c, constraints.maxWidth, constraints.maxHeight)),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AppColors c, double width, double height) {
    final o = widget.overview;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final content = (width - 48).clamp(0.0, 1200.0);
    final side = (width - content) / 2;
    const gap = 16.0;
    final statColumns = content >= 4 * 150 + 3 * gap ? 4 : 2;
    final queueColumns = content >= 640 ? 2 : 1;
    final queueLength = height >= 900 ? 5 : 3;
    final abnormal = [
      for (final cabinet in _cabinets)
        if (cabinet.isActive && _issues(cabinet).isNotEmpty) cabinet,
    ];

    final stats = [
      _StatCard(
        icon: Icons.people_alt_outlined,
        label: S.members2,
        value: o.memberCount,
        onTap: () => widget.onOpen(AdminSections.members),
      ),
      _StatCard(
        icon: Icons.receipt_long_outlined,
        label: S.todaySOrders,
        value: o.todayOrderCount,
        onTap: () => widget.onOpen(AdminSections.orders),
      ),
      _StatCard(
        icon: Icons.gavel_rounded,
        label: S.openCases,
        value: o.pendingModerationCount + o.pendingDisputeCount,
        alert: true,
        onTap: _openCases,
      ),
      _StatCard(
        icon: Icons.storage_rounded,
        label: S.activeLockers,
        value: o.activeCabinetCount,
        onTap: () => widget.onOpen(AdminSections.cabinets),
      ),
    ];

    final queues = [
      _QueueCard(
        icon: Icons.gavel_rounded,
        title: S.resolveDispute,
        count: o.pendingDisputeCount,
        onOpen: () => widget.onOpen(AdminSections.disputes),
        rows: [
          for (final d in _disputes.take(queueLength))
            _QueueRow(
              leading: BookThumbnail(imageUrl: d.bookImageUrl, width: 30, height: 40, radius: 6),
              title: d.bookTitle.isEmpty ? d.orderNo : d.bookTitle,
              subtitle: S.buyerP0SellerP1(d.buyerName, d.sellerName),
              trailing: formatRelative(d.createdAt),
              onTap: () => widget.onOpen(AdminSections.disputes),
            ),
        ],
      ),
      _QueueCard(
        icon: Icons.report_gmailerrorred_outlined,
        title: S.moderation,
        count: o.pendingModerationCount,
        onOpen: () => widget.onOpen(AdminSections.moderation),
        rows: [
          for (final (icon, label, count, tab) in [
            (Icons.flag_outlined, S.report, o.pendingReportCount, 0),
            (Icons.fact_check_outlined, S.listingReview, o.pendingListingReviewCount, AdminReportScreen.listingReviewTab),
            (Icons.shield_outlined, S.scamAlerts, o.openRiskAlertCount, AdminReportScreen.riskAlertTab),
          ])
            _QueueRow(
              leading: Icon(icon, size: 20, color: c.textSecondary),
              title: label,
              count: count,
              onTap: () => widget.onOpen(AdminSections.moderation, root: AdminReportScreen(initialTab: tab)),
            ),
        ],
      ),
      _QueueCard(
        icon: Icons.support_agent_rounded,
        title: S.supportEnquiries,
        count: o.openTicketCount,
        onOpen: () => widget.onOpen(AdminSections.tickets),
        rows: [
          for (final t in _tickets.take(queueLength))
            _QueueRow(
              leading: UserAvatar(imageUrl: t.userAvatar, radius: 15),
              title: t.subject,
              subtitle: '${t.userName.isEmpty ? S.user : t.userName}・${t.categoryText}',
              trailing: formatRelative(t.updatedAt),
              onTap: () => widget.onOpen(AdminSections.tickets),
            ),
        ],
      ),
      _QueueCard(
        icon: Icons.storage_rounded,
        title: S.lockerMonitor,
        count: abnormal.length,
        warning: true,
        onOpen: () => widget.onOpen(AdminSections.cabinets),
        rows: [
          for (final cabinet in abnormal.take(queueLength))
            _QueueRow(
              leading: Icon(Icons.warning_amber_rounded, size: 20, color: c.warning),
              title: cabinet.cabinetName,
              subtitle: _issues(cabinet).join('・'),
              onTap: () => widget.onOpen(
                AdminSections.cabinets,
                page: AdminCabinetDeviceScreen(cabinetId: cabinet.cabinetId, cabinetName: cabinet.cabinetName),
              ),
            ),
        ],
      ),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(side, 20, side, 32 + bottom),
      children: [
        FadeSlideIn(child: _grid(stats, statColumns, gap, height: 84)),
        const SizedBox(height: 28),
        FadeSlideIn(
          index: 1,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              S.openCases,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary, letterSpacing: 0.5),
            ),
          ),
        ),
        for (var row = 0; row * queueColumns < queues.length; row++)
          FadeSlideIn(
            index: row + 2,
            child: Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var col = 0; col < queueColumns; col++) ...[
                      if (col > 0) const SizedBox(width: gap),
                      Expanded(
                        child: row * queueColumns + col < queues.length ? queues[row * queueColumns + col] : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _grid(List<Widget> children, int columns, double gap, {required double height}) {
    return Column(
      children: [
        for (var row = 0; row * columns < children.length; row++) ...[
          if (row > 0) SizedBox(height: gap),
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) SizedBox(width: gap),
                  Expanded(child: row * columns + col < children.length ? children[row * columns + col] : const SizedBox.shrink()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final VoidCallback onTap;
  final bool alert;

  const _StatCard({required this.icon, required this.label, required this.value, required this.onTap, this.alert = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tint = alert && value > 0 ? c.danger : c.accent;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 數字過長縮小時保持高度，各卡片的說明文字才會對齊
                SizedBox(
                  height: 30,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedCount(
                      value: value.toDouble(),
                      style: TextStyle(color: tint, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final bool warning;
  final VoidCallback onOpen;
  final List<Widget> rows;

  const _QueueCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.onOpen,
    required this.rows,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tint = count > 0 ? (warning ? c.warning : c.danger) : c.accent;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                    child: Icon(icon, color: tint, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    count > 999 ? '999+' : '$count',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: count > 0 ? tint : c.textHint),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 20, color: c.iconInactive),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: c.divider),
          // 待處理數為 0 才顯示已清空；仍有待處理但清單尚未載入（或沒有該項權限）時留白，避免互相矛盾
          if (rows.isNotEmpty)
            ...rows
          else if (count == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Icon(Icons.check_circle_outline_rounded, size: 28, color: c.success.withValues(alpha: 0.7)),
            )
          else
            const SizedBox(height: 24),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final String? trailing;
  final int? count;
  final VoidCallback onTap;

  const _QueueRow({required this.leading, required this.title, required this.onTap, this.subtitle, this.trailing, this.count});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final value = count;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
        child: Row(
          children: [
            SizedBox(width: 32, child: Center(child: leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null && trailing!.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(trailing!, style: TextStyle(fontSize: 11.5, color: c.textHint)),
            ],
            if (value != null) ...[
              const SizedBox(width: 10),
              value > 0
                  ? CountBadge(count: value)
                  : Text(
                      '0',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textHint),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}
