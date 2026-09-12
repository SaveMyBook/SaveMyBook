import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/guards.dart';
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

  late final String _initialTitle;
  late final String _initialContent;

  bool get _isEdit => widget.announcement != null;

  @override
  void initState() {
    super.initState();
    final announcement = widget.announcement;
    _titleController = TextEditingController(text: announcement?.title ?? '');
    _contentController = TextEditingController(text: announcement?.content ?? '');
    _initialTitle = _titleController.text;
    _initialContent = _contentController.text;
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
      showAppSnackBar(context, S.enterTitleContent, isError: true);
      return;
    }
    if (title.length > 255) {
      showAppSnackBar(context, S.titleCannotExceed255Characters, isError: true);
      return;
    }
    if (content.length < 5) {
      showAppSnackBar(context, S.contentNeedsLeast5Characters, isError: true);
      return;
    }

    if (_isPublished) {
      final confirmed = await showConfirmDialog(
        context,
        title: S.publishAnnouncement,
        message: S.everyUserSeeAnnouncementOncePublished,
        confirmLabel: S.publish,
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
      showAppSnackBar(context, _isPublished ? S.announcementPublished : S.draftSaved);
      Navigator.of(context).maybePop();
    }
  }

  /// 公告內容是一整段文字，誤觸返回等於重打。
  bool get _isDirty => _titleController.text != _initialTitle || _contentController.text != _initialContent;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return UnsavedGuard(
      isDirty: _isDirty,
      child: Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: _isEdit ? S.editAnnouncement : S.newAnnouncement, icon: Icons.campaign_outlined),
          Expanded(
            child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FormRowCard(
                    label: S.title2,
                    labelWidth: 60,
                    child: AppTextField(controller: _titleController, hint: S.announcementTitle, maxLength: 255),
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
                      hint: S.writeAnnouncement,
                    ),
                  ),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isPublished,
                      activeThumbColor: c.accent,
                      title: Text(S.publishNow,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                      subtitle: Text(S.leaveOffSaveAsDraft,
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
                          : Text(_isPublished ? S.publishAnnouncement : S.saveDraft,
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
    ),
    );
  }
}
