import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_labels.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_select.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../cabinet/cabinet_messages.dart';
import '../selling/book_deposit_actions.dart';
import '../../i18n/strings.dart';
import 'admin_cabinet_open_sheet.dart';
import 'admin_layout.dart';

String _cabinetOf(CabinetDeposit item) => item.cabinetName.isEmpty ? S.faqCatCabinet : item.cabinetName;

Future<bool> confirmDepositRemoval(BuildContext context, CabinetDeposit item) => showConfirmDialog(
  context,
  title: S.recordRemoval,
  message: item.bookStatus == 'on_sale'
      ? S.confirmStaffRemovedP1FromP0(_cabinetOf(item), item.title)
      : S.confirmStaffRemovedBookFromLocker(_cabinetOf(item), item.title),
  confirmLabel: S.recordRemoval,
  isDestructive: true,
  icon: Icons.outbox_outlined,
);

class AdminCabinetDepositScreen extends StatefulWidget {
  final bool initialOverdue;

  const AdminCabinetDepositScreen({super.key, this.initialOverdue = false});

  @override
  State<AdminCabinetDepositScreen> createState() => _AdminCabinetDepositScreenState();
}

class _AdminCabinetDepositScreenState extends State<AdminCabinetDepositScreen> {
  final ApiService _api = ApiService();

  List<CabinetDeposit> _items = [];
  List<Cabinet> _cabinets = [];
  bool _isLoading = true;
  late bool _overdue = widget.initialOverdue;
  int? _cabinetId;
  int _page = 1;
  int _removed = 0;
  bool _hasMore = false;
  bool _loadingMore = false;
  int? _busyBookId;
  int _requestId = 0;

