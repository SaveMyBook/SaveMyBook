import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/strings.dart';
import '../../models/chat.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../books/book_detail_screen.dart';
import '../chat/chat_room_screen.dart';
import 'direct_purchase.dart';
import 'order_history_screen.dart';
import 'widgets/tablet_controls.dart';

bool isHeldReservation(ChatReservation r, DateTime now) =>
    r.isConfirmed && (r.pickupDeadline?.isAfter(now) ?? false);

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late final TabController _tabController = TabController(length: 2, vsync: this);
  late final Timer _ticker;
  List<ChatReservation> _items = const [];
  final Set<int> _busyIds = {};
  bool _loading = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabChanged);
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _ticker.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  bool get _showingHeld => _tabController.index == 0;

  Future<void> _load() async {
    final request = ++_request;
    final items = await _api.fetchMyReservations();
    if (!mounted || request != _request) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  List<ChatReservation> _visible(DateTime now) {
    if (!_showingHeld) return _items.where((r) => r.isPending).toList();
    return _items.where((r) => isHeldReservation(r, now)).toList()
      ..sort((a, b) => a.pickupDeadline!.compareTo(b.pickupDeadline!));
  }

  void _setBusy(int id, bool busy) {
    if (!mounted) return;
    setState(() => busy ? _busyIds.add(id) : _busyIds.remove(id));
  }

  Future<void> _openBook(ChatReservation r) async {
    final book = await runBusy(context, () => _api.fetchBookDetail(r.bookId));
    if (!mounted) return;
    if (book == null) {
      showAppSnackBar(context, S.bookNoLongerListed, isError: true);
      _load();
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)));
    if (mounted) _load();
  }

  Future<void> _openChat(ChatReservation r) async {
    final roomId = r.roomId ?? await runBusy<int?>(context, () => _api.openChatRoom(userId: r.sellerId));
    if (!mounted) return;
    if (roomId == null) {
      showAppSnackBar(context, S.couldNotOpenChatPleaseTry, isError: true);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatRoomScreen(roomId: roomId, partnerName: r.sellerName)),
    );
    if (mounted) _load();
  }

  Future<void> _cancel(ChatReservation r, {required bool held}) async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.cancelReservation,
      message: held ? S.p0NoLongerHeld(r.bookTitle) : null,
      confirmLabel: S.cancelReservation2,
      cancelLabel: S.notNow2,
      isDestructive: true,
      icon: Icons.event_available_rounded,
    );
    if (!confirmed || !mounted) return;

    _setBusy(r.reservationId, true);
    final (updated, error) = await _api.respondReservation(r.reservationId, 'cancel');
    _setBusy(r.reservationId, false);
    if (!mounted) return;
    if (updated == null) {
      showAppSnackBar(context, error ?? S.actionFailed, isError: true);
    } else {
      HapticFeedback.selectionClick();
      showAppSnackBar(context, S.reservationCanceled);
    }
    _load();
  }

  Future<void> _buy(ChatReservation r) async {
    final book = await runBusy(context, () => _api.fetchBookDetail(r.bookId));
    if (!mounted) return;
    if (book == null) {
      showAppSnackBar(context, S.bookNoLongerListed, isError: true);
      _load();
      return;
    }
    final result = await purchaseBookDirectly(
      context,
      book,
      onBusy: (busy) => _setBusy(r.reservationId, busy),
    );
    if (!mounted || result.outcome == DirectPurchaseOutcome.aborted) return;
    _load();
    if (result.outcome != DirectPurchaseOutcome.viewOrders) return;
    if (context.isWide) {
      await OrderHistoryScreen.open(context, filter: OrderHistoryScreen.purchaseFilterAfterPayment(result.readyForPickup));
      if (mounted) _load();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderHistoryScreen(filter: OrderHistoryScreen.purchaseFilterAfterPayment(result.readyForPickup)),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final held = _showingHeld;
    final items = _visible(DateTime.now());

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: S.myReservations,
            icon: Icons.event_available_outlined,
            bottom: AppTabBar(controller: _tabController, tabs: [S.reservationHeld, S.awaitingSellerReply]),
          ),
          Expanded(
            child: SwipeTabs(
              controller: _tabController,
              child: SwitchIn(
                child: _loading
                    ? const LoadingView.list(key: ValueKey('loading'))
                    : items.isEmpty
                    ? RefreshableCenter(
                        key: ValueKey('empty_$held'),
                        onRefresh: _load,
                        child: EmptyView(
                          icon: Icons.event_available_outlined,
                          message: held ? S.noHeldReservations : S.noPendingReservations,
                        ),
                      )
                    : RefreshIndicator(
                        key: ValueKey('list_$held'),
                        color: c.accent,
                        onRefresh: _load,
                        child: context.isWide
                            ? _buildTabletList(items, c, held: held)
                            : LayoutBuilder(
                          builder: (context, constraints) {
                            final bottom = MediaQuery.of(context).padding.bottom + 16;
                            final wide = context.isWide;
                            final columns = wide ? ((constraints.maxWidth - 48 + 12) / 332).floor().clamp(1, 3) : 1;
                            final padding = responsiveListPadding(
                              constraints,
                              maxWidth: columns > 1 ? Breakpoints.listMaxWidth + 160 : Breakpoints.formMaxWidth,
                              horizontal: wide ? 24 : 16,
                              top: wide ? 16 : 12,
                              bottom: bottom,
                            );
                            Widget card(int i) => RevealOnScroll(
                                  key: ValueKey(items[i].reservationId),
                                  index: i,
                                  child: _buildCard(items[i], c, held: held),
                                );
                            final rows = (items.length / columns).ceil();
                            return ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: padding,
                              itemCount: rows,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (_, row) => columns == 1
                                  ? card(row)
                                  // 同一列的卡片等高，按鈕列才會對齊
                                  : IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          for (var col = 0; col < columns; col++) ...[
                                            if (col > 0) const SizedBox(width: 12),
                                            Expanded(
                                              child: row * columns + col < items.length
                                                  ? card(row * columns + col)
                                                  : const SizedBox.shrink(),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletList(List<ChatReservation> items, AppColors c, {required bool held}) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: responsiveListPadding(
          constraints,
          maxWidth: Breakpoints.listMaxWidth,
          horizontal: 24,
          top: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => RevealOnScroll(
          key: ValueKey(items[i].reservationId),
          index: i,
          child: _buildTabletRow(items[i], c, held: held),
        ),
      ),
    );
  }

  void _showMenu(ChatReservation r, {required bool held}) {
    final busy = _busyIds.contains(r.reservationId);
    showItemMenu(
      context,
      title: r.bookTitle,
      actions: [
        MenuAction(S.viewDetails, Icons.menu_book_outlined, () => _openBook(r)),
        MenuAction(S.messageSeller, Icons.chat_bubble_outline_rounded, () => _openChat(r)),
        if (held && !busy) MenuAction(S.buyNow, Icons.shopping_bag_outlined, () => _buy(r)),
        if (!busy) MenuAction(S.cancelReservation2, Icons.event_busy_outlined, () => _cancel(r, held: held), destructive: true),
      ],
    );
  }

  Widget _buildTabletRow(ChatReservation r, AppColors c, {required bool held}) {
    final busy = _busyIds.contains(r.reservationId);
    final deadline = r.pickupDeadline;
    Widget meta(IconData icon, String text, {Color? color}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color ?? c.iconInactive),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: color == null ? FontWeight.normal : FontWeight.w600,
                  color: color ?? c.textSecondary,
                ),
              ),
            ),
          ],
        );
    final details = <Widget>[
      if (r.sellerName.isNotEmpty) meta(Icons.person_outline_rounded, S.seller3(r.sellerName)),
      if (held && deadline != null) ...[
        meta(Icons.lock_clock_rounded, S.heldUntilP03(_formatTime(deadline))),
        meta(Icons.hourglass_bottom_rounded, _timeLeft(deadline), color: c.warning),
      ] else if (r.createdAt != null)
        meta(Icons.schedule_rounded, S.reservationSentAtP0(_formatTime(r.createdAt!))),
    ];
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: S.messageSeller,
          onPressed: () => _openChat(r),
          style: IconButton.styleFrom(
            backgroundColor: c.categoryChip,
            fixedSize: const Size(38, 38),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: Icon(Icons.chat_bubble_outline_rounded, size: 17, color: c.accent),
        ),
        const SizedBox(width: 8),
        Flexible(child: CompactActionButton(label: S.cancelReservation2, onPressed: busy ? null : () => _cancel(r, held: held))),
        if (held) ...[
          const SizedBox(width: 8),
          Flexible(child: CompactActionButton(label: S.buyNow, filled: true, isLoading: busy, onPressed: () => _buy(r))),
        ],
      ],
    );

    return TabletListItem(
      onTap: () => _openBook(r),
      onMenu: () => _showMenu(r, held: held),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, box) {
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      r.bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '\$${r.bookPrice.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.accent),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 16, runSpacing: 4, children: details),
            ],
          );
          final cover = BookThumbnail(imageUrl: r.bookImageUrl, width: 52, height: 70, radius: 8);
          if (box.maxWidth >= 600) {
            return Row(
              children: [
                cover,
                const SizedBox(width: 14),
                Expanded(child: info),
                const SizedBox(width: 16),
                ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxWidth * 0.45), child: actions),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [cover, const SizedBox(width: 14), Expanded(child: info)]),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(ChatReservation r, AppColors c, {required bool held}) {
    final busy = _busyIds.contains(r.reservationId);
    final deadline = r.pickupDeadline;

    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => _openBook(r),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookThumbnail(imageUrl: r.bookImageUrl, width: 64, height: 86),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.bookTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600, color: c.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '\$${r.bookPrice.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.accent),
                      ),
                    ),
                    if (r.sellerName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      InfoLine(icon: Icons.person_outline_rounded, value: S.seller3(r.sellerName), maxLines: 1),
                    ],
                    const SizedBox(height: 4),
                    if (held && deadline != null) ...[
                      InfoLine(icon: Icons.lock_clock_rounded, value: S.heldUntilP03(_formatTime(deadline)), maxLines: 1),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.hourglass_bottom_rounded, size: 13, color: c.warning),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              _timeLeft(deadline),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, height: 1.3, fontWeight: FontWeight.w600, color: c.warning),
                            ),
                          ),
                        ],
                      ),
                    ] else if (r.createdAt != null)
                      InfoLine(
                        icon: Icons.schedule_rounded,
                        value: S.reservationSentAtP0(_formatTime(r.createdAt!)),
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ChatButton(onTap: () => _openChat(r)),
                const SizedBox(width: 8),
                Expanded(
                  child: SmallActionButton(
                    label: S.cancelReservation2,
                    onTap: busy ? null : () => _cancel(r, held: held),
                  ),
                ),
                if (held) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SmallActionButton(
                      label: S.buyNow,
                      filled: true,
                      isLoading: busy,
                      onTap: () => _buy(r),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeLeft(DateTime deadline) {
    final left = deadline.difference(DateTime.now());
    final minutes = left.inMinutes < 1 ? 1 : left.inMinutes;
    if (minutes < 60) return S.reservationTimeLeftMinutes(minutes);
    return S.reservationTimeLeftHoursMinutes(minutes ~/ 60, minutes % 60);
  }

  String _formatTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _ChatButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ChatButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: S.messageSeller,
      child: Semantics(
        button: true,
        label: S.messageSeller,
        child: PressableScale(
          scale: 0.94,
          onTap: onTap,
          child: Container(
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.categoryChip, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 15, color: c.accent),
          ),
        ),
      ),
    );
  }
}
