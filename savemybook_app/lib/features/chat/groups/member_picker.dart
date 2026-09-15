import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/chat.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/app_forms.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_tiles.dart';
import '../../../widgets/responsive.dart';
import '../../../widgets/state_views.dart';
import '../widgets/chat_format.dart';
import '../../../i18n/strings.dart';

const int kGroupMemberLimit = 100;
const int kGroupInviteBatch = 50;

Future<List<ChatPartner>?> pickGroupInvitees(
  BuildContext context, {
  required Set<int> excludeIds,
  required int maxSelect,
}) {
  return Navigator.push<List<ChatPartner>>(
    context,
    MaterialPageRoute(builder: (_) => _InviteMembersScreen(excludeIds: excludeIds, maxSelect: maxSelect)),
  );
}

class _InviteMembersScreen extends StatefulWidget {
  final Set<int> excludeIds;
  final int maxSelect;

  const _InviteMembersScreen({required this.excludeIds, required this.maxSelect});

  @override
  State<_InviteMembersScreen> createState() => _InviteMembersScreenState();
}

class _InviteMembersScreenState extends State<_InviteMembersScreen> {
  List<ChatPartner> _selected = const [];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.inviteMembers, icon: Icons.person_add_alt_1_outlined),
          Expanded(
            child: ChatMemberPicker(
              selected: _selected,
              onChanged: (value) => setState(() => _selected = value),
              excludeIds: widget.excludeIds,
              maxSelect: widget.maxSelect,
              confirmLabel: S.invite,
              onConfirm: () => Navigator.pop(context, _selected),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMemberPicker extends StatefulWidget {
  final List<ChatPartner> selected;
  final ValueChanged<List<ChatPartner>> onChanged;
  final Set<int> excludeIds;
  final int maxSelect;
  final String confirmLabel;
  final VoidCallback onConfirm;

  const ChatMemberPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.confirmLabel,
    required this.onConfirm,
    this.excludeIds = const {},
    this.maxSelect = kGroupMemberLimit - 1,
  });

  @override
  State<ChatMemberPicker> createState() => _ChatMemberPickerState();
}

class _ChatMemberPickerState extends State<ChatMemberPicker> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _chipScroll = ScrollController();
  List<ChatPartner>? _contacts;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _chipScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final myId = ApiService.currentUser?.userId ?? 0;
    final rooms = await ApiService().fetchChatRooms();
    if (!mounted) return;
    final seen = <int>{};
    final contacts = <ChatPartner>[
      for (final room in rooms)
        if (!room.isGroup &&
            !room.blocked &&
            room.partner.userId != 0 &&
            room.partner.userId != myId &&
            !widget.excludeIds.contains(room.partner.userId) &&
            seen.add(room.partner.userId))
          room.partner,
    ];
    setState(() => _contacts = contacts);
  }

  List<ChatPartner> get _visible {
    final contacts = _contacts ?? const [];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return contacts;
    return contacts
        .where((p) => p.displayName.toLowerCase().contains(q) || p.nickname.toLowerCase().contains(q))
        .toList();
  }

  bool _isSelected(ChatPartner p) => widget.selected.any((s) => s.userId == p.userId);

  void _toggle(ChatPartner p) {
    HapticFeedback.selectionClick();
    if (_isSelected(p)) {
      widget.onChanged(widget.selected.where((s) => s.userId != p.userId).toList());
      return;
    }
    if (widget.selected.length >= widget.maxSelect) {
      final limit = widget.maxSelect;
      showAppSnackBar(context, S.canSelectUpP0People(limit), isError: true);
      return;
    }
    widget.onChanged([...widget.selected, p]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chipScroll.hasClients) {
        _chipScroll.animateTo(_chipScroll.position.maxScrollExtent, duration: Motion.base, curve: Motion.standard);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final contacts = _contacts;

    final Widget body;
    if (contacts == null) {
      body = const LoadingView.menu(key: ValueKey('loading'));
    } else if (contacts.isEmpty) {
      body = RefreshableCenter(
        key: const ValueKey('empty'),
        onRefresh: _load,
        child: EmptyView(icon: Icons.person_search_outlined, message: S.noChatsChooseFrom),
      );
    } else {
      final visible = _visible;
      body = ResponsiveListPadding(
        key: const ValueKey('list'),
        maxWidth: Breakpoints.formMaxWidth,
        top: 4,
        bottom: 24,
        builder: (context, padding) => visible.isEmpty
            ? ListView(
                padding: padding,
                children: [
                  const SizedBox(height: 40),
                  EmptyView(icon: Icons.search_off_rounded, message: S.noMatchingPeople),
                ],
              )
            : ListView.builder(
                padding: padding,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: visible.length,
                itemBuilder: (_, i) => FadeSlideIn(index: i, child: _tile(c, visible[i])),
              ),
      );
    }

    final count = widget.selected.length;
    final label = widget.confirmLabel;

    return Column(
      children: [
        ResponsiveListPadding(
          maxWidth: Breakpoints.formMaxWidth,
          top: 16,
          bottom: 0,
          builder: (context, padding) => Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSearchField(
                  controller: _search,
                  hint: S.searchByName,
                  onChanged: (value) => setState(() => _query = value),
                ),
                AnimatedSize(
                  duration: Motion.base,
                  curve: Motion.standard,
                  alignment: Alignment.topCenter,
                  child: widget.selected.isEmpty ? const SizedBox(width: double.infinity, height: 12) : _chips(c),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: SwitchIn(child: body)),
        Container(
          decoration: BoxDecoration(
            color: c.card,
            border: Border(top: BorderSide(color: c.divider)),
          ),
          child: SafeArea(
            top: false,
            child: ResponsiveListPadding(
              maxWidth: Breakpoints.formMaxWidth,
              top: 10,
              bottom: 10,
              builder: (context, padding) => Padding(
                padding: padding,
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: count == 0 ? null : widget.onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: chatMineBubble(c),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: c.inputFill,
                      disabledForegroundColor: c.textHint,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      count == 0 ? label : '$label（$count）',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chips(AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          controller: _chipScroll,
          scrollDirection: Axis.horizontal,
          itemCount: widget.selected.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final p = widget.selected[i];
            return PopIn(
              triggerKey: p.userId,
              child: GestureDetector(
                onTap: () => _toggle(p),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(3, 3, 8, 3),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UserAvatar(imageUrl: p.avatarUrl, radius: 15),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(
                          p.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.close_rounded, size: 15, color: c.textSecondary),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tile(AppColors c, ChatPartner p) {
    final selected = _isSelected(p);
    final hasAlias = p.displayName != p.nickname;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        onTap: () => _toggle(p),
        child: Row(
          children: [
            UserAvatar(imageUrl: p.avatarUrl, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                  if (hasAlias)
                    Text(
                      p.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: Motion.micro,
              curve: Motion.standard,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? c.accent : Colors.transparent,
                border: Border.all(color: selected ? c.accent : c.iconInactive, width: 1.8),
              ),
              child: AnimatedScale(
                scale: selected ? 1 : 0,
                duration: Motion.micro,
                curve: Motion.pop,
                child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
