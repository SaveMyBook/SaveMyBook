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
import 'admin_member_detail_screen.dart';
import '../../utils/app_labels.dart';
import '../../i18n/strings.dart';

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
        ? (isBlacklisted ? S.addBlocklist : S.removeFromBlocklist)
        : (isActive == true ? S.reinstateAccount2 : S.suspendAccount2);

    final confirmed = await showConfirmDialog(
      context,
      title: action,
      message: S.runP1P0(member.nickname, action),
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
      showAppSnackBar(context, S.updatedP0SStatus(member.nickname));
      _load();
    } else {
      showAppSnackBar(context, AppLabels.updateFailed, isError: true);
    }
  }

  Future<void> _openDetail(AdminMember member) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminMemberDetailScreen(userId: member.userId)),
    );
    _load();
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
              title: Text(member.isActive ? S.suspendAccount : S.reinstateAccount2, style: TextStyle(color: c.textPrimary)),
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
                member.isBlacklisted ? S.removeFromBlocklist : S.addBlocklist,
                style: TextStyle(color: c.textPrimary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _toggle(member, isBlacklisted: !member.isBlacklisted);
              },
            ),
            ListTile(
              leading: Icon(Icons.manage_accounts_outlined, color: c.accent),
              title: Text(S.fullSettingsTierPermissions, style: TextStyle(color: c.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _openDetail(member);
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
          AppHeader(title: S.members3, icon: Icons.people_alt_outlined),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    controller: _searchController,
                    hint: S.searchDisplayNameEmail,
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
                    PopupMenuItem(value: null, child: Text(S.actionAll)),
                    PopupMenuItem(value: 'active', child: Text(S.memberNormal)),
                    PopupMenuItem(value: 'inactive', child: Text(S.memberInactive)),
                    PopupMenuItem(value: 'blacklisted', child: Text(S.memberBlacklisted)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView.list()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: SwitchIn(child: _members.isEmpty
                        ? ListView(key: const ValueKey('empty'), 
                            children: [
                              SizedBox(height: 80),
                              EmptyView(icon: Icons.person_off_outlined, message: S.noMembersMatch),
                            ],
                          )
                        : ListView.builder(key: const ValueKey('items'), 
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _members.length,
                            itemBuilder: (_, i) => RevealOnScroll(index: i, child: _buildMemberCard(_members[i], c)),
                          )),
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
      onTap: () => _openDetail(member),
      onLongPress: () => _showActions(member),
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
                            member.role == 'admin' ? S.roleAdmin : S.roleBuyerSeller,
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
              _info(S.phone, member.phone.isEmpty ? '—' : member.phone, c),
              _info(S.listings2, '${member.bookCount}', c),
              _info(S.purchase, '${member.buyOrderCount}', c),
              _info(S.sales2, '${member.sellOrderCount}', c),
              _info(S.created, formatDate(member.createdAt), c),
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
