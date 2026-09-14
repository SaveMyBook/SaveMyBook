import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../models/chat.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_header.dart';
import '../widgets/app_tiles.dart';
import '../widgets/state_views.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _api = ApiService();
  List<ChatPartner>? _users;
  bool _loading = true;
  final Set<int> _busyIds = {};
  final Set<int> _leaving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await _api.fetchBlockedUsers();
    if (!mounted) return;
    setState(() {
      _users = users;
      _leaving.clear();
      _loading = false;
    });
  }

  Future<void> _retry() async {
    setState(() => _loading = true);
    await _load();
  }

  Future<void> _unblock(ChatPartner user) async {
    if (_busyIds.contains(user.userId)) return;
    final confirmed = await showConfirmDialog(
      context,
      title: S.unblock,
      message: S.afterUnblockingP0CanSendMessages(user.nickname),
      confirmLabel: S.unblock,
      icon: Icons.lock_open_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyIds.add(user.userId));
    final error = await _api.setUserBlocked(user.userId, false);
    if (!mounted) return;
    setState(() => _busyIds.remove(user.userId));
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }

    setState(() => _leaving.add(user.userId));
    showAppSnackBar(context, S.userUnblocked);
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    setState(() {
      _users?.removeWhere((u) => u.userId == user.userId);
      _leaving.remove(user.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final users = _users;

    final Widget body;
    if (_loading) {
      body = const LoadingView.menu(key: ValueKey('loading'));
    } else if (users == null) {
      body = RefreshableCenter(
        key: const ValueKey('error'),
        onRefresh: _load,
        child: ErrorView(message: S.unableLoadBlockedUsers, onRetry: _retry),
      );
    } else if (users.isEmpty) {
      body = RefreshableCenter(
        key: const ValueKey('empty'),
        onRefresh: _load,
        child: EmptyView(icon: Icons.block_rounded, message: S.notBlockedAnyUsers),
      );
    } else {
      body = RefreshIndicator(
        key: const ValueKey('list'),
        color: c.accent,
        onRefresh: _load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          itemCount: users.length,
          itemBuilder: (_, i) => FadeSlideIn(index: i, child: _tile(c, users[i])),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.blockedUsers, icon: Icons.block_rounded),
          Expanded(child: SwitchIn(child: body)),
        ],
      ),
    );
  }

  Widget _tile(AppColors c, ChatPartner user) {
    final busy = _busyIds.contains(user.userId);
    return Reveal(
      visible: !_leaving.contains(user.userId),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              UserAvatar(imageUrl: user.avatarUrl, radius: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  user.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
              ),
              TextButton(
                onPressed: busy ? null : () => _unblock(user),
                style: TextButton.styleFrom(foregroundColor: c.accent),
                child: busy
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
                    : Text(S.unblock, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
