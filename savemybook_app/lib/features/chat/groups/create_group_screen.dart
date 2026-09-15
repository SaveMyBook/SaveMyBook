import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../widgets/chat_format.dart';
import 'member_picker.dart';
import '../../../i18n/strings.dart';

const int kGroupNameMax = 50;

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _name = TextEditingController();
  List<ChatPartner> _selected = const [];
  String? _avatarPath;
  bool _profileStep = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _back() {
    if (_creating) return;
    if (_profileStep) {
      FocusScope.of(context).unfocus();
      setState(() => _profileStep = false);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _pickAvatar() async {
    FocusScope.of(context).unfocus();
    final path = await PhotoService.pickAndCrop(context, circular: true, outputSize: 640);
    if (path == null || !mounted) return;
    setState(() => _avatarPath = path);
  }

  void _remove(ChatPartner p) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected = _selected.where((s) => s.userId != p.userId).toList();
      if (_selected.isEmpty) _profileStep = false;
    });
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _selected.isEmpty || _creating) return;
    FocusScope.of(context).unfocus();
    setState(() => _creating = true);
    final api = ApiService();

    final result = await runBusy<(int?, String?)>(context, () async {
      String? avatarUrl;
      final path = _avatarPath;
      if (path != null) {
        final (url, error) = await api.uploadChatImage(path);
        if (error != null) return (null, error);
        avatarUrl = url;
      }
      return api.createChatGroup(
        name: name,
        memberIds: [for (final p in _selected) p.userId],
        avatarUrl: avatarUrl,
      );
    });
    if (!mounted) return;
    setState(() => _creating = false);

    final (roomId, error) = result ?? (null, null);
    if (roomId == null) {
      showAppSnackBar(context, error ?? S.couldNotCreateGroup, isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context, roomId);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return PopScope(
      canPop: !_profileStep && !_creating,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: Column(
          children: [
            AppHeader(
              title: _profileStep ? S.groupDetails : S.selectMembers,
              icon: Icons.group_add_outlined,
              onBack: _back,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.base,
                switchInCurve: Motion.enterCurve,
                switchOutCurve: Motion.exitCurve,
                transitionBuilder: (child, animation) {
                  final forward = child.key == const ValueKey('profile');
                  final offset = Tween(begin: Offset(forward ? 0.08 : -0.08, 0), end: Offset.zero).animate(animation);
                  return FadeTransition(opacity: animation, child: SlideTransition(position: offset, child: child));
                },
                child: _profileStep
                    ? KeyedSubtree(key: const ValueKey('profile'), child: _profile(c))
                    : KeyedSubtree(
                        key: const ValueKey('members'),
                        child: ChatMemberPicker(
                          selected: _selected,
                          onChanged: (value) => setState(() => _selected = value),
                          confirmLabel: S.next,
                          onConfirm: () => setState(() => _profileStep = true),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profile(AppColors c) {
    final name = _name.text.trim();
    final path = _avatarPath;
    final count = _selected.length + 1;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: responsiveListPadding(constraints, maxWidth: Breakpoints.formMaxWidth, horizontal: 20, top: 28, bottom: 24),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.accent.withValues(alpha: c.isDark ? 0.24 : 0.12),
                          ),
                          child: path != null
                              ? Image.file(File(path), fit: BoxFit.cover)
                              : Icon(Icons.groups_rounded, size: 52, color: c.accent),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 2,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: chatMineBubble(c),
                              shape: BoxShape.circle,
                              border: Border.all(color: c.scaffold, width: 3),
                            ),
                            child: const Icon(Icons.photo_camera_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _name,
                  autofocus: false,
                  maxLength: kGroupNameMax,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _create(),
                  style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: S.groupName,
                    hintStyle: TextStyle(color: c.textHint, fontSize: 16, fontWeight: FontWeight.w500),
                    filled: true,
                    fillColor: c.card,
                    counterStyle: TextStyle(color: c.textHint, fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: c.accent, width: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    S.membersP0(count),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary),
                  ),
                ),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 10,
                    children: [
                      _memberCell(c, name: ApiService.currentUser?.nickname ?? '', avatarUrl: ApiService.currentUser?.avatarUrl),
                      for (final (i, p) in _selected.indexed)
                        FadeSlideIn(
                          index: i + 1,
                          child: _memberCell(c, name: p.displayName, avatarUrl: p.avatarUrl, onRemove: () => _remove(p)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.divider))),
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
                    onPressed: name.isEmpty || _creating ? null : _create,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: chatMineBubble(c),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: c.inputFill,
                      disabledForegroundColor: c.textHint,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(S.createGroup, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _memberCell(AppColors c, {required String name, String? avatarUrl, VoidCallback? onRemove}) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              UserAvatar(imageUrl: avatarUrl, radius: 24),
              if (onRemove != null)
                Positioned(
                  right: -4,
                  top: -4,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: c.textSecondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.card, width: 2),
                      ),
                      child: const Icon(Icons.close_rounded, size: 11, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}
