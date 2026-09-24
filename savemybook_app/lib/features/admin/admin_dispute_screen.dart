import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import 'admin_order_detail_screen.dart';
import '../../i18n/strings.dart';
import 'dispute_ai_panel.dart';
import 'admin_layout.dart';

class AdminDisputeScreen extends StatefulWidget {
  const AdminDisputeScreen({super.key});

  @override
  State<AdminDisputeScreen> createState() => _AdminDisputeScreenState();
}

class _AdminDisputeScreenState extends State<AdminDisputeScreen>
    with SingleTickerProviderStateMixin {
  List<({String value, String label})> get _results => [
    (value: 'refund_manual', label: S.disputeRefundManual),
    (value: 'refund_auto', label: S.disputeRefundAuto),
    (value: 'mediated', label: S.disputeMediated),
    (value: 'dismissed', label: S.disputeDismissed),
  ];

  final ApiService _api = ApiService();
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<DisputeCase> _all = [];
  bool _isLoading = true;
  bool _isBusy = false;
  bool _navigating = false;
  int _loadSeq = 0;

  bool get _isOpenTab => _tabController.index == 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    final seq = ++_loadSeq;
    if (showLoading) setState(() => _isLoading = true);
    final all = await _api.fetchAdminDisputes();
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _all = all;
      _isLoading = false;
    });
  }

  List<DisputeCase> _visible({required bool open}) {
    final keyword = _searchController.text.trim().toLowerCase();
    return _all.where((d) {
      if ((d.status != 'resolved') != open) return false;
      if (keyword.isEmpty) return true;
      return d.orderNo.toLowerCase().contains(keyword) ||
          d.bookTitle.toLowerCase().contains(keyword) ||
          d.buyerName.toLowerCase().contains(keyword) ||
          d.sellerName.toLowerCase().contains(keyword) ||
          d.reason.toLowerCase().contains(keyword);
    }).toList();
  }

  void _copyOrderNo(DisputeCase dispute) {
    Clipboard.setData(ClipboardData(text: dispute.orderNo));
    HapticFeedback.selectionClick();
    showAppSnackBar(context, S.orderNumberCopied);
  }

  Future<void> _openOrder(DisputeCase dispute) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminOrderDetailScreen(orderId: dispute.orderId, orderNo: dispute.orderNo),
        ),
      );
    } finally {
      _navigating = false;
    }
    if (mounted) _load(showLoading: false);
  }

  Future<void> _arbitrate(DisputeCase dispute) async {
    if (_isBusy) return;
    final c = AppColors.of(context);
    final noteController = TextEditingController();
    String selected = _results.first.value;

    setState(() => _isBusy = true);
    try {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: c.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheetState) => SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.disputeResolution,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
                  const SizedBox(height: 6),
                  Text(S.orderP0P1(dispute.orderNo, dispute.totalAmount.toStringAsFixed(0)),
                      style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  const SizedBox(height: 4),
                  Text(S.reasonP0(dispute.reason),
                      style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  const SizedBox(height: 14),
                  DisputeAiPanel(disputeId: dispute.disputeId),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: selected,
                    onChanged: (value) => setSheetState(() => selected = value ?? selected),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _results
                          .map(
                            (r) => RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: r.value,
                              title: Text(
                                r.label,
                                style: TextStyle(fontSize: 14, color: c.textPrimary),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchIn(
                    child: Container(
                      key: ValueKey(selected.startsWith('refund')),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: (selected.startsWith('refund') ? c.warning : c.accent)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        selected.startsWith('refund')
                            ? S.buyerSPaymentGoesBackTheir
                            : S.orderReturnsWhereWasBeforeDispute,
                        style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: noteController,
                    maxLines: 3,
                    maxLength: 500,
                    hint: S.decisionNoteOptional,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: S.submitDecision,
                    height: 46,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (confirmed != true || !mounted) return;

      final label = _results.firstWhere((r) => r.value == selected).label;
      final ok = await showConfirmDialog(
        context,
        title: S.submitDecision,
        message: selected.startsWith('refund')
            ? S.orderP0ClosedAsP1P2(dispute.orderNo, label, dispute.totalAmount.toStringAsFixed(0))
            : S.orderP0ClosedAsP1Can(dispute.orderNo, label),
        confirmLabel: S.submitDecision,
        isDestructive: selected.startsWith('refund'),
        icon: Icons.gavel_rounded,
      );
      if (!ok || !mounted) return;

      final note = noteController.text.trim();
      final error = await runBusy(
        context,
        () => _api.arbitrateDispute(
          dispute.disputeId,
          result: selected,
          adminNote: note.isEmpty ? null : note,
        ),
      );
      if (!mounted) return;

      if (error != null) {
        if (error.isNotEmpty && error != S.verificationCancelled) showAppSnackBar(context, error, isError: true);
      } else {
        showAppSnackBar(context, S.decisionRecorded);
        await _load(showLoading: false);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final openCount = _all.where((d) => d.status != 'resolved').length;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: AdminLayout(
        builder: (context, frame) => Column(
          children: [
            AppHeader(
              title: S.resolveDispute,
              icon: Icons.gavel_rounded,
              bottom: AppTabBar(
                controller: _tabController,
                tabs: [
                  openCount > 0 ? '${S.disputeProcessing} $openCount' : S.disputeProcessing,
                  S.ticketClosed,
                ],
              ),
            ),
            Padding(
              padding: frame.inset(const EdgeInsets.fromLTRB(16, 12, 16, 0)),
              child: AppSearchField(
                controller: _searchController,
                hint: S.searchOrderNumberBuyerSeller,
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: SwipeTabs(
                controller: _tabController,
                child: SwitchIn(
                  child: _isLoading ? const LoadingView.list() : _buildList(c, frame),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(AppColors c, AdminFrame frame) {
    final open = _isOpenTab;
    final disputes = _visible(open: open);
    final searching = _searchController.text.trim().isNotEmpty;

    return RefreshIndicator(
      key: ValueKey('tab_$open'),
      color: c.accent,
      onRefresh: () => _load(showLoading: false),
      child: SwitchIn(
        child: disputes.isEmpty
            ? ListView(
                key: const ValueKey('empty'),
                children: [
                  const SizedBox(height: 60),
                  EmptyView(
                    icon: Icons.balance_rounded,
                    message: S.noDisputesKind,
                    actionLabel: searching ? S.clearSearch : S.refresh,
                    onAction: () {
                      if (searching) {
                        _searchController.clear();
                        setState(() {});
                      } else {
                        _load();
                      }
                    },
                  ),
                ],
              )
            : ListView.builder(
                key: ValueKey('items_$open'),
                padding: frame.inset(const EdgeInsets.all(16)),
                itemCount: disputes.length,
                itemBuilder: (_, i) => RevealOnScroll(
                  index: i,
                  child: _buildCard(disputes[i], c, open: open),
                ),
              ),
      ),
    );
  }

  Widget _buildCard(DisputeCase dispute, AppColors c, {required bool open}) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _openOrder(dispute),
      onLongPress: () => _copyOrderNo(dispute),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookThumbnail(imageUrl: dispute.bookImageUrl, width: 52, height: 66, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dispute.bookTitle.isEmpty ? dispute.orderNo : dispute.bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            S.orderNumberP0(dispute.orderNo),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.textSecondary),
                          ),
                        ),
                        PressableScale(
                          onTap: () => _copyOrderNo(dispute),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Icon(Icons.copy_rounded, size: 13, color: c.iconInactive),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(S.buyerP0SellerP1(dispute.buyerName, dispute.sellerName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    const SizedBox(height: 2),
                    Text(S.filedByP0(dispute.applicantName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 90),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topRight,
                  child: Text(
                    '\$${dispute.totalAmount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.accent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(S.reasonP0(dispute.reason),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _when(dispute.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.textHint),
                ),
              ),
              const SizedBox(width: 8),
              if (open)
                SmallActionButton(
                  label: S.handle,
                  filled: true,
                  onTap: _isBusy ? null : () => _arbitrate(dispute),
                )
              else
                Flexible(
                  child: StatusBadge(
                    label: dispute.resultText.isEmpty ? dispute.statusText : dispute.resultText,
                    color: c.accent,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _when(DateTime? dt) {
    if (dt == null) return '';
    final relative = formatRelative(dt);
    final exact = formatDateTime(dt);
    return exact.startsWith(relative) ? exact : '$relative・$exact';
  }
}
