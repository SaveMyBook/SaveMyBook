import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_labels.dart';
import '../../utils/app_radius.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

/// 單筆訂單的全貌。列表只夠判斷「有沒有問題」，處理一筆爭議要看的是
/// 錢什麼時候扣的、書放進哪一格、退過款沒有、對方申訴了什麼。
class AdminOrderDetailScreen extends StatefulWidget {
  final int orderId;
  final String orderNo;

  const AdminOrderDetailScreen({super.key, required this.orderId, required this.orderNo});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  final ApiService _api = ApiService();

  AdminOrderDetail? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final detail = await _api.fetchAdminOrder(widget.orderId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _isLoading = false;
    });
  }

  Future<void> _changeStatus() async {
    final detail = _detail;
    if (detail == null) return;
    final c = AppColors.of(context);

    final status = await showOptionSheet<String>(
      context,
      title: S.changeOrderStatus,
      subtitle: S.orderP0(detail.order.orderNo),
      options: AppLabels.orderStatus.entries
          .map((e) => SheetOption(
                value: e.key,
                label: e.value,
                selected: e.key == detail.order.status,
                color: e.key == 'cancelled' ? c.danger : null,
              ))
          .toList(),
    );
    if (status == null || status == detail.order.status || !mounted) return;

    final note = await showTextInputDialog(
      context,
      title: S.reasonChange,
      hint: S.sentBuyerAsWellOptional,
      confirmLabel: S.applyChange,
    );
    if (!mounted) return;

    final error = await runBusy(
      context,
      () => _api.updateOrderStatusAsAdmin(detail.order.orderId, status, note: note),
    );
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    showAppSnackBar(context, S.orderStatusUpdated);
    _load();
  }

  void _copy(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    showAppSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final detail = _detail;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
              title: widget.orderNo,
              icon: Icons.receipt_long_outlined,
              actions: [
                HeaderIconButton(
                  icon: Icons.copy_rounded,
                  onTap: () => _copy(widget.orderNo, S.orderNumberCopied),
                ),
              ],
            ),
            Expanded(
              child: SwitchIn(
                child: _isLoading
                    ? const LoadingView()
                    : detail == null
                        ? EmptyView(
                            icon: Icons.receipt_long_outlined,
                            message: S.orderNotFound,
                          )
                        : RefreshIndicator(
                            color: c.accent,
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                              children: [
                                _buildSummary(detail, c),
                                const SizedBox(height: 12),
                                _buildTimeline(detail, c),
                                const SizedBox(height: 12),
                                _buildPeople(detail, c),
                                const SizedBox(height: 12),
                                _buildItems(detail, c),
                                const SizedBox(height: 12),
                                _buildPickup(detail, c),
                                if (detail.walletTxns.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _buildWallet(detail, c),
                                ],
                                if (detail.refunds.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _buildRefunds(detail, c),
                                ],
                                if (detail.disputes.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _buildDisputes(detail, c),
                                ],
                              ],
                            ),
                          ),
              ),
            ),
          if (detail != null) _buildBottomBar(detail, c),
        ],
      ),
    );
  }

  Widget _buildSummary(AdminOrderDetail detail, AppColors c) {
    final order = detail.order;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNo,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
              ),
              StatusBadge(label: order.statusText, color: c.orderStatusColor(order.status)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${order.totalAmount.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c.accent),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _paymentText(detail.paymentMethod),
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ),
            ],
          ),
          if (order.cancelReason?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _noteBox(order.cancelReason!, Icons.cancel_outlined, c.danger, c),
          ],
          if (detail.note?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _noteBox(detail.note!, Icons.sticky_note_2_outlined, c.warning, c),
          ],
        ],
      ),
    );
  }

  /// null 先擋掉，switch 的 default 分支才會是 String 而不是 String?——
  /// switch 運算式不會對被檢查的值做型別提升。
  String _paymentText(String? method) {
    if (method == null) return S.notPaidYet;
    return switch (method) {
      'wallet' => S.paidWithCoins,
      'bank_transfer' => S.bankTransfer,
      _ => method,
    };
  }

  Widget _noteBox(String text, IconData icon, Color tint, AppColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary)),
          ),
        ],
      ),
    );
  }

  /// 時間軸。空的節點代表流程還沒走到那裡，卡在哪一步一眼就看得出來。
  Widget _buildTimeline(AdminOrderDetail detail, AppColors c) {
    final steps = detail.steps;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: S.progress),
          const SizedBox(height: 6),
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: steps[i].done ? c.accent : Colors.transparent,
                          border: Border.all(
                            color: steps[i].done ? c.accent : c.border,
                            width: 2,
                          ),
                        ),
                        child: steps[i].done
                            ? const Icon(Icons.check, size: 8, color: Colors.white)
                            : null,
                      ),
                      if (i != steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: steps[i].done ? c.accent.withValues(alpha: 0.35) : c.border,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: steps[i].done ? FontWeight.w600 : FontWeight.normal,
                              color: steps[i].done ? c.textPrimary : c.textHint,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            steps[i].done ? formatDateTime(steps[i].at) : S.notYet,
                            style: TextStyle(fontSize: 11, color: c.textHint),
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

  Widget _buildPeople(AdminOrderDetail detail, AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: S.buyerSeller),
          const SizedBox(height: 4),
          _personRow(S.buyer, detail.order.buyerName, detail.buyerAvatarUrl, c),
          Divider(color: c.divider, height: 20),
          _personRow(S.seller, detail.order.sellerName, detail.sellerAvatarUrl, c),
        ],
      ),
    );
  }

  Widget _personRow(String role, String name, String avatarUrl, AppColors c) {
    return Row(
      children: [
        UserAvatar(imageUrl: avatarUrl.isEmpty ? null : avatarUrl, radius: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role, style: TextStyle(fontSize: 11, color: c.textHint)),
              const SizedBox(height: 2),
              Text(
                name,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItems(AdminOrderDetail detail, AppColors c) {
    final items = detail.order.items;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: S.items3, trailing: Text('${items.length}', style: TextStyle(fontSize: 12, color: c.textHint))),
          const SizedBox(height: 4),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(color: c.divider, height: 20),
            Row(
              children: [
                BookThumbnail(imageUrl: items[i].imageUrl, width: 40, height: 54, radius: 6),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].title.isEmpty ? S.bookDeleted : items[i].title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: c.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '\$${items[i].unitPrice.toStringAsFixed(0)} × ${items[i].quantity}',
                        style: TextStyle(fontSize: 11, color: c.textHint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPickup(AdminOrderDetail detail, AppColors c) {
    final order = detail.order;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: S.collect),
          const SizedBox(height: 4),
          _kv(S.faqCatCabinet, order.cabinetName.isEmpty ? '—' : order.cabinetName, c),
          if (detail.cabinetAddress.isNotEmpty) _kv(S.address, detail.cabinetAddress, c),
          _kv(S.slot, detail.slotNumber ?? S.notAssignedYet2, c),
          _kv(
            S.pickupCode,
            order.pickupCode?.isNotEmpty == true ? order.pickupCode! : S.notGeneratedYet,
            c,
            onCopy: order.pickupCode?.isNotEmpty == true
                ? () => _copy(order.pickupCode!, S.pickupCodeCopied)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value, AppColors c, {VoidCallback? onCopy}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(label, style: TextStyle(fontSize: 12, color: c.textHint)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 13, color: c.textPrimary)),
          ),
          if (onCopy != null)
            PressableScale(
              onTap: onCopy,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.copy_rounded, size: 15, color: c.iconInactive),
              ),
            ),
        ],
      ),
    );
  }

  /// 這筆訂單造成的錢包異動，買賣雙方的都在裡面，可以直接跟總額對帳。
  Widget _buildWallet(AdminOrderDetail detail, AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: S.walletActivity),
          const SizedBox(height: 4),
          for (final txn in detail.walletTxns)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          txn.description?.isNotEmpty == true
                              ? txn.description!
                              : AppLabels.walletTxnType[txn.type] ?? txn.type,
                          style: TextStyle(fontSize: 13, color: c.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatDateTime(txn.createdAt),
                          style: TextStyle(fontSize: 11, color: c.textHint),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${txn.amount >= 0 ? '+' : ''}${txn.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: txn.amount >= 0 ? c.success : c.danger,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        S.balanceP02(txn.balanceAfter.toStringAsFixed(0)),
                        style: TextStyle(fontSize: 11, color: c.textHint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRefunds(AdminOrderDetail detail, AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: S.refunds),
          const SizedBox(height: 4),
          for (final refund in detail.refunds)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '\$${refund.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: AppLabels.refundStatus[refund.status] ?? refund.status,
                        color: c.neutral,
                      ),
                    ],
                  ),
                  if (refund.reason?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      refund.reason!,
                      style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    refund.processedAt == null
                        ? S.requestedP0NotProcessedYet(formatDateTime(refund.createdAt))
                        : S.processedP0(formatDateTime(refund.processedAt)),
                    style: TextStyle(fontSize: 11, color: c.textHint),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDisputes(AdminOrderDetail detail, AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: S.disputes),
          const SizedBox(height: 4),
          for (final dispute in detail.disputes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusBadge(
                        label: AppLabels.disputeStatus[dispute.status] ?? dispute.status,
                        color: c.neutral,
                      ),
                      if (dispute.result != null) ...[
                        const SizedBox(width: 6),
                        StatusBadge(
                          label: AppLabels.disputeResult[dispute.result] ?? dispute.result!,
                          color: c.accent,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    dispute.reason,
                    style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary),
                  ),
                  if (dispute.adminNote?.isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    _noteBox(dispute.adminNote!, Icons.gavel_rounded, c.accent, c),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    dispute.resolvedAt == null
                        ? S.filedP0(formatDateTime(dispute.createdAt))
                        : S.decidedP0(formatDateTime(dispute.resolvedAt)),
                    style: TextStyle(fontSize: 11, color: c.textHint),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AdminOrderDetail detail, AppColors c) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: c.card,
        boxShadow: [
          BoxShadow(color: c.shadow.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              S.createdP0(formatDateTime(detail.order.createdAt)),
              style: TextStyle(fontSize: 11, color: c.textHint),
            ),
          ),
          SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _changeStatus,
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: Text(S.changeOrderStatus),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
