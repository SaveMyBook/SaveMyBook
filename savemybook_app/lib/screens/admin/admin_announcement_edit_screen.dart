import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

class AdminAnnouncementEditScreen extends StatefulWidget {
  final Announcement? announcement;
  const AdminAnnouncementEditScreen({super.key, this.announcement});

  @override
  State<AdminAnnouncementEditScreen> createState() => _AdminAnnouncementEditScreenState();
}

class _AdminAnnouncementEditScreenState extends State<AdminAnnouncementEditScreen> {
  List<({String value, String label})> get _types => [
    (value: 'general', label: S.announcement),
    (value: 'maintenance', label: S.maintenance),
    (value: 'promotion', label: S.promotions),
    (value: 'policy', label: S.policyUpdate),
  ];

  final ApiService _api = ApiService();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late String _type;
  late bool _isPublished;
  bool _isSaving = false;

  bool get _isEdit => widget.announcement != null;

  @override
  void initState() {
    super.initState();
    final announcement = widget.announcement;
    _titleController = TextEditingController(text: announcement?.title ?? '');
    _contentController = TextEditingController(text: announcement?.content ?? '');
    _type = announcement?.type ?? 'general';
    _isPublished = announcement?.isPublished ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      showAppSnackBar(context, '請填寫標題與內容', isError: true);
      return;
    }
    if (title.length > 255) {
      showAppSnackBar(context, '標題不可超過 255 個字元', isError: true);
      return;
    }
    if (content.length < 5) {
      showAppSnackBar(context, '內容至少 5 個字元', isError: true);
      return;
    }

    if (_isPublished) {
      final confirmed = await showConfirmDialog(
        context,
        title: '發布推播',
        message: '發布後全體使用者都會看到這則公告，確定發布嗎？',
        confirmLabel: '發布',
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _isSaving = true);
    final error = await _api.saveAnnouncement(
      announcementId: widget.announcement?.announcementId,
      title: title,
      content: content,
      type: _type,
      isPublished: _isPublished,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, _isPublished ? '公告已發布' : '草稿已儲存');
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: _isEdit ? '編輯推播' : '新增推播', icon: Icons.campaign_outlined),
          Expanded(
            child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FormRowCard(
                    label: '標題',
                    labelWidth: 60,
                    child: AppTextField(controller: _titleController, hint: '公告標題', maxLength: 255),
                  ),
                  FormRowCard(
                    label: S.type,
                    labelWidth: 60,
                    child: AppDropdownField<String>(
                      value: _type,
                      items: _types
                          .map((t) => DropdownMenuItem(value: t.value, child: Text(t.label)))
                          .toList(),
                      onChanged: (value) => setState(() => _type = value ?? _type),
                    ),
                  ),
                  FormRowCard(
                    label: S.content,
                    labelWidth: 60,
                    alignTop: true,
                    child: AppTextField(
                      controller: _contentController,
                      maxLines: 6,
                      maxLength: 2000,
                      hint: '輸入推播內容',
                    ),
                  ),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isPublished,
                      activeThumbColor: c.accent,
                      title: Text('立即發布',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                      subtitle: Text('關閉時只會存成草稿',
                          style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      onChanged: (value) => setState(() => _isPublished = value),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: c.accent.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isPublished ? '發布推播' : '儲存草稿',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
