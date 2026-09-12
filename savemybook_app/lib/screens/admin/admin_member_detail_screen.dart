import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/guards.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../../utils/app_labels.dart';
import '../../i18n/strings.dart';

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
      title: active ? (turningOff ? S.suspendAccount : S.reinstateAccount) : (turningOff ? S.addBlocklist : S.removeFromBlocklist),
      message: turningOff
          ? S.p0SignedOutImmediatelyCanNo(detail.nickname)
          : S.p0AbleSignAgain(detail.nickname),
      confirmLabel: S.confirm,
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
        return done ? null : AppLabels.updateFailed;
      },
      S.accountStatusUpdated,
    );
  }

  /// 臨時密碼由伺服器產生，而且只回傳這一次。畫面必須當場把它交出去，
  /// 關掉之後誰都拿不回來，只能再重設一次。
  Future<void> _resetPassword(AdminMemberDetail detail) async {
    final ok = await showConfirmDialog(
      context,
      title: S.resetPassword,
      message: S.p0SCurrentPasswordStopsWorking(detail.nickname),
      confirmLabel: S.generateTemporaryPassword,
      isDestructive: true,
      icon: Icons.lock_reset_rounded,
    );
    if (!ok || !mounted) return;

    final (password, error) = await runBusy(
          context,
          () => _api.resetMemberPassword(detail.userId),
        ) ??
        (null, null);
    if (!mounted) return;

    if (password == null) {
      showAppSnackBar(context, error ?? AppLabels.updateFailed, isError: true);
      return;
    }

    await _showTempPassword(detail.nickname, password);
  }

  Future<void> _showTempPassword(String nickname, String password) async {
    final c = AppColors.of(context);

    await showDialog<void>(
      context: context,
      // 點旁邊就關掉的話，密碼會在還沒抄下來前消失。
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
        title: Row(
          children: [
            Icon(Icons.key_rounded, color: c.accent, size: 20),
            const SizedBox(width: 8),
            Text(S.temporaryPassword, style: TextStyle(fontSize: 17, color: c.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.p0SPasswordBeenResetPassword(nickname),
              style: TextStyle(fontSize: 13, height: 1.6, color: c.textSecondary),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: c.inputFill,
                borderRadius: BorderRadius.circular(AppRadius.field),
              ),
              child: SelectableText(
                password,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: c.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              S.remindThemChangeSettingsChangePassword,
              style: TextStyle(fontSize: 11, height: 1.5, color: c.textHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: password));
              showAppSnackBar(context, S.temporaryPasswordCopied);
            },
            child: Text(S.copy, style: TextStyle(color: c.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.actionClose, style: TextStyle(color: c.textSecondary)),
          ),
        ],
      ),
    );
  }

  Future<void> _changeRole() async {
    final detail = _detail!;
    final next = detail.isAdmin ? 'buyer_seller' : 'admin';

    final ok = await showConfirmDialog(
      context,
      title: detail.isAdmin ? S.removeAdmin : S.makeAdmin,
      message: detail.isAdmin
          ? S.p0LosesEveryAdminPermissionImmediately(detail.nickname)
          : S.p0GainsAccessAdminAreaWith(detail.nickname),
      confirmLabel: S.confirm,
      isDestructive: detail.isAdmin,
    );
    if (!ok || !mounted) return;

    await _run(() => _api.updateMemberRole(detail.userId, next), S.roleUpdated);
  }

  /// 手動加減的點數。正數要自己補上 +，負數的減號由 toString 帶出來。
  String _manualPoints(int bonus) {
    final sign = bonus > 0 ? '+' : '';
    return S.manualP0P1(sign, bonus);
  }

  Future<void> _changeLevel() async {
    final detail = _detail!;
    final c = AppColors.of(context);

    final manualPart = detail.bonusPoints == 0 ? '' : _manualPoints(detail.bonusPoints);

    final choice = await showOptionSheet<String>(
      context,
      title: S.adjustMembershipTier,
      subtitle: S.currentlyP0PointsAutomaticP1P2(detail.points, detail.basePoints, manualPart),
      options: [
        ...detail.levels.map(
          (l) => SheetOption(
            value: 'level:${l.levelId}',
            label: S.p0P1Points2(l.name, l.minPoints),
            icon: Icons.workspace_premium_outlined,
            selected: detail.currentLevel?.levelId == l.levelId,
          ),
        ),
        SheetOption(
          value: 'delta',
          label: S.adjustPointsManually,
          icon: Icons.exposure_rounded,
        ),
        SheetOption(
          value: 'reset',
          label: S.backAutomatic,
          icon: Icons.restart_alt_rounded,
          color: c.danger,
        ),
      ],
    );
    if (choice == null || !mounted) return;

    if (choice == 'reset') {
      await _run(() => _api.adjustMemberLevel(detail.userId, reset: true), S.backAutomatic2);
      return;
    }

    if (choice == 'delta') {
      final input = await showTextInputDialog(
        context,
        title: S.pointAdjustment,
        hint: S.positiveAddsNegativeDeductsEG,
        confirmLabel: S.apply,
      );
      if (input == null || !mounted) return;

      final delta = int.tryParse(input.trim());
      if (delta == null || delta == 0) {
        showAppSnackBar(context, S.enterNonZeroWholeNumber, isError: true);
        return;
      }
      await _run(() => _api.adjustMemberLevel(detail.userId, delta: delta), S.pointsAdjusted);
      return;
    }

    final levelId = int.tryParse(choice.split(':').last);
    if (levelId == null) return;
    await _run(() => _api.adjustMemberLevel(detail.userId, levelId: levelId), S.tierAdjusted);
  }

  Future<void> _togglePermission(String key, bool value) async {
    final detail = _detail!;
    await _run(
      () => _api.updateAdminPermissions(detail.userId, {key: value}),
      value ? S.permissionGranted : S.permissionRevoked,
    );
  }

  Future<void> _setAllPermissions(bool value) async {
    final detail = _detail!;
    final ok = await showConfirmDialog(
      context,
      title: value ? S.grantAllPermissions : S.revokeAllPermissions,
      message: value
          ? S.p0AbleUseEveryAdminFeature(detail.nickname)
          : S.p0ReachAdminAreaButUnable(detail.nickname),
      confirmLabel: S.confirm,
      isDestructive: !value,
    );
    if (!ok || !mounted) return;

    await _run(
      () => _api.updateAdminPermissions(
        detail.userId,
        {for (final key in AppLabels.permission.keys) key: value},
      ),
      value ? S.allPermissionsGranted : S.allPermissionsRevoked,
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
          AppHeader(title: S.memberSettings, icon: Icons.manage_accounts_outlined),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.menu()
                  : detail == null
                      ? EmptyView(
                          icon: Icons.person_off_outlined,
                          message: S.noDataMember,
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
                          StatusBadge(label: S.roleAdmin, color: c.accent),
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
                label: S.listings2,
                value: Text(
                  '${detail.bookCount}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.accent),
                ),
              ),
              const VerticalDivider1(),
              StatTile(
                label: S.completedTrades,
                value: Text(
                  '${detail.completedOrders}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.accent),
                ),
              ),
              const VerticalDivider1(),
              StatTile(
                label: S.joined,
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
          SectionHeading(title: S.accountStatus),
          if (_isSelf)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                S.ownAccountStatusPermissionsCannotChanged,
                style: TextStyle(fontSize: 12, color: c.textHint),
              ),
            ),
          DisabledHint(
            disabled: _isSelf,
            reason: S.ownAccountStatusPermissionsCannotChanged,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(S.accountEnabled, style: TextStyle(fontSize: 14, color: c.textPrimary)),
              subtitle: Text(
                detail.isActive ? S.canSignUseAppNormally : S.suspendedSignedOutImmediatelyAfterSigning,
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
              value: detail.isActive,
              activeThumbColor: c.accent,
              onChanged: _isBusy ? null : (_) => _toggleStatus(active: true),
            ),
          ),
          Divider(color: c.divider, height: 1),
          DisabledHint(
            disabled: _isSelf,
            reason: S.ownAccountStatusPermissionsCannotChanged,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(S.blocked, style: TextStyle(fontSize: 14, color: c.textPrimary)),
              subtitle: Text(
                detail.isBlacklisted ? S.blockedNoFeaturesAvailable : S.notBlocked,
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
              value: detail.isBlacklisted,
              activeThumbColor: c.danger,
              onChanged: _isBusy ? null : (_) => _toggleStatus(active: false),
            ),
          ),
          Divider(color: c.divider, height: 1),
          DisabledHint(
            disabled: _isSelf,
            reason: S.ownAccountStatusPermissionsCannotChanged,
            child: AppMenuItem(
              icon: Icons.admin_panel_settings_outlined,
              title: S.role,
              subtitle: detail.isAdmin ? S.roleAdmin : S.roleBuyerSeller,
              onTap: _isBusy ? null : _changeRole,
            ),
          ),
          Divider(color: c.divider, height: 1),
          DisabledHint(
            disabled: _isSelf || detail.isAdmin,
            reason: _isSelf
                ? S.changeOwnPasswordGoSettingsChange
                : S.cannotResetAnotherAdminSPassword,
            child: AppMenuItem(
              icon: Icons.lock_reset_rounded,
              title: S.resetPassword,
              subtitle: detail.isAdmin
                  ? S.cannotResetAnotherAdminSPassword
                  : S.generateTemporaryPasswordHandOver,
              isLast: true,
              onTap: _isBusy ? null : () => _resetPassword(detail),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(AdminMemberDetail detail, AppColors c) {
    final manual = detail.bonusPoints != 0;
    final manualPart = manual ? _manualPoints(detail.bonusPoints) : '';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: S.membershipTier),
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
                      detail.currentLevel?.name ?? AppLabels.noLevel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      S.p0PointsAutomaticP1P2(detail.points, detail.basePoints, manualPart),
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
                      S.memberSTierBeenAdjustedBy,
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
              label: Text(S.adjustTier),
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
          SectionHeading(
            title: S.adminPermissions,
            trailing: DisabledHint(
              disabled: _isSelf,
              reason: S.ownAccountStatusPermissionsCannotChanged,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SmallActionButton(
                    label: S.all,
                    onTap: _isBusy ? null : () => _setAllPermissions(true),
                  ),
                  const SizedBox(width: 6),
                  SmallActionButton(
                    label: S.allOff,
                    color: c.danger,
                    onTap: _isBusy ? null : () => _setAllPermissions(false),
                  ),
                ],
              ),
            ),
          ),
          // 不是管理員就沒有後台權限可以調，直接說明比列出一排點不動的開關好。
          if (!detail.isAdmin)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                S.memberNotAdminSoThereNo,
                style: TextStyle(fontSize: 12, height: 1.5, color: c.textHint),
              ),
            )
          else
            for (final entry in AppLabels.permission.entries)
              DisabledHint(
                disabled: _isSelf,
                reason: S.ownAccountStatusPermissionsCannotChanged,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value.$1, style: TextStyle(fontSize: 14, color: c.textPrimary)),
                  subtitle: Text(
                    entry.value.$2,
                    style: TextStyle(fontSize: 11, color: c.textSecondary),
                  ),
                  value: detail.permissions[entry.key] ?? true,
                  activeThumbColor: c.accent,
                  onChanged: _isBusy ? null : (value) => _togglePermission(entry.key, value),
                ),
              ),
        ],
      ),
    );
  }
}
