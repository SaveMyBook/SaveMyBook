import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';

class AdminMemberDetailScreen extends StatefulWidget {
  final int userId;

  const AdminMemberDetailScreen({super.key, required this.userId});

  @override
  State<AdminMemberDetailScreen> createState() => _AdminMemberDetailScreenState();
}

class _AdminMemberDetailScreenState extends State<AdminMemberDetailScreen> {
  final ApiService _api = ApiService();
  AdminMemberDetail? _detail;
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final detail = await _api.fetchAdminMemberDetail(widget.userId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _isLoading = false;
    });
  }

  bool get _isSelf => ApiService.currentUser?.userId == widget.userId;

  Future<void> _run(Future<String?> Function() task, String successMessage) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    final error = await task();
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, successMessage);
      _load();
    }
  }

  Future<void> _toggleStatus({required bool active}) async {
    final detail = _detail!;
    final turningOff = active ? detail.isActive : !detail.isBlacklisted;

    final ok = await showConfirmDialog(
      context,
      title: active ? (turningOff ? '停權此帳號' : '恢復此帳號') : (turningOff ? '加入黑名單' : '移出黑名單'),
      message: turningOff
          ? '${detail.nickname} 會立刻被登出，且無法再使用 App 的任何功能。'
          : '${detail.nickname} 將可以重新登入使用。',
      confirmLabel: '確認',
      isDestructive: turningOff,
    );
    if (!ok || !mounted) return;

    await _run(
      () async {
        final done = await _api.updateMemberStatus(
          detail.userId,
          isActive: active ? !detail.isActive : null,
          isBlacklisted: active ? null : !detail.isBlacklisted,
        );
        return done ? null : '更新失敗，請稍後再試';
      },
      '已更新帳號狀態',
    );
  }

  Future<void> _changeRole() async {
    final detail = _detail!;
    final next = detail.isAdmin ? 'buyer_seller' : 'admin';

    final ok = await showConfirmDialog(
      context,
      title: detail.isAdmin ? '取消管理員' : '設為管理員',
      message: detail.isAdmin
          ? '${detail.nickname} 將立刻失去所有後台權限。'
          : '${detail.nickname} 將可以進入管理後台，預設擁有全部權限，可再逐項調整。',
      confirmLabel: '確認',
      isDestructive: detail.isAdmin,
    );
    if (!ok || !mounted) return;

    await _run(() => _api.updateMemberRole(detail.userId, next), '已更新身分');
  }

  Future<void> _changeLevel() async {
    final detail = _detail!;
    final c = AppColors.of(context);

    final choice = await showOptionSheet<String>(
      context,
      title: '調整會員等級',
      subtitle: '目前 ${detail.points} 點（自動 ${detail.basePoints}'
          '${detail.bonusPoints == 0 ? '' : '、手動 ${detail.bonusPoints > 0 ? '+' : ''}${detail.bonusPoints}'}）',
      options: [
        ...detail.levels.map(
          (l) => SheetOption(
            value: 'level:${l.levelId}',
            label: '${l.name}（${l.minPoints} 點）',
            icon: Icons.workspace_premium_outlined,
            selected: detail.currentLevel?.levelId == l.levelId,
          ),
        ),
        const SheetOption(
          value: 'delta',
          label: '手動加減點數',
          icon: Icons.exposure_rounded,
        ),
        SheetOption(
          value: 'reset',
          label: '恢復自動計算',
          icon: Icons.restart_alt_rounded,
          color: c.danger,
        ),
      ],
    );
    if (choice == null || !mounted) return;

    if (choice == 'reset') {
      await _run(() => _api.adjustMemberLevel(detail.userId, reset: true), '已恢復自動計算');
      return;
    }

    if (choice == 'delta') {
      final input = await showTextInputDialog(
        context,
        title: '加減點數',
        hint: '正數增加、負數扣除，例如 -50',
        confirmLabel: '套用',
      );
      if (input == null || !mounted) return;

      final delta = int.tryParse(input.trim());
      if (delta == null || delta == 0) {
        showAppSnackBar(context, '請輸入非零的整數', isError: true);
        return;
      }
      await _run(() => _api.adjustMemberLevel(detail.userId, delta: delta), '已調整點數');
      return;
    }

    final levelId = int.tryParse(choice.split(':').last);
    if (levelId == null) return;
    await _run(() => _api.adjustMemberLevel(detail.userId, levelId: levelId), '已調整等級');
  }

  Future<void> _togglePermission(String key, bool value) async {
    final detail = _detail!;
    await _run(
      () => _api.updateAdminPermissions(detail.userId, {key: value}),
      value ? '已開放權限' : '已收回權限',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final detail = _detail;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          const AppHeader(title: '會員設定', icon: Icons.manage_accounts_outlined),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : detail == null
                      ? const EmptyView(
                          icon: Icons.person_off_outlined,
                          message: '找不到這位會員的資料',
                        )
                      : RefreshIndicator(
                          color: c.accent,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                            children: [
                              FadeSlideIn(child: _buildProfile(detail, c)),
                              const SizedBox(height: 16),
                              FadeSlideIn(index: 1, child: _buildStatusCard(detail, c)),
                              const SizedBox(height: 16),
                              FadeSlideIn(index: 2, child: _buildLevelCard(detail, c)),
                              if (detail.isAdmin) ...[
                                const SizedBox(height: 16),
                                FadeSlideIn(index: 3, child: _buildPermissionCard(detail, c)),
                              ],
                            ],
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(AdminMemberDetail detail, AppColors c) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(imageUrl: detail.avatarUrl, radius: 28, enablePreview: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            detail.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (detail.isAdmin)
                          StatusBadge(label: '管理員', color: c.accent),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatTile(
                label: '上架書籍',
                value: Text(
                  '${detail.bookCount}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.accent),
                ),
              ),
              const VerticalDivider1(),
              StatTile(
                label: '完成交易',
                value: Text(
                  '${detail.completedOrders}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.accent),
                ),
              ),
              const VerticalDivider1(),
              StatTile(
                label: '加入日期',
                value: Text(
                  formatDate(detail.createdAt),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(AdminMemberDetail detail, AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: '帳號狀態'),
          if (_isSelf)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '這是你自己的帳號，無法在這裡調整狀態與權限。',
                style: TextStyle(fontSize: 12, color: c.textHint),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('啟用帳號', style: TextStyle(fontSize: 14, color: c.textPrimary)),
            subtitle: Text(
              detail.isActive ? '可以正常登入使用' : '已停權，登入後會被立刻登出',
              style: TextStyle(fontSize: 11, color: c.textSecondary),
            ),
            value: detail.isActive,
            activeThumbColor: c.accent,
            onChanged: _isSelf || _isBusy ? null : (_) => _toggleStatus(active: true),
          ),
          Divider(color: c.divider, height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('列入黑名單', style: TextStyle(fontSize: 14, color: c.textPrimary)),
            subtitle: Text(
              detail.isBlacklisted ? '已封鎖，無法使用任何功能' : '未封鎖',
              style: TextStyle(fontSize: 11, color: c.textSecondary),
            ),
            value: detail.isBlacklisted,
            activeThumbColor: c.danger,
            onChanged: _isSelf || _isBusy ? null : (_) => _toggleStatus(active: false),
          ),
          Divider(color: c.divider, height: 1),
          AppMenuItem(
            icon: Icons.admin_panel_settings_outlined,
            title: '身分',
            subtitle: detail.isAdmin ? '管理員' : '一般會員',
            isLast: true,
            onTap: _isSelf || _isBusy ? null : _changeRole,
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(AdminMemberDetail detail, AppColors c) {
    final manual = detail.bonusPoints != 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: '會員等級'),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.workspace_premium_rounded, color: c.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      detail.currentLevel?.name ?? '尚未評級',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${detail.points} 點（自動 ${detail.basePoints}'
                      '${manual ? '、手動 ${detail.bonusPoints > 0 ? '+' : ''}${detail.bonusPoints}' : ''}）',
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (manual) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: c.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '這位會員的等級目前有人工調整，不完全依交易自動計算。',
                      style: TextStyle(fontSize: 11, color: c.warning, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isBusy ? null : _changeLevel,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('調整等級'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(AdminMemberDetail detail, AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: '後台權限'),
          const SizedBox(height: 4),
          Text(
            '關閉之後，這位管理員打對應的 API 會直接被擋下。',
            style: TextStyle(fontSize: 11, color: c.textHint),
          ),
          for (final entry in AdminMemberDetail.permissionLabels.entries)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value.$1, style: TextStyle(fontSize: 14, color: c.textPrimary)),
              subtitle: Text(
                entry.value.$2,
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
              value: detail.permissions[entry.key] ?? true,
              activeThumbColor: c.accent,
              onChanged: _isSelf || _isBusy
                  ? null
                  : (value) => _togglePermission(entry.key, value),
            ),
        ],
      ),
    );
  }
}
