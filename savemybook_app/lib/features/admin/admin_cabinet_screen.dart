import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import 'admin_cabinet_edit_screen.dart';
import '../../utils/app_labels.dart';
import '../../i18n/strings.dart';
import 'admin_layout.dart';

class AdminCabinetScreen extends StatefulWidget {
  const AdminCabinetScreen({super.key});

  @override
  State<AdminCabinetScreen> createState() => _AdminCabinetScreenState();
}

class _AdminCabinetScreenState extends State<AdminCabinetScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Cabinet> _cabinets = [];
  bool _isLoading = true;
  bool _isBusy = false;
  bool _navigating = false;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cabinets = await _api.fetchAdminCabinets();
    if (!mounted) return;
    setState(() {
      _cabinets = cabinets;
      _isLoading = false;
    });
  }

  List<Cabinet> get _filtered {
    final keyword = _searchController.text.trim().toLowerCase();
    return _cabinets.where((cabinet) {
      if (_status == 'active' && !cabinet.isActive) return false;
      if (_status == 'disabled' && cabinet.isActive) return false;
      if (_status == 'maintenance' && !cabinet.isMaintenance && (cabinet.slotSummary['maintenance'] ?? 0) == 0) {
        return false;
      }
      if (keyword.isEmpty) return true;
      return cabinet.cabinetName.toLowerCase().contains(keyword) ||
          cabinet.address.toLowerCase().contains(keyword);
    }).toList();
  }

  static bool _isCancelled(String error) => error.isEmpty || error == S.verificationCancelled;

  Future<void> _openEditor([Cabinet? cabinet]) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminCabinetEditScreen(cabinet: cabinet)),
      );
    } finally {
      _navigating = false;
    }
    if (mounted) _load();
  }

  Future<void> _toggleActive(Cabinet cabinet) async {
    if (_isBusy) return;
    final action = cabinet.isActive ? S.disable : S.enable;
    final confirmed = await showConfirmDialog(
      context,
      title: S.p0Locker(action),
      message: cabinet.isActive
          ? S.onceDisabledP0NoLongerAppears(cabinet.cabinetName)
          : S.onceEnabledP0AvailableSellersAgain(cabinet.cabinetName),
      confirmLabel: action,
      isDestructive: cabinet.isActive,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    final error = await runBusy(
      context,
      () => _api.saveCabinet(
        cabinetId: cabinet.cabinetId,
        name: cabinet.cabinetName,
        address: cabinet.address,
        latitude: cabinet.latitude,
        longitude: cabinet.longitude,
        isActive: !cabinet.isActive,
      ),
    );
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (error != null) {
      if (!_isCancelled(error)) showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, cabinet.isActive ? S.lockerDisabled : S.lockerEnabled);
      await _load();
    }
  }

  Future<void> _toggleMaintenance(Cabinet cabinet) async {
    if (_isBusy) return;
    final on = !cabinet.isMaintenance;
    final confirmed = await showConfirmDialog(
      context,
      title: on ? S.markLockerMaintenance : S.endLockerMaintenance,
      message: on
          ? S.maintenanceHidesP0FromSellers(cabinet.cabinetName)
          : S.endingMaintenanceP0AvailableAgain(cabinet.cabinetName),
      confirmLabel: on ? S.markLockerMaintenance : S.endLockerMaintenance,
      isDestructive: on,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    final error = await runBusy(context, () => _api.setCabinetMaintenance(cabinet.cabinetId, on));
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (error != null) {
      if (!_isCancelled(error)) showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, on ? S.lockerMarkedMaintenance : S.lockerMaintenanceEnded);
      await _load();
    }
  }

  Future<void> _editSlot(Cabinet cabinet, CabinetSlot slot) async {
    if (_isBusy) return;
    final c = AppColors.of(context);
    final options = <({String value, String label})>[
      (value: 'empty', label: S.slotEmpty),
      (value: 'occupied', label: S.slotOccupied),
      (value: 'reserved', label: S.slotReserved),
      (value: 'maintenance', label: S.slotMaintenance),
    ];

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              Text(S.slotP0(slot.slotNumber),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
              const SizedBox(height: 2),
              Text('${cabinet.cabinetName}・${slot.statusText}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textSecondary)),
              const SizedBox(height: 8),
              ...options.map(
                (o) => ListTile(
                  leading: Icon(Icons.circle, size: 12, color: c.slotStatusColor(o.value)),
                  title: Text(o.label, style: TextStyle(color: c.textPrimary)),
                  trailing: slot.status == o.value
                      ? Icon(Icons.check_rounded, color: c.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, o.value),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (picked == null || picked == slot.status || !mounted) return;

    if (slot.status == 'occupied' || slot.status == 'reserved') {
      final label = options.firstWhere((o) => o.value == picked).label;
      final ok = await showConfirmDialog(
        context,
        title: S.slotP0(slot.slotNumber),
        message: S.slotCurrentlyP0MayOrderProgress(slot.statusText, label),
        confirmLabel: S.confirm,
        isDestructive: true,
      );
      if (!ok || !mounted) return;
    }

    setState(() => _isBusy = true);
    final ok = await runBusy(
      context,
      () => _api.updateSlotStatus(cabinet.cabinetId, slot.slotId, picked),
    );
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (ok == true) {
      showAppSnackBar(context, S.slotStatusUpdated);
      await _load();
    } else {
      showAppSnackBar(context, AppLabels.updateFailed, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final filtered = _filtered;
    final hasQuery = _searchController.text.trim().isNotEmpty || _status != 'all';

    return Scaffold(
      backgroundColor: c.scaffold,
      body: AdminLayout(
        builder: (context, frame) => Column(
          children: [
            AppHeader(
              title: S.lockerMonitor,
              icon: Icons.storage_rounded,
              actions: [
                HeaderIconButton(
                  icon: Icons.add_rounded,
                  onTap: () => _openEditor(),
                ),
              ],
            ),
            Padding(
              padding: frame.inset(const EdgeInsets.fromLTRB(16, 16, 16, 8)),
              child: AppSearchField(
                controller: _searchController,
                hint: S.searchLockerNameAddress,
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: frame.inset(const EdgeInsets.symmetric(horizontal: 16)),
                children: [
                  _chip(S.actionAll, 'all', c),
                  _chip(S.active, 'active', c),
                  _chip(S.disabled, 'disabled', c),
                  _chip(S.slotMaintenance, 'maintenance', c),
                ],
              ),
            ),
            Expanded(
              child: SwitchIn(child: _isLoading
                  ? const LoadingView.list()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: SwitchIn(child: filtered.isEmpty
                          ? ListView(key: const ValueKey('empty'),
                              children: [
                                const SizedBox(height: 80),
                                EmptyView(
                                  icon: Icons.inbox_outlined,
                                  message: S.noLockersMatch,
                                  actionLabel: hasQuery ? S.clearFilters : S.refresh,
                                  onAction: () {
                                    if (hasQuery) {
                                      _searchController.clear();
                                      setState(() => _status = 'all');
                                    } else {
                                      _load();
                                    }
                                  },
                                ),
                              ],
                            )
                          : ListView.builder(key: ValueKey('items_$_status'),
                              padding: frame.inset(const EdgeInsets.fromLTRB(16, 12, 16, 24)),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => RevealOnScroll(index: i, child: _buildCabinetCard(filtered[i], c)),
                            )),
                    )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, AppColors c) {
    final selected = _status == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressableScale(
        scale: 0.94,
        onTap: () => setState(() => _status = value),
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

  Widget _buildCabinetCard(Cabinet cabinet, AppColors c) {
    final available = cabinet.slotSummary['empty'] ?? cabinet.availableSlots;
    final total = cabinet.totalSlots == 0 ? 1 : cabinet.totalSlots;
    final ratio = (available / total).clamp(0.0, 1.0);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      cabinet.cabinetName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    if (!cabinet.isActive) StatusBadge(label: S.disabled, color: c.warning, fontSize: 10),
                    if (cabinet.isMaintenance) StatusBadge(label: S.slotMaintenance, color: c.danger, fontSize: 10),
                  ],
                ),
              ),
              if (cabinet.maintenanceSupported)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: cabinet.isMaintenance ? S.endLockerMaintenance : S.markLockerMaintenance,
                  icon: Icon(
                    cabinet.isMaintenance ? Icons.build_circle_rounded : Icons.build_outlined,
                    size: 20,
                    color: cabinet.isMaintenance ? c.danger : c.iconInactive,
                  ),
                  onPressed: _isBusy ? null : () => _toggleMaintenance(cabinet),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: cabinet.isActive ? S.disable : S.enable,
                icon: Icon(
                  cabinet.isActive ? Icons.power_settings_new_rounded : Icons.play_arrow_rounded,
                  size: 20,
                  color: cabinet.isActive ? c.danger : c.success,
                ),
                onPressed: _isBusy ? null : () => _toggleActive(cabinet),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.edit_outlined, size: 20, color: c.iconInactive),
                onPressed: () => _openEditor(cabinet),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(S.freeSlotsP0P1(available, cabinet.totalSlots),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.textSecondary)),
              ),
              if ((cabinet.slotSummary['maintenance'] ?? 0) > 0)
                StatusBadge(
                  label: '${S.slotMaintenance} ${cabinet.slotSummary['maintenance']}',
                  color: c.danger,
                  fontSize: 10,
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, animated, _) => LinearProgressIndicator(
                value: animated,
                minHeight: 6,
                backgroundColor: c.inputFill,
                valueColor: AlwaysStoppedAnimation(c.accent),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: c.iconInactive),
              const SizedBox(width: 4),
              Expanded(
                child: Text(cabinet.address,
                    style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.3)),
              ),
            ],
          ),
          if (cabinet.openHours.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: c.iconInactive),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(cabinet.openHours, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ),
              ],
            ),
          ],
          if (cabinet.slots.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: c.divider),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cabinet.slots.map((slot) => _buildSlotChip(cabinet, slot, c)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotChip(Cabinet cabinet, CabinetSlot slot, AppColors c) {
    Color color;
    switch (slot.status) {
      case 'occupied':
        color = c.accent;
        break;
      case 'reserved':
        color = c.warning;
        break;
      case 'maintenance':
        color = c.danger;
        break;
      case 'empty':
      default:
        color = c.iconInactive;
    }

    return PressableScale(
      scale: 0.92,
      onTap: () => _editSlot(cabinet, slot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          '${slot.slotNumber}・${slot.statusText}',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }
}
