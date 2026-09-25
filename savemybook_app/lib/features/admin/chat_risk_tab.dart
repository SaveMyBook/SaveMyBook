import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/admin_models.dart';
import '../../models/chat.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import 'admin_layout.dart';
import 'admin_member_detail_screen.dart';
import '../../i18n/strings.dart';

String chatRiskCategoryLabel(ChatRiskCategory category) => switch (category) {
  ChatRiskCategory.contact => S.contactDetails,
  ChatRiskCategory.payment => S.paymentDetails,
  ChatRiskCategory.offsite => S.offPlatformDeal,
  ChatRiskCategory.link => S.suspiciousLink,
  ChatRiskCategory.credential => S.asksVerificationDetails,
  ChatRiskCategory.scam => S.scamWording,
};

class ChatRiskTab extends StatefulWidget {
  final ValueChanged<int>? onCountChanged;

  const ChatRiskTab({super.key, this.onCountChanged});

  @override
  State<ChatRiskTab> createState() => _ChatRiskTabState();
}

class _ChatRiskTabState extends State<ChatRiskTab> with AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();
  List<ChatRiskAlert> _items = [];
  final Set<int> _busy = {};
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _api.fetchChatRiskAlerts();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = items;
    });
    widget.onCountChanged?.call(items.length);
  }

  Future<void> _handle(ChatRiskAlert alert, {required bool dismiss}) async {
    if (_busy.contains(alert.alertId)) return;
    setState(() => _busy.add(alert.alertId));
    final error = await _api.handleChatRiskAlert(alert.alertId, dismiss: dismiss);
    if (!mounted) return;
    setState(() => _busy.remove(alert.alertId));
    if (error != null) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, error, isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    showAppSnackBar(context, dismiss ? S.markedAsFalseAlarm : S.markedAsHandled);
    setState(() => _items.removeWhere((a) => a.alertId == alert.alertId));
    widget.onCountChanged?.call(_items.length);
  }

  Future<void> _openMember(ChatRiskAlert alert) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminMemberDetailScreen(userId: alert.userId)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);

    return SwitchIn(
      child: _loading
          ? const LoadingView.list(key: ValueKey('loading'))
          : _items.isEmpty
              ? RefreshableCenter(
                  key: const ValueKey('empty'),
                  onRefresh: _load,
                  child: EmptyView(icon: Icons.verified_user_outlined, message: S.noOpenScamAlerts),
                )
              : RefreshIndicator(
                  key: const ValueKey('list'),
                  color: c.accent,
                  onRefresh: _load,
                  child: AdminLayout(
                    builder: (context, frame) => ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: frame.inset(const EdgeInsets.fromLTRB(16, 16, 16, 40)),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => RevealOnScroll(
                        index: i,
                        child: Padding(padding: const EdgeInsets.only(bottom: 14), child: _card(c, _items[i])),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _card(AppColors c, ChatRiskAlert alert) {
    final busy = _busy.contains(alert.alertId);
    final categories = <ChatRiskCategory>{for (final s in alert.samples) ...s.categories};
    final count = alert.hitCount;
    final restricted = !alert.isActive || alert.isBlacklisted;
    final first = alert.firstAt == null ? null : formatRelative(alert.firstAt!);
    final last = alert.lastAt == null ? null : formatRelative(alert.lastAt!);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openMember(alert),
            child: Row(
              children: [
                UserAvatar(imageUrl: alert.avatarUrl, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.nickname, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                      const SizedBox(height: 2),
                      Text(alert.userNo, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ],
                  ),
                ),
                if (restricted)
                  StatusBadge(label: alert.isBlacklisted ? S.memberBlacklisted : S.disabled, color: c.neutral, fontSize: 10)
                else
                  StatusBadge(label: S.p0HighRisk(count), color: c.danger, fontSize: 10),
                Icon(Icons.chevron_right_rounded, color: c.textHint),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            [if (first != null) S.firstP0(first), if (last != null) S.latestP0(last)].join('・'),
            style: TextStyle(fontSize: 12, color: c.textSecondary),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final category in ChatRiskCategory.values)
                  if (categories.contains(category))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: c.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(chatRiskCategoryLabel(category),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.danger)),
                    ),
              ],
            ),
          ],
          if (alert.samples.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: c.inputFill, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, sample) in alert.samples.indexed) ...[
                    if (i > 0) Divider(height: 16, color: c.divider),
                    Text(sample.content, maxLines: 4, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, height: 1.45, color: c.textPrimary)),
                    if (sample.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(formatDateTime(sample.createdAt!), style: TextStyle(fontSize: 11, color: c.textHint)),
                    ],
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          AnimatedOpacity(
            duration: Motion.micro,
            opacity: busy ? 0.5 : 1,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _handle(alert, dismiss: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.textSecondary,
                      side: BorderSide(color: c.divider),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(S.falseAlarm, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy ? null : () => _handle(alert, dismiss: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(S.reportResolved, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
