import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

class AdminLevelScreen extends StatefulWidget {
  const AdminLevelScreen({super.key});

  @override
  State<AdminLevelScreen> createState() => _AdminLevelScreenState();
}

class _AdminLevelScreenState extends State<AdminLevelScreen> {
  final ApiService _api = ApiService();
  List<AdminLevel> _levels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final levels = await _api.fetchAdminLevels();
    if (!mounted) return;
    setState(() {
      _levels = levels;
      _isLoading = false;
    });
  }

  Future<void> _edit({AdminLevel? level}) async {
    final c = AppColors.of(context);
    final nameController = TextEditingController(text: level?.name ?? '');
    final minController = TextEditingController(text: '${level?.minPoints ?? 0}');
    final maxController = TextEditingController(text: level?.maxPoints?.toString() ?? '');
    final benefitsController = TextEditingController(text: level?.benefits ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                level == null ? '新增等級' : '編輯等級',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              const SizedBox(height: 16),
              AppTextField(controller: nameController, hint: '等級名稱', maxLength: 50),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: minController,
                      hint: '最低點數',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      controller: maxController,
                      hint: '最高點數（留空 = 無上限）',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: benefitsController,
                hint: '權益，用頓號或換行分隔，會在會員等級頁逐條顯示',
                maxLines: 4,
                maxLength: 500,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(S.actionSave, style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || !mounted) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      showAppSnackBar(context, '請輸入等級名稱', isError: true);
      return;
    }

    final minPoints = int.tryParse(minController.text.trim()) ?? 0;
    final maxText = maxController.text.trim();
    final maxPoints = maxText.isEmpty ? null : int.tryParse(maxText);

    if (maxPoints != null && maxPoints <= minPoints) {
      showAppSnackBar(context, '最高點數必須大於最低點數', isError: true);
      return;
    }

    final error = await runBusy(
      context,
      () => _api.saveLevel(
        levelId: level?.levelId,
        name: name,
        minPoints: minPoints,
        maxPoints: maxPoints,
        benefits: benefitsController.text.trim(),
      ),
    );
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, level == null ? '已新增等級' : '已更新等級');
      _load();
    }
  }

  Future<void> _delete(AdminLevel level) async {
    final ok = await showConfirmDialog(
      context,
      title: '刪除等級',
      message: '要刪除「${level.name}」嗎？已在這個等級的會員會退到下一個符合的等級。',
      confirmLabel: S.actionDelete,
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    final error = await runBusy(context, () => _api.deleteLevel(level.levelId));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, '已刪除等級');
      _load();
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
            title: '會員等級管理',
            icon: Icons.workspace_premium_outlined,
            actions: [
              HeaderIconButton(icon: Icons.add_rounded, onTap: () => _edit()),
            ],
          ),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: SwitchIn(child: _levels.isEmpty
                          ? ListView(key: const ValueKey('empty'), 
                              children: const [
                                SizedBox(height: 60),
                                EmptyView(
                                  icon: Icons.workspace_premium_outlined,
                                  message: '尚未設定會員等級',
                                ),
                              ],
                            )
                          : ListView.builder(key: const ValueKey('items'), 
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                              itemCount: _levels.length,
                              itemBuilder: (_, i) => RevealOnScroll(
                                index: i,
                                child: _buildCard(_levels[i], c),
                              ),
                            )),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AdminLevel level, AppColors c) {
    final range = level.maxPoints == null
        ? '${level.minPoints} 點以上'
        : '${level.minPoints} ~ ${level.maxPoints} 點';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _edit(level: level),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, size: 20, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  level.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Text(range, style: TextStyle(fontSize: 12, color: c.textSecondary)),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: c.iconInactive, size: 20),
                onPressed: () => _delete(level),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            level.benefits.isEmpty ? '尚未填寫權益說明' : level.benefits,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: level.benefits.isEmpty ? c.textHint : c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
