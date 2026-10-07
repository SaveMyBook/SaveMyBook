import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/master_detail.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import 'admin_image_strip.dart';
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

  Future<void> _openOrder(BuildContext ctx, DisputeCase dispute) async {
    if (MasterDetail.isSplit(ctx)) {
      MasterDetail.open(
        ctx,
        AdminOrderDetailScreen(
          orderId: dispute.orderId,
          orderNo: dispute.orderNo,
          onChanged: () => _load(showLoading: false),
        ),
        id: ('order', dispute.disputeId),
      );
      return;
    }
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

  Future<void> _arbitrate(BuildContext ctx, DisputeCase dispute) async {
    if (MasterDetail.isSplit(ctx)) {
      MasterDetail.open(
        ctx,
        _DisputeArbitrationPage(
          dispute: dispute,
          results: _results,
          onSubmit: (result, note) => _submit(dispute, result, note),
        ),
        id: ('arbitrate', dispute.disputeId),
      );
      return;
    }
    if (_isBusy) return;
    final c = AppColors.of(context);
    (String, String)? choice;

    setState(() => _isBusy = true);
    try {
      final confirmed = await showAppModalSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: c.card,
        dialogMaxWidth: 600,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: _DisputeArbitrationForm(
              dispute: dispute,
              results: _results,
              onSubmit: (result, note) {
                choice = (result, note);
                Navigator.pop(ctx, true);
              },
            ),
          ),
        ),
      );

      final picked = choice;
      if (confirmed != true || picked == null || !mounted) return;
      await _submit(dispute, picked.$1, picked.$2);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<bool> _submit(DisputeCase dispute, String selected, String note) async {
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
    if (!ok || !mounted) return false;

    final error = await runBusy(
      context,
      () => _api.arbitrateDispute(
        dispute.disputeId,
        result: selected,
        adminNote: note.isEmpty ? null : note,
      ),
    );
    if (!mounted) return false;

    if (error != null) {
      if (error.isNotEmpty && error != S.verificationCancelled) showAppSnackBar(context, error, isError: true);
      return false;
    }
    showAppSnackBar(context, S.decisionRecorded);
    await _load(showLoading: false);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final openCount = _all.where((d) => d.status != 'resolved').length;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: MasterDetail(
        placeholderIcon: Icons.gavel_rounded,
        master: AdminLayout(
          builder: (context, frame) => Column(
            children: [
              AppHeader(
                title: S.resolveDispute,
                icon: Icons.gavel_rounded,
                bottom: AppTabBar(
                  controller: _tabController,
                  tabs: [
                    openCount > 0 ? '${S.disputeProcessing} $openCount' : S.disputeProcessing,
                    S.disputeResolved,
                  ],
                ),
              ),
              if (context.isWide)
                AdminSearchBar(
                  frame: frame,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                  search: AppSearchField(
                    controller: _searchController,
                    hint: S.searchOrderNumberBuyerSeller,
                    onChanged: (_) => setState(() {}),
                  ),
                )
              else
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
                    child: _isLoading ? const LoadingView.list() : _buildList(context, c, frame),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext ctx, AppColors c, AdminFrame frame) {
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
            : ctx.isWide
            ? AdminRowList(
                key: ValueKey('rows_$open'),
                frame: frame,
                itemCount: disputes.length,
                itemBuilder: (_, i) => RevealOnScroll(index: i, child: _buildRow(ctx, disputes[i], c, open: open)),
              )
            : AdminCardList(
                key: ValueKey('items_$open'),
                frame: frame,
                padding: const EdgeInsets.all(16),
                itemCount: disputes.length,
                itemBuilder: (_, i) => RevealOnScroll(
                  index: i,
                  child: _buildCard(ctx, disputes[i], c, open: open),
                ),
              ),
      ),
    );
  }

  Widget _buildRow(BuildContext ctx, DisputeCase dispute, AppColors c, {required bool open}) {
    return AdminListRow(
      selected: AdminListRow.isSelected(ctx, [('order', dispute.disputeId), ('arbitrate', dispute.disputeId)]),
      onTap: () => open && MasterDetail.isSplit(ctx) ? _arbitrate(ctx, dispute) : _openOrder(ctx, dispute),
      onMenu: () => _copyOrderNo(dispute),
      leading: AdminRowThumbnail(imageUrl: dispute.bookImageUrl),
      title: dispute.bookTitle.isEmpty ? dispute.orderNo : dispute.bookTitle,
      subtitle: S.orderNumberP0(dispute.orderNo),
      detail: S.reasonP0(dispute.reason),
      detailFooter: dispute.evidenceImages.isEmpty
          ? null
          : Row(
              children: [
                Flexible(
                  child: Text(
                    S.evidencePhotos,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: c.textHint),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: AdminImageStrip(urls: dispute.evidenceImages, size: 30, title: S.evidencePhotos)),
              ],
            ),
      status: open
          ? null
          : StatusBadge(label: dispute.resultText.isEmpty ? dispute.statusText : dispute.resultText, color: c.accent),
      amount: '\$${dispute.totalAmount.toStringAsFixed(0)}',
      time: formatDateTime(dispute.createdAt),
      trailing: open
          ? SmallActionButton(label: S.handle, filled: true, onTap: _isBusy ? null : () => _arbitrate(ctx, dispute))
          : null,
    );
  }

  Widget _buildCard(BuildContext ctx, DisputeCase dispute, AppColors c, {required bool open}) {
    return AdminSelectable(
      ids: [('order', dispute.disputeId), ('arbitrate', dispute.disputeId)],
      builder: (margin) => AppCard(
        margin: margin,
        onTap: () => open && MasterDetail.isSplit(ctx) ? _arbitrate(ctx, dispute) : _openOrder(ctx, dispute),
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              dispute.bookTitle.isEmpty ? dispute.orderNo : dispute.bookTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '\$${dispute.totalAmount.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.accent),
                          ),
                        ],
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
              ],
            ),
            const SizedBox(height: 8),
            Text(S.reasonP0(dispute.reason),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4)),
            if (dispute.evidenceImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              _evidenceLabel(c),
              const SizedBox(height: 6),
              AdminImageStrip(urls: dispute.evidenceImages, size: 52, title: S.evidencePhotos),
            ],
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
                    onTap: _isBusy ? null : () => _arbitrate(ctx, dispute),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: StatusBadge(
                      label: dispute.resultText.isEmpty ? dispute.statusText : dispute.resultText,
                      color: c.accent,
                    ),
                  ),
              ],
            ),
          ],
        ),
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

