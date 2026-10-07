import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../i18n/strings.dart';
import '../../models/cabinet.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_side_nav.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../account/support_ticket_screen.dart';
import '../home/home_screen.dart';
import '../orders/pickup_success_screen.dart';
import '../orders/order_history_screen.dart';
import '../selling/book_manage_screen.dart';
import 'cabinet_flow_controller.dart';
import 'cabinet_match_code_field.dart';
import 'cabinet_messages.dart';
import 'cabinet_scanner_view.dart';

class CabinetFlowScreen extends StatefulWidget {
  final String? code;
  final CabinetContext? cabinetContext;
  final CabinetSession? resume;
  final Stream<String>? scanInput;
  final CabinetFlowController? controller;
  final ValueChanged<CabinetFlowOutcome>? onOutcome;

  const CabinetFlowScreen({super.key, this.code, this.cabinetContext, this.resume, this.scanInput, this.controller, this.onOutcome});

  static final ValueNotifier<int> _showing = ValueNotifier(0);

  static ValueListenable<int> get showing => _showing;

  static bool get isShowing => _showing.value > 0;

  @override
  State<CabinetFlowScreen> createState() => _CabinetFlowScreenState();
}

class _CabinetFlowScreenState extends State<CabinetFlowScreen> with WidgetsBindingObserver {
  late final CabinetFlowController _flow = widget.controller ?? CabinetFlowController(cabinetContext: widget.cabinetContext);
  final _matchInput = TextEditingController();
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    CabinetFlowScreen._showing.value++;
    WidgetsBinding.instance.addObserver(this);
    _flow.addListener(_onFlow);
    final resume = widget.resume;
    final code = widget.code;
    if (resume != null) {
      _flow.resume(resume);
    } else if (code != null) {
      unawaited(_flow.submitCode(code));
    } else if (_flow.step == CabinetFlowStep.scan) {
      unawaited(_flow.prepareScan());
    }
  }

  @override
  void dispose() {
    CabinetFlowScreen._showing.value--;
    WidgetsBinding.instance.removeObserver(this);
    _flow.removeListener(_onFlow);
    _flow.dispose();
    _matchInput.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _flow.resumePolling();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _flow.pause();
    }
  }

  void _onFlow() {
    widget.onOutcome?.call(_flow.outcome);
    if (_flow.step != CabinetFlowStep.match && _matchInput.text.isNotEmpty) _matchInput.clear();
    if (!_leaving && _flow.step == CabinetFlowStep.result && _flow.pickupSucceeded) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPickupSuccess());
    }
  }

  Future<void> _showPickupSuccess() async {
    final orderId = _flow.session?.selectedItems.firstOrNull?.orderId;
    final order = orderId == null ? null : await ApiService().fetchOrderDetail(orderId);
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PickupSuccessScreen(order: order)),
        result: CabinetFlowOutcome.completed,
      ),
    );
  }

  // 作業畫面推在最上層，須先關閉，訂單紀錄才會切換到側邊欄的分頁
  void _closeAndOpenOrders(OrderRole role, String filter) {
    final navigator = Navigator.of(context);
    _close();
    unawaited(OrderHistoryScreen.open(navigator.context, role: role, filter: filter));
  }

  void _close([CabinetFlowOutcome? outcome]) {
    if (!mounted) return;
    Navigator.of(context).pop(outcome ?? _flow.outcome);
  }

  Future<void> _cancel() async {
    final close = await _flow.cancel();
    if (close) _close();
  }

  bool _expired(CabinetSession session) => session.remainingMs != null && _flow.remaining == Duration.zero;

  // 開門後的「完成」「取消」只在這個畫面；倒數結束前離開就無法再結束作業。
  bool get _locked {
    final session = _flow.session;
    final step = _flow.step;
    if (session == null || session.remainingMs == null) return false;
    return (step == CabinetFlowStep.opening || step == CabinetFlowStep.open) && !_expired(session);
  }

  bool _canSubmitMatch(CabinetSession session) =>
      !_flow.busy && !_expired(session) && _matchInput.text.length == CabinetMatchCodeField.length;

  Future<void> _submitMatch() async {
    final session = _flow.session;
    if (session == null || !_canSubmitMatch(session)) return;
    final error = await _flow.submitMatch(_matchInput.text);
    if (mounted && error == CabinetApiError.matchCodeInvalid) _matchInput.clear();
  }

  Future<void> _run(CabinetFlowAction action) async {
    switch (action) {
      case CabinetFlowAction.rescan:
        _flow.rescan();
      case CabinetFlowAction.close:
        _close();
      case CabinetFlowAction.reportManually:
        _flow.requestManual();
        _close(CabinetFlowOutcome.manualRequested);
      case CabinetFlowAction.openMap:
        final cabinet = _flow.error?.cabinet;
        if (cabinet == null || !cabinet.hasCoordinates) return;
        final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${cabinet.latitude},${cabinet.longitude}');
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      case CabinetFlowAction.viewPurchases:
        if (_wide) return _closeAndOpenOrders(OrderRole.buyer, OrderHistoryScreen.awaitingPickup);
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OrderHistoryScreen(filter: OrderHistoryScreen.awaitingPickup)),
        );
      case CabinetFlowAction.viewSales:
        if (_wide) return _closeAndOpenOrders(OrderRole.seller, OrderHistoryScreen.awaitingDeposit);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const OrderHistoryScreen(role: OrderRole.seller, filter: OrderHistoryScreen.awaitingDeposit),
          ),
        );
      case CabinetFlowAction.viewBooks:
        if (_wide) {
          // 作業畫面推在最上層，須先關閉，HomeScreen.showTab 才會切換分頁
          final navigator = Navigator.of(context);
          _close();
          if (!HomeScreen.showTab(AppSideNav.myBooksTab)) {
            unawaited(navigator.push(MaterialPageRoute(builder: (_) => const BookManageScreen())));
          }
          return;
        }
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookManageScreen()));
      case CabinetFlowAction.contactSupport:
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportTicketScreen()));
      case CabinetFlowAction.resume:
        final sessionNo = _flow.error?.sessionNo;
        if (sessionNo != null) await _flow.resumeSession(sessionNo);
      case CabinetFlowAction.retry:
        await _flow.retry();
      case CabinetFlowAction.openSettings:
        await LocationService.openSettings();
    }
  }

  String _actionLabel(CabinetFlowAction action) => switch (action) {
    CabinetFlowAction.rescan => S.rescan,
    CabinetFlowAction.close => S.actionClose,
    CabinetFlowAction.reportManually => S.reportManually,
    CabinetFlowAction.openMap => S.openMap,
    CabinetFlowAction.viewPurchases => S.viewPurchases,
    CabinetFlowAction.viewSales => S.viewSales,
    CabinetFlowAction.viewBooks => S.viewMyBooks,
    CabinetFlowAction.contactSupport => S.contactSupport,
    CabinetFlowAction.resume => S.continueTask,
    CabinetFlowAction.retry => S.retry,
    CabinetFlowAction.openSettings => S.openSettings,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_flow, _matchInput]),
      builder: (context, _) {
        final c = AppColors.of(context);
        final step = _flow.step;
        final scanning = step == CabinetFlowStep.scan || step == CabinetFlowStep.prepare;
        final beforeSession = scanning || (_flow.session == null && step != CabinetFlowStep.result);
        final locked = _locked;
        return PopScope(
          canPop: !locked,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) _flow.abandon();
          },
          child: Scaffold(
            backgroundColor: scanning ? Colors.black : c.scaffold,
            body: Column(
              children: [
                AppHeader(
                  title: beforeSession ? S.scanLockerQrCode : S.confirmLockerTask,
                  icon: Icons.qr_code_scanner_rounded,
                  showBack: !locked,
                  onBack: _close,
                ),
                Expanded(
                  child: SwitchIn(
                    child: KeyedSubtree(key: ValueKey(step), child: _body(c, step)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body(AppColors c, CabinetFlowStep step) {
    final session = _flow.session;
    switch (step) {
      case CabinetFlowStep.prepare:
        return const SizedBox.expand();
      case CabinetFlowStep.scan:
        return CabinetScannerView(onScan: _flow.submitCode, scanInput: widget.scanInput);
      case CabinetFlowStep.checking:
        return _progress(c, S.checkingLocker);
      case CabinetFlowStep.error:
        return _error(c);
      case CabinetFlowStep.confirm:
        return session == null ? _progress(c, S.checkingLocker) : _confirm(c, session);
      case CabinetFlowStep.match:
        return session == null ? _progress(c, S.checkingLocker) : _match(c, session);
      case CabinetFlowStep.opening:
        return _progress(c, S.openingDoor, detail: session == null ? null : _doorsText(session));
      case CabinetFlowStep.open:
        return session == null ? _progress(c, S.openingDoor) : _open(c, session);
      case CabinetFlowStep.result:
        if (_flow.pickupSucceeded) return _progress(c, null);
        return session == null ? _progress(c, S.checkingLocker) : _result(c, session);
    }
  }

  bool get _wide => context.isWide;

  Widget _scroll(AppColors c, List<Widget> children, {Widget? bottom}) {
    if (_wide) return _panel(c, children, bottom: bottom, stretch: true);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => ListView(
              padding: responsiveListPadding(
                constraints,
                maxWidth: Breakpoints.formMaxWidth,
                top: 16,
                bottom: bottom == null ? MediaQuery.paddingOf(context).bottom + 24 : 16,
              ),
              children: children,
            ),
          ),
        ),
        if (bottom != null) _bottomBar(c, bottom),
      ],
    );
  }

  Widget _centered(AppColors c, List<Widget> children, {Widget? bottom}) {
    if (_wide) return _panel(c, children, bottom: bottom, stretch: false);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: responsiveListPadding(constraints, maxWidth: Breakpoints.formMaxWidth, top: 24, bottom: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: math.max(0, constraints.maxHeight - 48)),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: children)),
              ),
            ),
          ),
        ),
        if (bottom != null) _bottomBar(c, bottom),
      ],
    );
  }

  Widget _panel(AppColors c, List<Widget> children, {Widget? bottom, required bool stretch}) {
    final vertical = MediaQuery.viewInsetsOf(context).bottom > 0 ? 16.0 : 32.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, vertical, 24, vertical + MediaQuery.paddingOf(context).bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(24, 28, 24, bottom == null ? 28 : 20),
                    child: Column(
                      crossAxisAlignment: stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
                      children: children,
                    ),
                  ),
                ),
                if (bottom != null)
                  Container(
                    padding: EdgeInsets.fromLTRB(24, stretch ? 16 : 0, 24, 24),
                    decoration: stretch ? BoxDecoration(border: Border(top: BorderSide(color: c.divider))) : null,
                    child: bottom,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _box(AppColors c, Widget child) {
    if (!_wide) return AppCard(child: child);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.inputFill.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }

  Widget _bottomBar(AppColors c, Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = responsiveListPadding(constraints, maxWidth: Breakpoints.formMaxWidth).left;
        return Container(
          padding: EdgeInsets.fromLTRB(side, 12, side, MediaQuery.paddingOf(context).bottom + 12),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            boxShadow: [BoxShadow(color: c.shadow, blurRadius: 24, offset: const Offset(0, -6))],
          ),
          child: child,
        );
      },
    );
  }

  Widget _progress(AppColors c, String? label, {String? detail}) {
    return _centered(c, [
      SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: c.accent)),
      if (label != null) ...[
        const SizedBox(height: 20),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary),
        ),
      ],
      if (detail != null) ...[
        const SizedBox(height: 8),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: c.textSecondary),
        ),
      ],
    ]);
  }

  Widget _alertIcon(AppColors c, Color color, IconData icon) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 38),
    );
  }

  Widget _notice(AppColors c, String text, {String? title, Color? color, IconData icon = Icons.info_outline_rounded}) {
    final tint = color ?? c.warning;
    final body = Text(text, style: TextStyle(fontSize: 13, height: 1.5, color: c.textPrimary));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: title == null
                ? body
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.bold, color: c.textPrimary)),
                      body,
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buttons(List<Widget> buttons) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[if (i > 0) const SizedBox(height: 8), buttons[i]],
      ],
    );
  }

  Widget _error(AppColors c) {
    final error = _flow.error;
    if (error == null) return _progress(c, S.checkingLocker);
    final actions = error.actions.isEmpty ? const [CabinetFlowAction.close] : error.actions;
    return _centered(
      c,
      [
        _alertIcon(c, c.warning, Icons.error_outline_rounded),
        const SizedBox(height: 20),
        Text(
          error.message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, height: 1.5, fontWeight: FontWeight.bold, color: c.textPrimary),
        ),
        if (error.detail != null) ...[
          const SizedBox(height: 8),
          Text(
            error.detail!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: c.textSecondary),
          ),
        ],
      ],
      bottom: _buttons([
        PrimaryButton(label: _actionLabel(actions.first), isLoading: _flow.busy, onPressed: () => _run(actions.first)),
        for (final action in actions.skip(1))
          SecondaryButton(label: _actionLabel(action), onPressed: _flow.busy ? null : () => _run(action)),
      ]),
    );
  }

  String _sectionTitle(CabinetItemKind kind) => switch (kind) {
    CabinetItemKind.pickup => S.collect,
    CabinetItemKind.orderDeposit => S.orderDropOff,
    CabinetItemKind.preDeposit => S.preSaleDropOff,
    CabinetItemKind.retrieval => S.retrieveBooks,
  };

  List<String> _doorsOf(CabinetSessionItem item) {
    if (item.doors.isNotEmpty) return item.doors;
    return {
      for (final book in item.books)
        if (book.door != null) book.door!,
    }.toList();
  }

  String? _doorsText(CabinetSession session) {
    final labels = session.doors.isNotEmpty
        ? [for (final door in session.doors) door.label]
        : {for (final item in session.selectedItems) ..._doorsOf(item)}.toList();
    return labels.isEmpty ? null : CabinetMessages.door(labels.join('、'));
  }

  String _titles(CabinetSessionItem item) {
    final titles = [for (final book in item.books) book.title.isEmpty ? S.untitled : book.title];
    return titles.isEmpty ? (item.orderNo == null ? S.untitled : S.order(item.orderNo!)) : titles.join('、');
  }

  Widget _cabinetCard(AppColors c, CabinetSession session) {
    final cabinet = session.cabinet;
    return _box(
      c,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.storage_rounded, color: c.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cabinet.cabinetName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    if (cabinet.address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        cabinet.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, height: 1.4, color: c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemRow(AppColors c, CabinetSessionItem item) {
    final blocked = item.blocked;
    final selectable = blocked == null && !_flow.busy;
    final selected = blocked == null && _flow.isSelected(item.key);
    final book = item.books.firstOrNull;
    final doors = _doorsOf(item);
    final note = item.note;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: selectable ? () => _flow.toggle(item.key) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              height: 60,
              child: (item.kind?.isSingleChoice ?? false)
                  ? Radio<String>(
                      value: item.key,
                      toggleable: true,
                      enabled: selectable,
                      activeColor: c.accent,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    )
                  : Checkbox(
                      value: selected,
                      onChanged: selectable ? (_) => _flow.toggle(item.key) : null,
                      activeColor: c.accent,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
            ),
            const SizedBox(width: 6),
            Opacity(
              opacity: blocked == null ? 1 : 0.5,
              child: BookThumbnail(imageUrl: book?.imageUrl, width: 44, height: 60, radius: 8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final title
                      in item.books.isEmpty ? [_titles(item)] : [for (final b in item.books) b.title.isEmpty ? S.untitled : b.title])
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: blocked == null ? c.textPrimary : c.textHint,
                      ),
                    ),
                  if (item.orderNo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      S.order(item.orderNo!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ],
                  if (doors.isNotEmpty || item.paused) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (doors.isNotEmpty) StatusBadge(label: CabinetMessages.door(doors.join('、')), color: c.accent),
                        if (item.paused) StatusBadge(label: S.salesPaused, color: c.warning),
                      ],
                    ),
                  ],
                  if (note != null) ...[
                    const SizedBox(height: 4),
                    Text(CabinetMessages.note(note, item: item), style: TextStyle(fontSize: 12, height: 1.4, color: c.warning)),
                  ],
                  if (blocked != null && !CabinetMessages.isSharedBlock(item)) ...[
                    const SizedBox(height: 4),
                    Text(CabinetMessages.blocked(blocked), style: TextStyle(fontSize: 12, height: 1.4, color: c.danger)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemRows(AppColors c, CabinetItemKind kind, List<CabinetSessionItem> items) {
    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[if (i > 0) Divider(height: 1, color: c.divider), _itemRow(c, items[i])],
      ],
    );
    if (!kind.isSingleChoice) return rows;
    final selected = _flow.selectedOf(kind);
    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (key) {
        final target = key ?? selected;
        if (target != null) _flow.toggle(target);
      },
      child: rows,
    );
  }

  Widget _singleChoiceNote(AppColors c, List<CabinetSessionItem> items) {
    final blocks = CabinetMessages.sharedBlocks(items);
    if (blocks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(S.preSaleDropOffLimitedOne, style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final message in blocks) Padding(padding: const EdgeInsets.only(bottom: 8), child: _notice(c, message)),
      ],
    );
  }

  Widget _confirm(AppColors c, CabinetSession session) {
    final groups = <CabinetItemKind, List<CabinetSessionItem>>{};
    for (final item in session.items) {
      final kind = item.kind;
      if (kind != null) groups.putIfAbsent(kind, () => []).add(item);
    }
    final notice = _flow.notice;
    return _scroll(
      c,
      [
        if (notice != null) ...[_notice(c, notice), const SizedBox(height: 12)],
        _cabinetCard(c, session),
        for (final kind in CabinetItemKind.values)
          if (groups[kind] case final items?) ...[
            const SizedBox(height: 14),
            _box(
              c,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeading(title: _sectionTitle(kind)),
                  if (kind.isSingleChoice) _singleChoiceNote(c, items),
                  _itemRows(c, kind, items),
                  if (kind == CabinetItemKind.retrieval) ...[
                    const SizedBox(height: 4),
                    Text(S.booksSameDoorRetrievedTogether, style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary)),
                  ],
                ],
              ),
            ),
          ],
      ],
      bottom: _buttons([
        Text(
          S.confirmWithinP0(CabinetFlowController.formatClock(_flow.remaining)),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: c.textSecondary),
        ),
        PrimaryButton(
          label: S.openDoor,
          icon: Icons.lock_open_rounded,
          isLoading: _flow.busy,
          onPressed: _flow.selectedKeys.isEmpty ? null : _flow.start,
        ),
        SecondaryButton(label: S.cancelTask, onPressed: _flow.busy ? null : _cancel),
      ]),
    );
  }

  Widget _match(AppColors c, CabinetSession session) {
    final doors = _doorsText(session);
    final notice = _flow.notice;
    return _centered(
      c,
      [
        Text(
          S.enterNumberShownLockerScreen,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, height: 1.4, fontWeight: FontWeight.bold, color: c.textPrimary),
        ),
        if (doors != null) ...[
          const SizedBox(height: 12),
          Text(
            doors,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          ),
        ],
        const SizedBox(height: 24),
        CabinetMatchCodeField(
          controller: _matchInput,
          enabled: !_flow.busy && !_expired(session),
          autofocus: true,
          semanticLabel: S.enterNumberShownLockerScreen,
          onSubmitted: _submitMatch,
        ),
        const SizedBox(height: 12),
        Text(
          S.p0SRemaining(CabinetFlowController.secondsOf(_flow.remaining)),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: c.textSecondary),
        ),
        if (notice != null) ...[const SizedBox(height: 16), _notice(c, notice)],
        const SizedBox(height: 20),
        _notice(c, S.ifSomeoneTellsNumberAsksEnter, color: c.danger, icon: Icons.shield_outlined),
      ],
      bottom: _buttons([
        PrimaryButton(
          label: S.confirm,
          isLoading: _flow.busy && !_flow.cancelling,
          onPressed: _canSubmitMatch(session) ? _submitMatch : null,
        ),
        SecondaryButton(label: S.cancelTask, isLoading: _flow.cancelling, onPressed: _flow.busy ? null : _cancel),
      ]),
    );
  }

  List<CabinetSessionBook> _booksAt(CabinetSession session, String label) {
    return [
      for (final item in session.selectedItems)
        for (final book in item.books)
          if ((book.door ?? (item.doors.length == 1 && item.booksWithDoor == 0 ? item.doors.first : null)) == label) book,
    ];
  }

  String _doorTitle(CabinetSession session, String label) {
    final kinds = {
      for (final item in session.selectedItems)
        if (_doorsOf(item).contains(label)) item.kind,
    };
    if (kinds.contains(CabinetItemKind.pickup)) return S.takeBooksFromDoorP0(label);
    if (kinds.contains(CabinetItemKind.retrieval)) return S.retrieveBooksFromDoorP0(label);
    return S.placeTheseBooksDoorP0(label);
  }

  Widget _doorHeading(AppColors c, CabinetSession session, CabinetSessionDoor door) => switch (door.state) {
    'failed' => SectionHeading(title: CabinetMessages.door(door.label), trailing: StatusBadge(label: S.doorDidNotOpen, color: c.danger)),
    'pending' => SectionHeading(title: CabinetMessages.door(door.label), trailing: StatusBadge(label: S.openingDoor, color: c.textSecondary)),
    _ => SectionHeading(title: _doorTitle(session, door.label)),
  };

  Widget _open(AppColors c, CabinetSession session) {
    final doors = session.doors.isNotEmpty
        ? session.doors
        : [
            for (final label in {for (final item in session.selectedItems) ..._doorsOf(item)})
              CabinetSessionDoor(label: label, state: 'open'),
          ];
    final remaining = _flow.remaining;
    final total = session.openMs ?? 0;
    final fraction = total <= 0 ? 0.0 : (remaining.inMilliseconds / total).clamp(0.0, 1.0);
    final closing = _flow.closing;
    final idle = closing == null && !_flow.busy && !_expired(session);
    final notice = _flow.notice;
    return _scroll(c, [
      const SizedBox(height: 8),
      Center(
        child: SizedBox(
          width: 128,
          height: 128,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: fraction,
                strokeWidth: 8,
                color: c.accent,
                backgroundColor: c.accent.withValues(alpha: 0.14),
              ),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CabinetFlowController.formatClock(remaining),
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: c.textPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        S.doorOpened,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary),
      ),
      const SizedBox(height: 16),
      for (final door in doors) ...[
        _box(
          c,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _doorHeading(c, session, door),
              for (final book in _booksAt(session, door.label))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      BookThumbnail(imageUrl: book.imageUrl, width: 40, height: 54, radius: 8),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          book.title.isEmpty ? S.untitled : book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: door.state == 'failed' ? c.textHint : c.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      _notice(c, S.cancelTapCancelBeforeClosingDoor, color: c.accent),
    ], bottom: _buttons([
      if (session.closeDoorFirst && closing == null)
        _notice(c, S.onceDoorClosedTaskEndAutomatically, title: S.closeDoorFirst, icon: Icons.sensor_door_outlined),
      if (notice != null) _notice(c, notice),
      PrimaryButton(
        label: S.finish,
        isLoading: closing == CabinetCloseOutcome.completed,
        onPressed: idle ? () => _flow.close(CabinetCloseOutcome.completed) : null,
      ),
      SecondaryButton(
        label: S.actionCancel,
        isLoading: closing == CabinetCloseOutcome.cancelled,
        onPressed: idle ? () => _flow.close(CabinetCloseOutcome.cancelled) : null,
      ),
    ]));
  }

  Widget _resultItems(AppColors c, CabinetSession session) {
    final items = session.selectedItems;
    if (items.isEmpty) return const SizedBox.shrink();
    return _box(
      c,
      Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[if (i > 0) Divider(height: 20, color: c.divider), _resultRow(c, items[i])],
        ],
      ),
    );
  }

  Widget _resultRow(AppColors c, CabinetSessionItem item) {
    final error = item.error;
    final partial = item.isPartialDeposit ? item.note : null;
    final (String? status, Color color) = item.isDone && partial != null
        ? (CabinetMessages.note(partial, item: item), c.warning)
        : item.isDone
        ? (S.orderCompleted, c.success)
        : error != null
        ? (CabinetMessages.itemNotDone(CabinetMessages.itemError(error)), c.warning)
        : (null, c.textSecondary);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BookThumbnail(imageUrl: item.books.firstOrNull?.imageUrl, width: 36, height: 48, radius: 6),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titles(item),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600, color: c.textPrimary),
              ),
              if (status != null) ...[const SizedBox(height: 2), Text(status, style: TextStyle(fontSize: 12.5, height: 1.4, color: color))],
            ],
          ),
        ),
      ],
    );
  }

  Widget _result(AppColors c, CabinetSession session) {
    final finish = PrimaryButton(label: S.finish, onPressed: _close);
    if (session.status == CabinetSession.completed) {
      return _centered(c, [
        DrawnCheck(color: c.success, size: 96),
        const SizedBox(height: 20),
        Text(
          CabinetMessages.completedTitle(session),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, height: 1.4, fontWeight: FontWeight.bold, color: c.textPrimary),
        ),
        const SizedBox(height: 20),
        _resultItems(c, session),
      ], bottom: finish);
    }
    if (session.status == CabinetSession.partial) {
      return _centered(c, [
        _alertIcon(c, c.warning, Icons.error_outline_rounded),
        const SizedBox(height: 20),
        Text(
          CabinetMessages.partialTitle(session),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, height: 1.4, fontWeight: FontWeight.bold, color: c.textPrimary),
        ),
        const SizedBox(height: 20),
        _resultItems(c, session),
      ], bottom: finish);
    }
    final review = session.needsReview;
    final message = CabinetMessages.result(session.result);
    return _centered(
      c,
      [
        _alertIcon(c, review ? c.accent : c.warning, review ? Icons.support_agent_rounded : Icons.error_outline_rounded),
        const SizedBox(height: 20),
        Text(
          message.isEmpty ? S.taskBeenCancelled : message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, height: 1.5, fontWeight: FontWeight.bold, color: c.textPrimary),
        ),
      ],
      bottom: review
          ? _buttons([finish, SecondaryButton(label: S.contactSupport, onPressed: () => _run(CabinetFlowAction.contactSupport))])
          : _buttons([PrimaryButton(label: S.rescan, onPressed: _flow.rescan), SecondaryButton(label: S.finish, onPressed: _close)]),
    );
  }
}
