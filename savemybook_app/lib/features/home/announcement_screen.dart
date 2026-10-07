import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/responsive.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/master_detail.dart';
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
    if (!context.isWide) return _buildList(context, widget.padding);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _splitWidth) return _buildList(context, widget.padding);
        return MasterDetail(
          minSplitWidth: _splitWidth,
          placeholderIcon: Icons.campaign_outlined,
          master: Builder(builder: (context) => _buildList(context, EdgeInsets.fromLTRB(16, 16, 16, widget.padding.bottom))),
        );
      },
    );
  }

  static const double _splitWidth = 840;

  Widget _buildList(BuildContext context, EdgeInsets padding) {
    final c = AppColors.of(context);
    final wide = context.isWide;

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
                      padding: _listPadding(constraints, padding),
                      itemCount: _items.length,
                      itemBuilder: (context, i) => RevealOnScroll(
                        index: i,
                        child: wide ? _buildWideItem(context, _items[i], c) : _buildCard(_items[i], c),
                      ),
                    )),
            ),
    );
  }

  EdgeInsets _listPadding(BoxConstraints constraints, EdgeInsets padding) {
    final side = responsiveListPadding(constraints, horizontal: padding.left).left;
    return padding.copyWith(left: side, right: side);
  }

  Widget _buildWideItem(BuildContext context, Announcement a, AppColors c) {
    final selected = MasterDetail.selectedId(context) == a.announcementId;
    final radius = BorderRadius.circular(14);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? c.accent.withValues(alpha: c.isDark ? 0.22 : 0.1) : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? c.accent.withValues(alpha: 0.5) : c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => MasterDetail.open(context, AnnouncementDetailScreen(announcement: a), id: a.announcementId),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            child: _cardContent(a, c),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Announcement a, AppColors c) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AnnouncementDetailScreen(announcement: a)),
      ),
      child: _cardContent(a, c),
    );
  }

  Widget _cardContent(Announcement a, AppColors c) {
    return Row(
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
    final wide = context.isWide;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: a.typeText, icon: announcementIcon(a.type)),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) => ListView(
              padding: responsiveListPadding(constraints, maxWidth: Breakpoints.readingMaxWidth, horizontal: wide ? 24 : 20, top: wide ? 24 : 20, bottom: 40),
              children: [
                Text(
                  a.title,
                  style: TextStyle(fontSize: wide ? 24 : 20, fontWeight: FontWeight.bold, height: 1.4, color: c.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  S.publishedP0(formatDate(a.publishedAt?.toLocal())),
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
