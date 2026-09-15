import 'package:flutter/material.dart';
import '../../models/support.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../account/support_ticket_screen.dart';
import '../../i18n/strings.dart';
import 'admin_layout.dart';

class AdminTicketScreen extends StatefulWidget {
  const AdminTicketScreen({super.key});

  @override
  State<AdminTicketScreen> createState() => _AdminTicketScreenState();
}

class _AdminTicketScreenState extends State<AdminTicketScreen>
    with SingleTickerProviderStateMixin {
  List<({String key, String label})> get _tabs => [
    (key: 'open', label: S.ticketOpen),
    (key: 'pending', label: S.replied),
    (key: 'resolved', label: S.ticketResolved),
    (key: 'all', label: S.actionAll),
  ];

  final ApiService _api = ApiService();
  late final TabController _tabController = TabController(length: _tabs.length, vsync: this);
  final TextEditingController _searchController = TextEditingController();

  List<SupportTicket> _tickets = [];
  bool _isLoading = true;
  bool _navigating = false;
  int _loadSeq = 0;
  int _loadedTab = -1;

  @override
  void initState() {
    super.initState();
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index != _loadedTab) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    final seq = ++_loadSeq;
    final tab = _tabController.index;
    if (showLoading) setState(() => _isLoading = true);
    final tickets = await _api.fetchAdminTickets(status: _tabs[tab].key);
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _tickets = tickets;
      _loadedTab = tab;
      _isLoading = false;
    });
  }

  List<SupportTicket> get _visible {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return _tickets;
    return _tickets
        .where((t) =>
            t.subject.toLowerCase().contains(keyword) ||
            t.userName.toLowerCase().contains(keyword) ||
            (t.lastMessage ?? '').toLowerCase().contains(keyword))
        .toList();
  }

  Future<void> _open(SupportTicket ticket) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TicketDetailScreen(ticketId: ticket.ticketId, asAdmin: true),
        ),
      );
    } finally {
      _navigating = false;
    }
    if (mounted) _load(showLoading: false);
  }

  static String _when(DateTime? dt) {
    if (dt == null) return '';
    final relative = formatRelative(dt);
    final exact = formatDateTime(dt);
    return exact.startsWith(relative) ? exact : '$relative・$exact';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final visible = _visible;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: AdminLayout(
        builder: (context, frame) => Column(
          children: [
            AppHeader(
              title: S.supportEnquiries,
              icon: Icons.support_agent_rounded,
              bottom: AppTabBar(
                controller: _tabController,
                tabs: _tabs.map((t) => t.label).toList(),
              ),
            ),
            Padding(
              padding: frame.inset(const EdgeInsets.fromLTRB(16, 12, 16, 0)),
              child: AppSearchField(
                controller: _searchController,
                hint: S.searchSubjectMemberMessage,
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: SwipeTabs(
                controller: _tabController,
                child: SwitchIn(
                  child: _isLoading
                      ? const LoadingView.list()
                      : RefreshIndicator(
                          color: c.accent,
                          onRefresh: () => _load(showLoading: false),
                          child: SwitchIn(
                            child: visible.isEmpty
                                ? ListView(
                                    key: const ValueKey('empty'),
                                    children: [
                                      const SizedBox(height: 60),
                                      EmptyView(
                                        icon: Icons.inbox_outlined,
                                        message: S.noEnquiriesCategory,
                                        actionLabel: _searchController.text.trim().isEmpty ? S.refresh : S.clearSearch,
                                        onAction: () {
                                          if (_searchController.text.trim().isEmpty) {
                                            _load();
                                          } else {
                                            _searchController.clear();
                                            setState(() {});
                                          }
                                        },
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    key: ValueKey('items_$_loadedTab'),
                                    padding: frame.inset(const EdgeInsets.fromLTRB(16, 16, 16, 24)),
                                    itemCount: visible.length,
                                    itemBuilder: (_, i) => RevealOnScroll(
                                      index: i,
                                      child: _buildCard(visible[i], c, wide: frame.isWide),
                                    ),
                                  ),
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

  Widget _buildCard(SupportTicket ticket, AppColors c, {bool wide = false}) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _open(ticket),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(imageUrl: ticket.userAvatar, radius: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ticket.userName.isEmpty ? S.user : ticket.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
              ),
              StatusBadge(label: ticket.statusText, color: c.ticketStatusColor(ticket.status)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ticket.subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            ticket.lastMessage ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: Text(
                  ticket.categoryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.textHint),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.forum_outlined, size: 12, color: c.textHint),
              const SizedBox(width: 3),
              Text('${ticket.messageCount}', style: TextStyle(fontSize: 11, color: c.textHint)),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Text(
                  _when(ticket.updatedAt),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.textHint),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
