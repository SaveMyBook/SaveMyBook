import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/guards.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_select.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

class AdminAnnouncementEditScreen extends StatefulWidget {
  final Announcement? announcement;
  const AdminAnnouncementEditScreen({super.key, this.announcement});

  @override
  State<AdminAnnouncementEditScreen> createState() => _AdminAnnouncementEditScreenState();
}

class _AdminAnnouncementEditScreenState extends State<AdminAnnouncementEditScreen> {
  List<({String value, String label, IconData icon})> get _types => [
        (value: 'general', label: S.announcement, icon: Icons.campaign_outlined),
        (value: 'maintenance', label: S.maintenance, icon: Icons.build_circle_outlined),
        (value: 'promotion', label: S.promotions, icon: Icons.local_offer_outlined),
        (value: 'policy', label: S.policyUpdate, icon: Icons.policy_outlined),
      ];

  final ApiService _api = ApiService();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late String _type;
  late bool _isPublished;
  bool _isSaving = false;
  bool _saved = false;
  bool _showErrors = false;

  late final String _initialTitle;
  late final String _initialContent;
  late final String _initialType;
  late final bool _initialPublished;

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
    _initialType = _type;
    _initialPublished = _isPublished;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    setState(() => _showErrors = true);

    if (title.isEmpty || content.isEmpty) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.enterTitleContent, isError: true);
      return;
    }
    if (title.length > 255) {
      showAppSnackBar(context, S.titleCannotExceed255Characters, isError: true);
      return;
    }
    if (content.length < 5) {
      HapticFeedback.heavyImpact();
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

    if (!mounted) return;
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
      setState(() => _saved = true);
      HapticFeedback.mediumImpact();
      showAppSnackBar(context, _isPublished ? S.announcementPublished : S.draftSaved);
      Navigator.of(context).pop(true);
    }
  }

  bool get _isDirty =>
      !_saved &&
      (_titleController.text != _initialTitle ||
          _contentController.text != _initialContent ||
          _type != _initialType ||
          _isPublished != _initialPublished);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return UnsavedGuard(
      isDirty: _isDirty && !_isSaving,
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: Column(
          children: [
            AppHeader(title: _isEdit ? S.editAnnouncement : S.newAnnouncement, icon: Icons.campaign_outlined),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: AbsorbPointer(
                  absorbing: _isSaving,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FormRowCard(
                          label: S.title2,
                          labelWidth: 60,
                          isRequired: true,
                          child: AppTextField(
                            controller: _titleController,
                            hint: S.announcementTitle,
                            maxLength: 255,
                            textInputAction: TextInputAction.next,
                            errorText: _showErrors && _titleController.text.trim().isEmpty ? S.enterTitleContent : null,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        FormRowCard(
                          label: S.type,
                          labelWidth: 60,
                          child: AppSelect<String>(
                            value: _type,
                            title: S.type,
                            options: [
                              for (final t in _types) AppSelectOption(value: t.value, label: t.label, icon: t.icon),
                            ],
                            onChanged: (value) => setState(() => _type = value),
                          ),
                        ),
                        FormRowCard(
                          label: S.content,
                          labelWidth: 60,
                          alignTop: true,
                          isRequired: true,
                          child: AppTextField(
                            controller: _contentController,
                            minLines: 5,
                            maxLines: 10,
                            maxLength: 2000,
                            keyboardType: TextInputType.multiline,
                            hint: S.writeAnnouncement,
                            errorText: _showErrors && _contentController.text.trim().length < 5
                                ? S.contentNeedsLeast5Characters
                                : null,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _isPublished,
                            activeThumbColor: c.accent,
                            title: Text(
                              S.publishNow,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
                            ),
                            subtitle: Text(
                              S.leaveOffSaveAsDraft,
                              style: TextStyle(fontSize: 12, color: c.textSecondary),
                            ),
                            onChanged: (value) {
                              HapticFeedback.selectionClick();
                              setState(() => _isPublished = value);
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          label: _isPublished ? S.publishAnnouncement : S.saveDraft,
                          icon: _isPublished ? Icons.send_rounded : Icons.save_outlined,
                          isLoading: _isSaving,
                          onPressed: _save,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
