import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/responsive.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

IconData announcementIcon(String type) => switch (type) {
      'maintenance' => Icons.build_circle_outlined,
      'promotion' => Icons.local_offer_outlined,
      'policy' => Icons.gavel_rounded,
      _ => Icons.campaign_outlined,
    };

class AnnouncementList extends StatefulWidget {
  final EdgeInsets padding;

  const AnnouncementList({super.key, this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24)});

  @override
  State<AnnouncementList> createState() => _AnnouncementListState();
}

class _AnnouncementListState extends State<AnnouncementList> {
  final ApiService _api = ApiService();
  List<Announcement> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _api.fetchAnnouncements();
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return SwitchIn(
      child: _isLoading
          ? const LoadingView.list()
          : RefreshIndicator(
              color: c.accent,
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      key: const ValueKey('empty'),
                      children: [
                        const SizedBox(height: 80),
                        EmptyView(icon: Icons.campaign_outlined, message: S.noAnnouncements),
                      ],
                    )
                  : LayoutBuilder(builder: (context, constraints) => ListView.builder(
                      key: const ValueKey('items'),
                      padding: _listPadding(constraints),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => RevealOnScroll(index: i, child: _buildCard(_items[i], c)),
                    )),
            ),
    );
  }

  EdgeInsets _listPadding(BoxConstraints constraints) {
    final side = responsiveListPadding(constraints, horizontal: widget.padding.left).left;
    return widget.padding.copyWith(left: side, right: side);
  }

  Widget _buildCard(Announcement a, AppColors c) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AnnouncementDetailScreen(announcement: a)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(announcementIcon(a.type), size: 20, color: c.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(label: a.typeText, color: c.accent),
                    Text(formatDate(a.publishedAt?.toLocal()), style: TextStyle(fontSize: 11, color: c.textHint)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  a.title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  a.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AnnouncementDetailScreen extends StatelessWidget {
  final Announcement announcement;

  const AnnouncementDetailScreen({super.key, required this.announcement});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = announcement;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: a.typeText, icon: announcementIcon(a.type)),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) => ListView(
              padding: responsiveListPadding(constraints, maxWidth: Breakpoints.readingMaxWidth, horizontal: 20, top: 20, bottom: 40),
              children: [
                Text(
                  a.title,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.4, color: c.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  S.lastUpdated(formatDate(a.publishedAt?.toLocal())),
                  style: TextStyle(fontSize: 12, color: c.textHint),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: SelectableText(
                    a.content,
                    style: TextStyle(fontSize: 15, height: 1.8, color: c.textPrimary),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}