  bool get _filtered => _overdue || _cabinetId != null;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCabinets();
  }

  Future<void> _loadCabinets() async {
    final cabinets = await _api.fetchAdminCabinets();
    if (mounted) setState(() => _cabinets = cabinets);
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    final page = await _api.fetchCabinetDeposits(overdue: _overdue, cabinetId: _cabinetId);
    if (!mounted || requestId != _requestId) return;
    setState(() {
      if (page.ok || _isLoading) {
        _items = page.items;
        _page = 1;
        _removed = 0;
        _hasMore = page.hasMore;
      }
      _isLoading = false;
      _loadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore || _loadingMore) return;
    final requestId = _requestId;
    final removed = _removed;
    // 已登記取出的書會從伺服器的分頁中消失，後面的書往前遞補；下一頁須依移除筆數回推，否則會漏掉遞補的書。
    const size = AdminCabinetsApi.cabinetDepositPageSize;
    final next = math.max(1, (_page * size - removed) ~/ size + 1);
    setState(() => _loadingMore = true);
    final page = await _api.fetchCabinetDeposits(overdue: _overdue, cabinetId: _cabinetId, page: next);
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _loadingMore = false;
      if (!page.ok) {
        _hasMore = false;
        return;
      }
      final known = _items.map((d) => d.bookId).toSet();
      _items = [..._items, ...page.items.where((d) => !known.contains(d.bookId))];
      _page = next;
      _removed -= removed;
      _hasMore = page.hasMore;
    });
  }

  void _setFilter({required bool overdue, required int? cabinetId}) {
    if (overdue == _overdue && cabinetId == _cabinetId) return;
    HapticFeedback.selectionClick();
    setState(() {
      _overdue = overdue;
      _cabinetId = cabinetId;
      _isLoading = true;
    });
    _load();
  }

  Future<void> _pickCabinet() async {
    final c = AppColors.of(context);
    final picked = await showAppPicker<int>(
      context,
      title: S.faqCatCabinet,
      selected: _cabinetId ?? 0,
      options: [
        AppSelectOption(value: 0, label: S.allLockers, icon: Icons.inventory_2_outlined),
        for (final cabinet in _cabinets)
          AppSelectOption(
            value: cabinet.cabinetId,
            label: cabinet.cabinetName,
            subtitle: cabinet.address.isEmpty ? null : cabinet.address,
            icon: Icons.storage_rounded,
            badge: !cabinet.isActive ? S.disabled : (cabinet.isMaintenance ? S.slotMaintenance : null),
            badgeColor: !cabinet.isActive ? c.warning : (cabinet.isMaintenance ? c.danger : null),
          ),
      ],
    );
    if (picked == null || !mounted) return;
    _setFilter(overdue: _overdue, cabinetId: picked == 0 ? null : picked);
  }

  Future<void> _clear(CabinetDeposit item) async {
    if (_busyBookId != null) return;
    final confirmed = await confirmDepositRemoval(context, item);
    if (!confirmed || !mounted) return;

    setState(() => _busyBookId = item.bookId);
    final error = await _api.clearCabinetDeposit(item.bookId);
    if (!mounted) return;
    setState(() {
      _busyBookId = null;
      if (error == null) {
        final before = _items.length;
        _items = _items.where((d) => d.bookId != item.bookId).toList();
        _removed += before - _items.length;
      }
    });
    if (error != null) {
      if (error.isNotEmpty && error != S.verificationCancelled) showAppSnackBar(context, error, isError: true);
      _load();
    } else {
      HapticFeedback.mediumImpact();
      showAppSnackBar(context, S.removalRecorded);
      if (_items.isEmpty && _hasMore) _load();
    }
  }

  Future<void> _openDoor(CabinetDeposit item) async {
    final cabinetId = item.cabinetId;
    final slotId = item.doorSlotId;
    final label = item.doorLabel;
    if (_busyBookId != null || cabinetId == null || slotId == null || label == null) return;
    final result = await showAdminCabinetOpenSheet(
      context,
      cabinetId: cabinetId,
      slotId: slotId,
      label: label,
      cabinetName: _cabinetOf(item),
      initialReason: S.staffRetrievalOverdueBooks,
    );
    final finished = result.finished;
    if (!mounted || finished == null) return;
    if (finished.status == 'completed') {
      showAppSnackBar(context, S.checkContentsDoorP0(label));
    } else {
      showAppSnackBar(context, CabinetMessages.result(finished.result), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: AdminLayout(
        builder: (context, frame) {
          EdgeInsets inset(double top, double bottom) => frame.isWide
              ? frame.inset(EdgeInsets.fromLTRB(24, top, 24, bottom), maxWidth: 1200)
              : frame.inset(EdgeInsets.fromLTRB(16, top, 16, bottom));
          final columns = frame.isWide
              ? Breakpoints.columnsFor(math.min(frame.width, 1200) - 48, minTileWidth: 380, min: 1, max: 3)
              : 1;
          final rows = (_items.length / columns).ceil();
          return Column(
            children: [
              AppHeader(title: S.booksLockers, icon: Icons.inventory_2_outlined),
              Padding(
                padding: inset(12, 0),
                child: SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      Expanded(
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _chip(S.actionAll, !_overdue, () => _setFilter(overdue: false, cabinetId: _cabinetId), c),
                            _chip(S.overdue, _overdue, () => _setFilter(overdue: true, cabinetId: _cabinetId), c),
                          ],
                        ),
                      ),
                      if (_cabinets.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 170),
                          child: _buildCabinetFilter(c),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SwitchIn(
                  child: _isLoading
                      ? LoadingView.list(key: ValueKey('loading_${_overdue}_$_cabinetId'))
                      : RefreshIndicator(
                          key: ValueKey('list_${_overdue}_$_cabinetId'),
                          color: c.accent,
                          onRefresh: _load,
                          child: _items.isEmpty
                              ? ListView(
                                  children: [
                                    const SizedBox(height: 80),
                                    EmptyView(
                                      icon: Icons.inventory_2_outlined,
                                      message: _overdue ? S.noOverdueBooks : S.noBooksCurrentlyStoredLockers,
                                      actionLabel: _filtered ? S.clearFilters : S.refresh,
                                      onAction: _filtered ? () => _setFilter(overdue: false, cabinetId: null) : _load,
                                    ),
                                  ],
                                )
                              : NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    if (notification.metrics.extentAfter < 400) _loadMore();
                                    return false;
                                  },
                                  child: ListView.builder(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: inset(12, 24),
                                    itemCount: rows + (_hasMore ? 1 : 0),
                                    itemBuilder: (_, i) {
                                      if (i >= rows) {
                                        if (!_loadingMore) {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (mounted) _loadMore();
                                          });
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          child: Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                                            ),
                                          ),
                                        );
                                      }
                                      if (columns == 1) {
                                        return RevealOnScroll(
                                          key: ValueKey(_items[i].bookId),
                                          index: i,
                                          child: _buildCard(_items[i], c),
                                        );
                                      }
                                      final row = _items.skip(i * columns).take(columns).toList();
                                      return RevealOnScroll(
                                        key: ValueKey(row.map((d) => d.bookId).join(',')),
                                        index: i,
                                        child: IntrinsicHeight(
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              for (var j = 0; j < columns; j++) ...[
                                                if (j > 0) const SizedBox(width: 12),
                                                Expanded(child: j < row.length ? _buildCard(row[j], c, fill: true) : const SizedBox.shrink()),
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
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressableScale(
        scale: 0.94,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.accent : c.categoryChip,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Colors.white : c.accent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCabinetFilter(AppColors c) {
    final selected = _cabinets.where((cab) => cab.cabinetId == _cabinetId).firstOrNull;
    final active = selected != null;
    final fg = active ? Colors.white : c.accent;

    return PressableScale(
      scale: 0.94,
      onTap: _pickCabinet,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 34,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: active ? c.accent : c.categoryChip,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storage_rounded, size: 15, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                selected?.cabinetName ?? S.allLockers,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.bold : FontWeight.w500, color: fg),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(CabinetDeposit item, AppColors c, {bool fill = false}) {
    final seller = item.sellerDeleted || item.sellerName.isEmpty ? S.deletedUser : item.sellerName;
    final cabinet = _cabinetOf(item);
    final door = item.doorLabel;
    final canOpen = item.cabinetId != null && item.doorSlotId != null && door != null;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookThumbnail(imageUrl: item.imageUrl, width: 52, height: 68, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      S.seller3(seller),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    InfoLine(icon: Icons.storage_rounded, value: cabinet, maxLines: 1, fontSize: 12),
                    if (door != null) ...[
                      const SizedBox(height: 2),
                      InfoLine(icon: Icons.sensor_door_outlined, value: S.doorP0(door), maxLines: 1, fontSize: 12),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusBadge(
                          label: storedDaysText(item.daysStored),
                          color: item.overdue ? c.danger : c.accent,
                          fontSize: 10,
                        ),
                        if (item.paused)
                          StatusBadge(label: S.salesPaused, color: c.warning, fontSize: 10)
                        else if (item.bookStatus != 'on_sale')
                          StatusBadge(
                            label: AppLabels.ownerBook(item.bookStatus),
                            color: c.bookStatusColor(item.bookStatus),
                            fontSize: 10,
                          ),
                        if (item.escalated) StatusBadge(label: S.adminsNotified, color: c.danger, fontSize: 10),
                      ],
                    ),
                  ],
                ),
              ),
              if (canOpen)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: S.openDoorRemotely,
                  icon: Icon(Icons.lock_open_rounded, size: 20, color: c.accent),
                  onPressed: _busyBookId != null ? null : () => _openDoor(item),
                ),
            ],
          ),
          if (fill) const Spacer(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatDateTime(item.depositedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.textHint),
                ),
              ),
              const SizedBox(width: 8),
              SmallActionButton(
                label: S.recordRemoval,
                filled: true,
                color: c.danger,
                isLoading: _busyBookId == item.bookId,
                onTap: _busyBookId != null ? null : () => _clear(item),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