Widget _evidenceLabel(AppColors c) => Text(
      S.evidencePhotos,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
    );

class _DisputeArbitrationForm extends StatefulWidget {
  final DisputeCase dispute;
  final List<({String value, String label})> results;
  final void Function(String result, String note) onSubmit;
  final bool showTitle;
  final VoidCallback? onViewOrder;

  const _DisputeArbitrationForm({
    required this.dispute,
    required this.results,
    required this.onSubmit,
    this.showTitle = true,
    this.onViewOrder,
  });

  @override
  State<_DisputeArbitrationForm> createState() => _DisputeArbitrationFormState();
}

class _DisputeArbitrationFormState extends State<_DisputeArbitrationForm> {
  final TextEditingController _noteController = TextEditingController();
  late String _selected = widget.results.first.value;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dispute = widget.dispute;
    final orderLine = Text(S.orderP0P1(dispute.orderNo, dispute.totalAmount.toStringAsFixed(0)),
        style: TextStyle(fontSize: 13, color: c.textSecondary));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle) ...[
          Text(S.disputeResolution,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
          const SizedBox(height: 6),
        ],
        if (widget.onViewOrder == null)
          orderLine
        else
          Row(
            children: [
              Expanded(child: orderLine),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: widget.onViewOrder,
                style: TextButton.styleFrom(foregroundColor: c.accent, visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: Text(S.viewOrder, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        const SizedBox(height: 4),
        Text(S.reasonP0(dispute.reason),
            style: TextStyle(fontSize: 13, color: c.textSecondary)),
        if (dispute.evidenceImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          _evidenceLabel(c),
          const SizedBox(height: 6),
          AdminImageStrip(urls: dispute.evidenceImages, size: 88, title: S.evidencePhotos),
        ],
        const SizedBox(height: 14),
        DisputeAiPanel(disputeId: dispute.disputeId),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: _selected,
          onChanged: (value) => setState(() => _selected = value ?? _selected),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.results
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
            key: ValueKey(_selected.startsWith('refund')),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: (_selected.startsWith('refund') ? c.warning : c.accent)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _selected.startsWith('refund')
                  ? S.buyerSPaymentGoesBackTheir
                  : S.orderReturnsWhereWasBeforeDispute,
              style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _noteController,
          maxLines: 3,
          maxLength: 500,
          hint: S.decisionNoteOptional,
        ),
        const SizedBox(height: 16),
        if (context.isWide)
          AdminButtonRow(
            minWidth: 180,
            children: [
              PrimaryButton(
                label: S.submitDecision,
                height: 46,
                expand: false,
                onPressed: () => widget.onSubmit(_selected, _noteController.text.trim()),
              ),
            ],
          )
        else
          PrimaryButton(
            label: S.submitDecision,
            height: 46,
            onPressed: () => widget.onSubmit(_selected, _noteController.text.trim()),
          ),
      ],
    );
  }
}

class _DisputeArbitrationPage extends StatefulWidget {
  final DisputeCase dispute;
  final List<({String value, String label})> results;
  final Future<bool> Function(String result, String note) onSubmit;

  const _DisputeArbitrationPage({required this.dispute, required this.results, required this.onSubmit});

  @override
  State<_DisputeArbitrationPage> createState() => _DisputeArbitrationPageState();
}

class _DisputeArbitrationPageState extends State<_DisputeArbitrationPage> {
  bool _submitting = false;

  Future<void> _submit(String result, String note) async {
    if (_submitting) return;
    _submitting = true;
    try {
      final done = await widget.onSubmit(result, note);
      if (done && mounted) Navigator.of(context).pop(true);
    } finally {
      _submitting = false;
    }
  }

  void _viewOrder() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminOrderDetailScreen(orderId: widget.dispute.orderId, orderNo: widget.dispute.orderNo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.disputeResolution, icon: Icons.gavel_rounded),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: responsiveListPadding(
                  constraints,
                  maxWidth: Breakpoints.readingMaxWidth,
                  horizontal: 24,
                  top: 20,
                  bottom: MediaQuery.paddingOf(context).bottom + 24,
                ),
                child: AppCard(
                  padding: const EdgeInsets.all(20),
                  child: _DisputeArbitrationForm(
                    dispute: widget.dispute,
                    results: widget.results,
                    showTitle: false,
                    onViewOrder: _viewOrder,
                    onSubmit: _submit,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
