import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';

class AdminCategoryScreen extends StatefulWidget {
  const AdminCategoryScreen({super.key});

  @override
  State<AdminCategoryScreen> createState() => _AdminCategoryScreenState();
}

class _AdminCategoryScreenState extends State<AdminCategoryScreen> {
  final ApiService _api = ApiService();
  List<AdminCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final categories = await _api.fetchAdminCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  Future<void> _edit({AdminCategory? category}) async {
    final c = AppColors.of(context);
    final nameController = TextEditingController(text: category?.name ?? '');
    final orderController =
        TextEditingController(text: '${category?.sortOrder ?? _categories.length}');

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category == null ? '新增分類' : '編輯分類',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 16),
            AppTextField(controller: nameController, hint: '分類名稱', maxLength: 50),
            const SizedBox(height: 12),
            AppTextField(
              controller: orderController,
              hint: '排序（數字越小越前面）',
              keyboardType: TextInputType.number,
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
                child: const Text('儲存', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      showAppSnackBar(context, '請輸入分類名稱', isError: true);
      return;
    }

    final error = await runBusy(
      context,
      () => _api.saveCategory(
        categoryId: category?.categoryId,
        name: name,
        sortOrder: int.tryParse(orderController.text.trim()) ?? 0,
      ),
    );
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, category == null ? '已新增分類' : '已更新分類');
      _load();
    }
  }

  Future<void> _delete(AdminCategory category) async {
    final ok = await showConfirmDialog(
      context,
      title: '刪除分類',
      message: '要刪除「${category.name}」嗎？此動作無法復原。',
      confirmLabel: '刪除',
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    final error = await runBusy(context, () => _api.deleteCategory(category.categoryId));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, '已刪除分類');
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
            title: '分類管理',
            icon: Icons.category_outlined,
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
                      child: _categories.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 60),
                                EmptyView(
                                  icon: Icons.category_outlined,
                                  message: '還沒有任何分類\n點右上角新增一個',
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                              itemCount: _categories.length,
                              itemBuilder: (_, i) => FadeSlideIn(
                                index: i,
                                child: _buildCard(_categories[i], c),
                              ),
                            ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AdminCategory category, AppColors c) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _edit(category: category),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${category.sortOrder}',
              style: TextStyle(fontWeight: FontWeight.bold, color: c.accent),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${category.bookCount} 本書使用中',
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: c.iconInactive, size: 20),
            onPressed: () => _delete(category),
          ),
        ],
      ),
    );
  }
}
