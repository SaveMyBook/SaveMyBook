import 'package:flutter/material.dart';

import '../../i18n/strings.dart';
import '../../models/admin_models.dart';
import '../../models/chat.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/app_tiles.dart';
import 'admin_image_strip.dart';

class ReportedMessagePanel extends StatefulWidget {
  final int reportId;
  final ReportedMessage message;

  const ReportedMessagePanel({super.key, required this.reportId, required this.message});

  @override
  State<ReportedMessagePanel> createState() => _ReportedMessagePanelState();
}

class _ReportedMessagePanelState extends State<ReportedMessagePanel> {
  final ApiService _api = ApiService();
  List<ReportedMessage> _before = const [];
  List<ReportedMessage> _after = const [];

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    final result = await _api.fetchReportMessageContext(widget.reportId);
    if (!mounted || result == null) return;
    setState(() {
      _before = result.before;
      _after = result.after;
    });
  }

  String _header(ReportedMessage item, {bool withNo = false}) {
    final m = item.message;
    return [
      if (m.senderName.isNotEmpty) m.senderName,
      if (withNo && item.senderNo.isNotEmpty) item.senderNo,
      if (m.createdAt != null) formatDateTime(m.createdAt),
      if (m.isEdited) S.edited,
    ].join('・');
  }

  Widget _body(AppColors c, ChatMessage m, {required bool reported}) {
    if (m.isRecalled) {
      return Text(S.messageUnsent, style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: c.textHint));
    }
    final images = m.imageUrls;
    if (images.isNotEmpty) return AdminImageStrip(urls: images, size: reported ? 96 : 56);
    final style = TextStyle(fontSize: reported ? 14 : 13, height: 1.45, color: reported ? c.textPrimary : c.textSecondary);
    return reported
        ? SelectableText(m.preview, style: style)
        : Text(m.preview, maxLines: 3, overflow: TextOverflow.ellipsis, style: style);
  }

  Widget _context(AppColors c, ReportedMessage item) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_header(item), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.textHint)),
            const SizedBox(height: 3),
            _body(c, item.message, reported: false),
          ],
        ),
      );

  Widget _reported(AppColors c, ReportedMessage item) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.danger.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_header(item, withNo: true),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
                ),
                const SizedBox(width: 6),
                StatusBadge(label: S.reportedMessage, color: c.danger, fontSize: 10),
              ],
            ),
            const SizedBox(height: 6),
            _body(c, item.message, reported: true),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: c.inputFill, borderRadius: BorderRadius.circular(12)),
      child: AnimatedSize(
        duration: Motion.base,
        curve: Motion.standard,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in _before) _context(c, item),
            _reported(c, widget.message),
            for (final item in _after) _context(c, item),
          ],
        ),
      ),
    );
  }
}
