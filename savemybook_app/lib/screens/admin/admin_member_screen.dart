import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';

class AdminMemberScreen extends StatefulWidget {
  const AdminMemberScreen({super.key});

  @override
  State<AdminMemberScreen> createState() => _AdminMemberScreenState();
}

class _AdminMemberScreenState extends State<AdminMemberScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<AdminMember> _members = [];
  bool _isLoading = true;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final members = await _api.fetchAdminMembers(
      keyword: _searchController.text.trim(),
      status: _statusFilter,
    );
    if (!mounted) return;
    setState(() {
      _members = members;
      _isLoading = false;
    });
  }

  Future<void> _toggle(AdminMember member, {bool? isActive, bool? isBlacklisted}) async {
    final action = isBlacklisted != null
        ? (isBlacklisted ? '加入黑名單' : '移出黑名單')
        : (isActive == true ? '恢復帳號' : '停權帳號');

    final confirmed = await showConfirmDialog(
      context,
      title: action,
      message: '確定要對「${member.nickname}」執行「$action」嗎？',
      confirmLabel: action,
      isDestructive: isBlacklisted == true || isActive == false,
    );
    if (!confirmed || !mounted) return;

    final ok = await runBusy(
      context,
      () => _api.updateMemberStatus(
        member.userId,
        isActive: isActive,
        isBlacklisted: isBlacklisted,
      ),
    );
    if (!mounted) return;

    if (ok == true) {
      showAppSnackBar(context, '已更新 ${member.nickname} 的狀態');
      _load();
    } else {
      showAppSnackBar(context, '更新失敗，請稍後再試', isError: true);
    }
  }

  void _showActions(AdminMember member) {
    final c = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              member.nickname,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            Text(member.email, style: TextStyle(fontSize: 12, color: c.textSecondary)),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                member.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                color: member.isActive ? c.danger : c.success,
              ),
              title: Text(member.isActive ? '停權此帳號' : '恢復帳號', style: TextStyle(color: c.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _toggle(member, isActive: !member.isActive);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.gpp_bad_outlined,
                color: member.isBlacklisted ? c.success : c.danger,
              ),
              title: Text(
                member.isBlacklisted ? '移出黑名單' : '加入黑名單',
                style: TextStyle(color: c.textPrimary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _toggle(member, isBlacklisted: !member.isBlacklisted);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          const AppHeader(title: '會員列表', icon: Icons.people_alt_outlined),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    controller: _searchController,
                    hint: '搜尋暱稱或 Email',
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String?>(
                  color: c.card,
                  icon: Icon(Icons.filter_list_rounded, color: c.textPrimary),
                  onSelected: (value) {
                    setState(() => _statusFilter = value);
                    _load();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: null, child: Text('全部')),
                    const PopupMenuItem(value: 'active', child: Text('正常')),
                    const PopupMenuItem(value: 'inactive', child: Text('已停權')),
                    const PopupMenuItem(value: 'blacklisted', child: Text('黑名單')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: _members.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyView(icon: Icons.person_off_outlined, message: '找不到符合條件的會員'),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _members.length,
                            itemBuilder: (_, i) => FadeSlideIn(index: i, child: _buildMemberCard(_members[i], c)),
                          ),
                  )),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(AdminMember member, AppColors c) {
    final statusColor = member.isBlacklisted
        ? c.danger
        : (!member.isActive ? c.warning : c.success);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _showActions(member),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(imageUrl: member.avatarUrl, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          member.nickname,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            member.role == 'admin' ? '管理員' : '一般會員',
                            style: const TextStyle(fontSize: 10, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(member.email, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  member.statusText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: c.divider),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _info('電話', member.phone.isEmpty ? '—' : member.phone, c),
              _info('上架書籍', '${member.bookCount}', c),
              _info('購買', '${member.buyOrderCount}', c),
              _info('銷售', '${member.sellOrderCount}', c),
              _info('創建日期', formatDate(member.createdAt), c),
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value, AppColors c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label：', style: TextStyle(fontSize: 11, color: c.textHint)),
        Text(value, style: TextStyle(fontSize: 11, color: c.textSecondary)),
      ],
    );
  }
}
