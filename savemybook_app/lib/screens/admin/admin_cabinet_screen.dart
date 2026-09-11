import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import 'admin_cabinet_edit_screen.dart';
import '../../utils/app_labels.dart';

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
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return _cabinets;
    return _cabinets
        .where((c) => c.cabinetName.contains(keyword) || c.address.contains(keyword))
        .toList();
  }

  Future<void> _toggleActive(Cabinet cabinet) async {
    final action = cabinet.isActive ? '停用' : '啟用';
    final confirmed = await showConfirmDialog(
      context,
      title: '$action書櫃',
      message: cabinet.isActive
          ? '停用後「${cabinet.cabinetName}」不會再出現在賣家的存放區域選單中。'
          : '啟用後「${cabinet.cabinetName}」會重新開放給賣家選擇。',
      confirmLabel: action,
      isDestructive: cabinet.isActive,
    );
    if (!confirmed || !mounted) return;

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
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, cabinet.isActive ? '書櫃已停用' : '書櫃已啟用');
      _load();
    }
  }

  Future<void> _editSlot(Cabinet cabinet, CabinetSlot slot) async {
    final c = AppColors.of(context);
    const options = [
      (value: 'empty', label: '空置'),
      (value: 'occupied', label: '使用中'),
      (value: 'reserved', label: '已預約'),
      (value: 'maintenance', label: '維修中'),
    ];

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Text('櫃位 ${slot.slotNumber}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
            const SizedBox(height: 8),
            ...options.map(
              (o) => ListTile(
                title: Text(o.label, style: TextStyle(color: c.textPrimary)),
                trailing: slot.status == o.value
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, o.value),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked == null || picked == slot.status || !mounted) return;

    final ok = await runBusy(
      context,
      () => _api.updateSlotStatus(cabinet.cabinetId, slot.slotId, picked),
    );
    if (!mounted) return;

    if (ok == true) {
      showAppSnackBar(context, '櫃位狀態已更新');
      _load();
    } else {
      showAppSnackBar(context, AppLabels.updateFailed, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: '書櫃監控',
            icon: Icons.storage_rounded,
            actions: [
              HeaderIconButton(
                icon: Icons.add_rounded,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminCabinetEditScreen()),
                  );
                  _load();
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AppSearchField(
              controller: _searchController,
              hint: '搜尋書櫃名稱或地址',
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView.list()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: SwitchIn(child: _filtered.isEmpty
                        ? ListView(key: const ValueKey('empty'), 
                            children: const [
                              SizedBox(height: 80),
                              EmptyView(icon: Icons.inbox_outlined, message: '沒有符合條件的書櫃'),
                            ],
                          )
                        : ListView.builder(key: const ValueKey('items'), 
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => RevealOnScroll(index: i, child: _buildCabinetCard(_filtered[i], c)),
                          )),
                  )),
          ),
        ],
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
              Text(
                cabinet.cabinetName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              const SizedBox(width: 8),
              if (!cabinet.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('已停用',
                      style: TextStyle(fontSize: 10, color: Colors.orangeAccent)),
                ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  cabinet.isActive ? Icons.power_settings_new_rounded : Icons.play_arrow_rounded,
                  size: 20,
                  color: cabinet.isActive ? c.danger : c.success,
                ),
                onPressed: () => _toggleActive(cabinet),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.edit_outlined, size: 20, color: c.iconInactive),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminCabinetEditScreen(cabinet: cabinet)),
                  );
                  _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('剩餘空間：$available / ${cabinet.totalSlots}',
              style: TextStyle(fontSize: 13, color: c.textSecondary)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, animated, _) => LinearProgressIndicator(
                value: animated,
                minHeight: 6,
                backgroundColor: c.inputFill,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
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
                Text(cabinet.openHours, style: TextStyle(fontSize: 12, color: c.textSecondary)),
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

    return GestureDetector(
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
