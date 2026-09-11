import 'package:flutter/material.dart';
import '../../models/support.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../support_ticket_screen.dart';

class AdminTicketScreen extends StatefulWidget {
  const AdminTicketScreen({super.key});

  @override
  State<AdminTicketScreen> createState() => _AdminTicketScreenState();
}

class _AdminTicketScreenState extends State<AdminTicketScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    (key: 'open', label: '待處理'),
    (key: 'pending', label: '已回覆'),
    (key: 'resolved', label: '已解決'),
    (key: 'all', label: '全部'),
  ];

  final ApiService _api = ApiService();
  late final TabController _tabController = TabController(length: _tabs.length, vsync: this);

  List<SupportTicket> _tickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final tickets = await _api.fetchAdminTickets(status: _tabs[_tabController.index].key);
    if (!mounted) return;
    setState(() {
      _tickets = tickets;
      _isLoading = false;
    });
  }

  Future<void> _open(SupportTicket ticket) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailScreen(ticketId: ticket.ticketId, asAdmin: true),
      ),
    );
    _load();
  }


  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: '客服工單',
            icon: Icons.support_agent_rounded,
            bottom: AppTabBar(
              controller: _tabController,
              tabs: _tabs.map((t) => t.label).toList(),
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
                        onRefresh: _load,
                        child: SwitchIn(child: _tickets.isEmpty
                            ? ListView(key: const ValueKey('empty'), 
                                children: const [
                                  SizedBox(height: 60),
                                  EmptyView(
                                    icon: Icons.inbox_outlined,
                                    message: '此分類目前沒有工單',
                                  ),
                                ],
                              )
                            : ListView.builder(key: const ValueKey('items'), 
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                itemCount: _tickets.length,
                                itemBuilder: (_, i) => RevealOnScroll(
                                  index: i,
                                  child: _buildCard(_tickets[i], c),
                                ),
                              )),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(SupportTicket ticket, AppColors c) {
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
                  ticket.userName.isEmpty ? '使用者' : ticket.userName,
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
              Text(ticket.categoryText, style: TextStyle(fontSize: 11, color: c.textHint)),
              const SizedBox(width: 10),
              Icon(Icons.forum_outlined, size: 12, color: c.textHint),
              const SizedBox(width: 3),
              Text('${ticket.messageCount}', style: TextStyle(fontSize: 11, color: c.textHint)),
              const Spacer(),
              Text(formatRelative(ticket.updatedAt), style: TextStyle(fontSize: 11, color: c.textHint)),
            ],
          ),
        ],
      ),
    );
  }
}
