import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

class AdminCategoryScreen extends StatefulWidget {
  const AdminCategoryScreen({super.key});

  @override
  State<AdminCategoryScreen> createState() => _AdminCategoryScreenState();
}

class _AdminCategoryScreenState extends State<AdminCategoryScreen> {
  final ApiService _api = ApiService();
  List<AdminCategory> _categories = [];
  bool _isLoading = true;
  bool _isReordering = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static bool _isCancelled(String error) => error.isEmpty || error == S.verificationCancelled;

  Future<void> _retry() async {
    setState(() => _isLoading = true);
    await _load();
  }

  Future<void> _load() async {
    final categories = await _api.fetchAdminCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (_isReordering) return;

    // ReorderableListView 的 newIndex 是「移除前」的索引，往下拖要扣一。
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (target == oldIndex) return;

    final previous = List<AdminCategory>.from(_categories);
    final reordered = List<AdminCategory>.from(_categories);
    reordered.insert(target, reordered.removeAt(oldIndex));

    HapticFeedback.selectionClick();
    setState(() {
      _categories = reordered;
      _isReordering = true;
    });

    final error = await _api.reorderCategories(
      reordered.map((e) => e.categoryId).toList(),
    );
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _categories = previous;
        _isReordering = false;
      });
      if (!_isCancelled(error)) showAppSnackBar(context, error, isError: true);
      return;
    }

    setState(() => _isReordering = false);
    await _load();
  }

  Future<void> _edit({AdminCategory? category}) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await _runEdit(category);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _runEdit(AdminCategory? category) async {
    final c = AppColors.of(context);
    final nameController = TextEditingController(text: category?.name ?? '');
    String? nameError;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void submit() {
            final name = nameController.text.trim();
            String? error;
            if (name.isEmpty) {
              error = S.enterCategoryName;
            } else if (_categories.any((e) =>
                e.categoryId != category?.categoryId && e.name.trim().toLowerCase() == name.toLowerCase())) {
              error = S.categoryWithNameAlreadyExists;
            }
            if (error != null) {
              HapticFeedback.lightImpact();
              setSheetState(() => nameError = error);
              return;
            }
            Navigator.pop(ctx, true);
          }

          return SafeArea(
            child: Padding(
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
                    category == null ? S.newCategory : S.editCategory,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: nameController,
                    hint: S.categoryName,
                    maxLength: 50,
                    errorText: nameError,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                    onChanged: (_) {
                      if (nameError != null) setSheetState(() => nameError = null);
                    },
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(label: S.actionSave, height: 46, onPressed: submit),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (saved != true || !mounted) return;

    final name = nameController.text.trim();
    if (category != null && name == category.name) return;

    final error = await runBusy(
      context,
      () => _api.saveCategory(
        categoryId: category?.categoryId,
        name: name,
        sortOrder: category?.sortOrder ?? _categories.length,
      ),
    );
    if (!mounted) return;

    if (error != null) {
      if (!_isCancelled(error)) showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, category == null ? S.categoryAdded : S.categoryUpdated);
      await _load();
    }
  }

  Future<void> _delete(AdminCategory category) async {
    if (_isBusy || _isReordering) return;
    final ok = await showConfirmDialog(
      context,
      title: S.deleteCategory,
      message: category.bookCount > 0
          ? '${S.deleteP0CannotUndone2(category.name)}\n\n${S.p0BooksUse(category.bookCount)}'
          : S.deleteP0CannotUndone2(category.name),
      confirmLabel: S.actionDelete,
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _isBusy = true);
    final error = await runBusy(context, () => _api.deleteCategory(category.categoryId));
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (error != null) {
      if (!_isCancelled(error)) showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, S.categoryDeleted);
      await _load();
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
            title: S.categories,
            icon: Icons.category_outlined,
            actions: [
              HeaderIconButton(icon: Icons.add_rounded, onTap: _isBusy ? null : () => _edit()),
            ],
          ),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: SwitchIn(child: _categories.isEmpty
                          ? ListView(key: const ValueKey('empty'), 
                              children: [
                                SizedBox(height: 60),
                                EmptyView(
                                  icon: Icons.category_outlined,
                                  message: S.noCategoriesYet,
                                  actionLabel: S.newCategory,
                                  onAction: () => _edit(),
                                ),
                                Center(
                                  child: TextButton(
                                    onPressed: _retry,
                                    child: Text(S.refresh, style: TextStyle(color: c.textSecondary)),
                                  ),
                                ),
                              ],
                            )
                          : ReorderableListView.builder(key: const ValueKey('items'), 
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: _categories.length,
                              onReorder: _onReorder,
                              buildDefaultDragHandles: false,
                              proxyDecorator: (child, index, animation) => AnimatedBuilder(
                                animation: animation,
                                builder: (context, _) => Transform.scale(
                                  scale: 1 + 0.04 * Curves.easeOut.transform(animation.value),
                                  child: Material(
                                    color: Colors.transparent,
                                    elevation: 8 * animation.value,
                                    borderRadius: BorderRadius.circular(16),
                                    shadowColor: c.shadow,
                                    child: child,
                                  ),
                                ),
                              ),
                              itemBuilder: (_, i) => _buildCard(
                                _categories[i],
                                c,
                                index: i,
                                key: ValueKey(_categories[i].categoryId),
                              ),
                            )),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AdminCategory category, AppColors c, {required int index, required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: FadeSlideIn(
      index: index,
      child: AppCard(
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
              '${index + 1}',
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  S.p0BooksUse(category.bookCount),
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: c.iconInactive, size: 20),
            onPressed: _isBusy ? null : () => _delete(category),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(left: 2, right: 2),
              child: Icon(Icons.drag_handle_rounded, color: c.iconInactive, size: 22),
            ),
          ),
        ],
      ),
      ),
      ),
    );
  }
}
