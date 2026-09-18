import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../i18n/strings.dart';
import '../../../models/chat.dart';
import '../../../services/api_service.dart';
import '../../../services/photo_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_tiles.dart';
import '../../../widgets/responsive.dart';
import '../../../widgets/state_views.dart';
import '../../books/seller_screen.dart';
import '../groups/create_group_screen.dart' show kGroupNameMax;
import '../groups/group_avatar.dart';
import '../groups/member_picker.dart';

enum ChatRoomSettingsResult { left }

const int kChatAliasMax = 30;

class ChatRoomSettingsScreen extends StatefulWidget {
  final int roomId;

  const ChatRoomSettingsScreen({super.key, required this.roomId});

  @override
  State<ChatRoomSettingsScreen> createState() => _ChatRoomSettingsScreenState();
}

class _ChatRoomSettingsScreenState extends State<ChatRoomSettingsScreen> {
  final ApiService _api = ApiService();
  ChatRoomInfo? _info;
  String? _error;
  bool _loading = true;
  bool _muted = false;
  bool _pinned = false;
  bool _blocked = false;
  bool _togglingMute = false;
  bool _togglingPin = false;
  bool _togglingBlock = false;

  int get _myId => ApiService.currentUser?.userId ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (info, error) = await _api.fetchChatRoomInfo(widget.roomId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (info == null) {
        _error = error ?? S.loadFailed;
        return;
      }
      _error = null;
      _info = info;
      _muted = info.muted;
      _pinned = info.pinned;
      _blocked = info.blocked;
    });
  }

  Future<void> _retry() async {
    setState(() => _loading = true);
    await _load();
  }

  ChatPartner? get _partner {
    final info = _info;
    if (info == null) return null;
    final partner = info.partner;
    if (partner != null && partner.userId != 0) return partner;
    final other = info.members.where((m) => m.userId != _myId).firstOrNull;
    if (other == null) return null;
    return ChatPartner(userId: other.userId, nickname: other.nickname, avatarUrl: other.avatarUrl, alias: other.alias);
  }

  Future<void> _setMuted(bool muted) async {
    if (_togglingMute) return;
    setState(() {
      _togglingMute = true;
      _muted = muted;
    });
    final error = await _api.setChatRoomMuted(widget.roomId, muted);
    if (!mounted) return;
    setState(() {
      _togglingMute = false;
      if (error != null) _muted = !muted;
    });
    showAppSnackBar(context, error ?? (muted ? S.chatMuted : S.chatUnmuted), isError: error != null);
  }

  Future<void> _setPinned(bool pinned) async {
    if (_togglingPin) return;
    setState(() {
      _togglingPin = true;
      _pinned = pinned;
    });
    final error = await _api.setChatRoomPinned(widget.roomId, pinned);
    if (!mounted) return;
    setState(() {
      _togglingPin = false;
      if (error != null) _pinned = !pinned;
    });
    showAppSnackBar(context, error ?? (pinned ? S.chatPinned : S.unpinned), isError: error != null);
  }

  Future<void> _editAlias({required int userId, required String nickname, String? alias}) async {
    final value = await showTextInputDialog(
      context,
      title: S.setNickname,
      message: S.onlyVisible,
      hint: nickname,
      initialValue: alias ?? '',
      maxLength: kChatAliasMax,
      confirmLabel: S.actionSave,
    );
    if (value == null || !mounted) return;
    if (value == (alias ?? '')) return;
    final error = await runBusy(context, () => _api.setChatAlias(userId, value));
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    showAppSnackBar(context, value.isEmpty ? S.nicknameRemoved : S.nicknameUpdated);
    await _load();
  }

  void _openProfile({required int userId, required String name, String? avatarUrl}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerScreen(sellerId: userId, sellerName: name, sellerAvatarUrl: avatarUrl),
      ),
    );
  }

  Future<void> _setBlocked(bool blocked) async {
    final partner = _partner;
    if (partner == null || _togglingBlock) return;
    if (blocked) {
      final confirmed = await showConfirmDialog(
        context,
        title: S.blockUser,
        message: S.afterBlockP0NeitherCanSend(partner.displayName),
        confirmLabel: S.block,
        isDestructive: true,
        icon: Icons.block_rounded,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _togglingBlock = true);
    final error = await _api.setUserBlocked(partner.userId, blocked);
    if (!mounted) return;
    setState(() {
      _togglingBlock = false;
      if (error == null) _blocked = blocked;
    });
    showAppSnackBar(context, error ?? (blocked ? S.userBlocked : S.userUnblocked), isError: error != null);
  }

  Future<void> _deleteRoom() async {
    final name = _partner?.displayName ?? '';
    final confirmed = await showConfirmDialog(
      context,
      title: S.deleteChat,
      message: S.allMessagesWithDeletedBothCannot(name),
      confirmLabel: S.actionDelete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await runBusy(context, () => _api.deleteChatRoom(widget.roomId));
    if (!mounted) return;
    if (ok != true) {
      showAppSnackBar(context, S.somethingWentWrongPleaseTryAgain, isError: true);
      return;
    }
    _api.fetchUnreadChatCount();
    showAppSnackBar(context, S.chatDeleted);
    Navigator.pop(context, ChatRoomSettingsResult.left);
  }

  Future<void> _leaveGroup() async {
    final name = _info?.name ?? '';
    final confirmed = await showConfirmDialog(
      context,
      title: S.leaveGroup,
      message: S.leaveP0(name),
      confirmLabel: S.leave,
      isDestructive: true,
      icon: Icons.logout_rounded,
    );
    if (!confirmed || !mounted) return;
    final error = await runBusy(context, () => _api.leaveChatGroup(widget.roomId));
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    _api.fetchUnreadChatCount();
    showAppSnackBar(context, S.leftGroup);
    Navigator.pop(context, ChatRoomSettingsResult.left);
  }

  Future<void> _renameGroup() async {
    final info = _info;
    if (info == null) return;
    final value = await showTextInputDialog(
      context,
      title: S.groupName,
      initialValue: info.name,
      maxLength: kGroupNameMax,
      confirmLabel: S.actionSave,
      validator: (v) => v.isEmpty ? S.enterGroupName : null,
    );
    if (value == null || value.isEmpty || value == info.name || !mounted) return;
    final error = await runBusy(context, () => _api.updateChatGroup(widget.roomId, name: value));
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    showAppSnackBar(context, S.groupNameUpdated);
    await _load();
  }

  Future<void> _changeGroupAvatar() async {
    final path = await PhotoService.pickAndCrop(context, circular: true, outputSize: 640);
    if (path == null || !mounted) return;
    final error = await runBusy<String?>(context, () async {
      final (url, uploadError) = await _api.uploadChatImage(path);
      if (url == null) return uploadError;
      return _api.updateChatGroup(widget.roomId, avatarUrl: url);
    });
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    showAppSnackBar(context, S.groupPhotoUpdated);
    await _load();
  }

  Future<void> _invite() async {
    final info = _info;
    if (info == null) return;
    final remaining = kGroupMemberLimit - info.members.length;
    if (remaining <= 0) {
      showAppSnackBar(context, S.groupReachedMemberLimit, isError: true);
      return;
    }
    final picked = await pickGroupInvitees(
      context,
      excludeIds: {for (final m in info.members) m.userId},
      maxSelect: remaining < kGroupInviteBatch ? remaining : kGroupInviteBatch,
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final error = await runBusy(
      context,
      () => _api.addChatGroupMembers(widget.roomId, [for (final p in picked) p.userId]),
    );
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    showAppSnackBar(context, S.invitedP0Members(picked.length));
    await _load();
  }

  // 群組暱稱所有成員共用：自己可改自己的，管理員可改所有人的。
  Future<void> _editGroupNickname(ChatMember member) async {
    final isMe = member.userId == _myId;
    final value = await showTextInputDialog(
      context,
      title: isMe ? S.myNicknameGroup : S.setGroupNickname,
      message: S.allGroupMembersSeeNickname,
      hint: member.nickname,
      initialValue: member.alias ?? '',
      maxLength: kChatAliasMax,
      confirmLabel: S.actionSave,
    );
    if (value == null || !mounted) return;
    if (value.trim() == (member.alias ?? '')) return;
    final (info, error) =
        await runBusy(context, () => _api.setChatGroupNickname(widget.roomId, member.userId, value)) ??
        (null, S.actionFailed);
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    showAppSnackBar(context, value.trim().isEmpty ? S.nicknameRemoved : S.nicknameUpdated);
    if (info != null) {
      setState(() => _info = info);
    } else {
      await _load();
    }
  }

  Future<void> _memberActions(ChatMember member) async {
    final info = _info;
    if (info == null) return;
    if (member.userId == _myId) {
      await _editGroupNickname(member);
      return;
    }
    final c = AppColors.of(context);
    final manage = info.isOwner;
    final choice = await showOptionSheet<String>(
      context,
      title: member.displayName,
      subtitle: member.alias != null ? member.nickname : null,
      options: [
        if (manage && member.isOwner)
          SheetOption(value: 'revoke', label: S.removeAdminRole, icon: Icons.remove_moderator_outlined),
        if (manage) SheetOption(value: 'nickname', label: S.setGroupNickname, icon: Icons.edit_outlined),
        SheetOption(value: 'profile', label: S.viewProfile, icon: Icons.person_outline_rounded),
        if (manage && !member.isOwner)
          SheetOption(value: 'promote', label: S.makeAdmin, icon: Icons.add_moderator_outlined),
        if (manage && !member.isOwner)
          SheetOption(value: 'remove', label: S.removeMember, icon: Icons.person_remove_outlined, color: c.danger),
      ],
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'nickname':
        await _editGroupNickname(member);
      case 'profile':
        _openProfile(userId: member.userId, name: member.displayName, avatarUrl: member.avatarUrl);
      case 'promote':
        await _setAdmin(member, true);
      case 'revoke':
        await _setAdmin(member, false);
      case 'remove':
        await _removeMember(member);
    }
  }

  Future<void> _setAdmin(ChatMember member, bool admin) async {
    final name = member.displayName;
    final confirmed = await showConfirmDialog(
      context,
      title: admin ? S.makeAdmin : S.removeAdminRole,
      message: admin ? S.makeP0Admin(name) : S.removeAdminRoleFromP0(name),
      confirmLabel: admin ? S.makeAdmin : S.remove2,
      isDestructive: !admin,
      icon: admin ? Icons.add_moderator_outlined : Icons.remove_moderator_outlined,
    );
    if (!confirmed || !mounted) return;
    final (info, error) =
        await runBusy(context, () => _api.setChatMemberRole(widget.roomId, member.userId, admin: admin)) ??
        (null, S.actionFailed);
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    HapticFeedback.selectionClick();
    showAppSnackBar(context, admin ? S.p0NowAdmin(name) : S.removedAdminRoleFromP0(name));
    if (info != null) {
      setState(() => _info = info);
    } else {
      await _load();
    }
  }

  Future<void> _removeMember(ChatMember member) async {
    final name = member.displayName;
    final confirmed = await showConfirmDialog(
      context,
      title: S.removeMember,
      message: S.removeP0FromGroup(name),
      confirmLabel: S.remove,
      isDestructive: true,
      icon: Icons.person_remove_outlined,
    );
    if (!confirmed || !mounted) return;
    final error = await runBusy(context, () => _api.removeChatGroupMember(widget.roomId, member.userId));
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    showAppSnackBar(context, S.memberRemoved);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final info = _info;

    final Widget body;
    if (_loading && info == null) {
      body = const LoadingView.menu(key: ValueKey('loading'));
    } else if (info == null) {
      body = RefreshableCenter(
        key: const ValueKey('error'),
        onRefresh: _load,
        child: ErrorView(message: _error, onRetry: _retry),
      );
    } else {
      body = RefreshIndicator(
        key: const ValueKey('content'),
        color: c.accent,
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: responsiveListPadding(
              constraints,
              maxWidth: Breakpoints.formMaxWidth,
              horizontal: 20,
              top: 20,
              bottom: 40,
            ),
            children: info.isGroup ? _groupSections(c, info) : _directSections(c, info),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.chatSettings, icon: Icons.tune_rounded),
          Expanded(child: SwitchIn(child: body)),
        ],
      ),
    );
  }

  List<Widget> _directSections(AppColors c, ChatRoomInfo info) {
    final partner = _partner;
    if (partner == null) return [EmptyView(icon: Icons.person_off_outlined, message: S.loadFailed)];
    final hasAlias = partner.alias != null;
    var index = 0;
    return [
      FadeSlideIn(
        index: index++,
        child: _profileHeader(
          c,
          avatar: UserAvatar(
            imageUrl: partner.avatarUrl,
            radius: 44,
            background: c.card,
            enablePreview: true,
            previewTitle: partner.displayName,
          ),
          title: partner.displayName,
          subtitle: hasAlias ? partner.nickname : null,
        ),
      ),
      _section(c, index++, null, [
        _row(
          c,
          icon: Icons.edit_outlined,
          title: S.setNickname,
          value: partner.alias,
          onTap: () => _editAlias(userId: partner.userId, nickname: partner.nickname, alias: partner.alias),
        ),
        _row(
          c,
          icon: Icons.person_outline_rounded,
          title: S.viewProfile,
          onTap: () => _openProfile(userId: partner.userId, name: partner.displayName, avatarUrl: partner.avatarUrl),
        ),
      ]),
      _section(c, index++, null, _switches(c)),
      _section(c, index++, null, [
        _row(
          c,
          icon: _blocked ? Icons.lock_open_rounded : Icons.block_rounded,
          title: _blocked ? S.unblock : S.blockUser,
          color: _blocked ? null : c.danger,
          busy: _togglingBlock,
          chevron: false,
          onTap: () => _setBlocked(!_blocked),
        ),
        _row(
          c,
          icon: Icons.delete_outline_rounded,
          title: S.deleteChat,
          color: c.danger,
          chevron: false,
          onTap: _deleteRoom,
        ),
      ]),
    ];
  }

  List<Widget> _groupSections(AppColors c, ChatRoomInfo info) {
    final members = [...info.members]
      ..sort((a, b) {
        if (a.userId == _myId) return -1;
        if (b.userId == _myId) return 1;
        if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
        return 0;
      });
    final count = members.length;
    var index = 0;
    return [
      FadeSlideIn(
        index: index++,
        child: _profileHeader(
          c,
          avatar: Stack(
            clipBehavior: Clip.none,
            children: [
              ChatRoomAvatar(imageUrl: info.avatarUrl, isGroup: true, radius: 44, onTap: _changeGroupAvatar),
              Positioned(
                right: -2,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.scaffold, width: 3),
                    ),
                    child: const Icon(Icons.photo_camera_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          title: info.name,
          titleSuffix: '($count)',
          onEditTitle: _renameGroup,
        ),
      ),
      _section(c, index++, null, _switches(c)),
      _section(c, index++, S.membersP0(count), [
        _row(
          c,
          icon: Icons.person_add_alt_1_outlined,
          title: S.inviteMembers,
          color: c.accent,
          chevron: false,
          onTap: _invite,
        ),
        for (final member in members) _memberRow(c, member),
      ]),
      _section(c, index++, null, [
        _row(c, icon: Icons.logout_rounded, title: S.leaveGroup, color: c.danger, chevron: false, onTap: _leaveGroup),
      ]),
    ];
  }

  List<Widget> _switches(AppColors c) => [
    _switchRow(
      c,
      icon: _muted ? Icons.notifications_off_outlined : Icons.notifications_none_rounded,
      title: S.muteNotifications,
      value: _muted,
      onChanged: _togglingMute ? null : _setMuted,
    ),
    _switchRow(
      c,
      icon: Icons.push_pin_outlined,
      title: S.pinChat,
      value: _pinned,
      onChanged: _togglingPin ? null : _setPinned,
    ),
  ];

  Widget _profileHeader(
    AppColors c, {
    required Widget avatar,
    required String title,
    String? titleSuffix,
    String? subtitle,
    VoidCallback? onEditTitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        children: [
          avatar,
          const SizedBox(height: 14),
          InkWell(
            onTap: onEditTitle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary, height: 1.3),
                    ),
                  ),
                  if (titleSuffix != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      titleSuffix,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.textSecondary),
                    ),
                  ],
                  if (onEditTitle != null) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.edit_outlined, size: 18, color: c.iconInactive),
                  ],
                ],
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(AppColors c, int index, String? title, List<Widget> rows) {
    return FadeSlideIn(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary),
                ),
              ),
            AppCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) Divider(height: 1, thickness: 1, indent: 56, color: c.divider),
                      rows[i],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    AppColors c, {
    required IconData icon,
    required String title,
    String? value,
    Color? color,
    bool chevron = true,
    bool busy = false,
    VoidCallback? onTap,
  }) {
    return _SettingsTile(
      leading: Icon(icon, size: 22, color: color ?? c.textPrimary),
      title: title,
      titleColor: color,
      onTap: busy ? null : onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null && value.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: c.textSecondary),
              ),
            ),
          if (busy)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
            )
          else if (chevron)
            Icon(Icons.chevron_right_rounded, size: 22, color: c.iconInactive),
        ],
      ),
    );
  }

  Widget _switchRow(
    AppColors c, {
    required IconData icon,
    required String title,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return _SettingsTile(
      leading: Icon(icon, size: 22, color: c.textPrimary),
      title: title,
      onTap: onChanged == null ? null : () => onChanged(!value),
      trailing: Switch.adaptive(value: value, activeThumbColor: c.accent, onChanged: onChanged),
    );
  }

  Widget _memberRow(AppColors c, ChatMember member) {
    final isMe = member.userId == _myId;
    return _SettingsTile(
      leading: UserAvatar(imageUrl: member.avatarUrl, radius: 18),
      leadingWidth: 36,
      title: member.displayName,
      subtitle: member.alias != null ? member.nickname : null,
      onTap: () => _memberActions(member),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMe) StatusBadge(label: S.me, color: c.neutral),
          if (member.isOwner) ...[if (isMe) const SizedBox(width: 6), StatusBadge(label: S.roleAdmin, color: c.accent)],
          const SizedBox(width: 4),
          Icon(isMe ? Icons.edit_outlined : Icons.more_horiz_rounded, size: 20, color: c.iconInactive),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final Widget leading;
  final double leadingWidth;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.leading,
    required this.title,
    required this.trailing,
    this.leadingWidth = 24,
    this.subtitle,
    this.titleColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: AnimatedContainer(
          duration: Motion.micro,
          constraints: const BoxConstraints(minHeight: 58),
          padding: EdgeInsets.fromLTRB(16, 8, leadingWidth > 24 ? 14 : 12, 8),
          child: Row(
            children: [
              SizedBox(
                width: leadingWidth,
                child: Center(child: leading),
              ),
              SizedBox(width: leadingWidth > 24 ? 12 : 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: titleColor ?? c.textPrimary),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
