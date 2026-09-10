import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';

/// 系統公告－新增／編輯推播
class AdminAnnouncementEditScreen extends StatefulWidget {
  final Announcement? announcement;
  const AdminAnnouncementEditScreen({super.key, this.announcement});

  @override
  State<AdminAnnouncementEditScreen> createState() => _AdminAnnouncementEditScreenState();
}

class _AdminAnnouncementEditScreenState extends State<AdminAnnouncementEditScreen> {
  static const _types = [
    (value: 'general', label: '一般公告'),
    (value: 'maintenance', label: '系統維護'),
    (value: 'promotion', label: '活動優惠'),
    (value: 'policy', label: '政策更新'),
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
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      showAppSnackBar(context, '請填寫標題與內容', isError: true);
      return;
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text('標題',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _titleController,
                            style: TextStyle(color: c.textPrimary, fontSize: 14),
                            decoration: _decoration(c),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text('類型',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                        ),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _type,
                              isExpanded: true,
                              dropdownColor: c.card,
                              style: TextStyle(color: c.textPrimary, fontSize: 14),
                              items: _types
                                  .map((t) => DropdownMenuItem(value: t.value, child: Text(t.label)))
                                  .toList(),
                              onChanged: (value) => setState(() => _type = value ?? _type),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 60,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text('內容',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _contentController,
                            maxLines: 6,
                            style: TextStyle(color: c.textPrimary, fontSize: 14),
                            decoration: _decoration(c, hint: '輸入推播內容'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isPublished,
                      activeColor: AppColors.primary,
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
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
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

  InputDecoration _decoration(AppColors c, {String? hint}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(color: c.textHint, fontSize: 13),
      filled: true,
      fillColor: c.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }
}
