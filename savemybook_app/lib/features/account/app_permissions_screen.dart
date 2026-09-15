import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_permissions.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/biometric_icon.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

class AppPermissionsScreen extends StatefulWidget {
  const AppPermissionsScreen({super.key});

  @override
  State<AppPermissionsScreen> createState() => _AppPermissionsScreenState();
}

class _AppPermissionsScreenState extends State<AppPermissionsScreen> {
  List<AppPermissionState>? _states;
  final Set<AppPermission> _busy = {};
  bool _requestingAll = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final states = await AppPermissions.load();
    if (!mounted) return;
    setState(() => _states = states);
  }

  void _replace(AppPermissionState state) {
    final states = _states;
    if (states == null) return;
    setState(() => _states = [for (final s in states) s.permission == state.permission ? state : s]);
  }

  Future<void> _act(AppPermissionState state) async {
    if (_busy.contains(state.permission) || _requestingAll) return;
    HapticFeedback.selectionClick();
    if (!state.canRequest) {
      await AppPermissions.openSettings(state.permission);
      return;
    }
    setState(() => _busy.add(state.permission));
    final updated = await AppPermissions.request(state.permission);
    if (!mounted) return;
    setState(() => _busy.remove(state.permission));
    if (updated != null) _replace(updated);
  }

  Future<void> _requestAll() async {
    final pending = _states?.where((s) => s.canRequest).toList() ?? const [];
    if (pending.isEmpty || _requestingAll) return;
    HapticFeedback.selectionClick();
    setState(() => _requestingAll = true);
    for (final state in pending) {
      if (!mounted) return;
      setState(() => _busy.add(state.permission));
      final updated = await AppPermissions.request(state.permission);
      if (!mounted) return;
      setState(() => _busy.remove(state.permission));
      if (updated != null) _replace(updated);
    }
    if (!mounted) return;
    setState(() => _requestingAll = false);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final states = _states;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.appPermissions, icon: Icons.app_settings_alt_outlined),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (states == null) {
                  return Center(child: CircularProgressIndicator(color: c.accent));
                }
                if (states.isEmpty) {
                  return EmptyView(icon: Icons.app_settings_alt_outlined, message: S.noPermissionsRequiredDevice);
                }
                final pending = states.where((s) => s.canRequest).length;
                return RefreshIndicator(
                  color: c.accent,
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: responsiveListPadding(
                      constraints,
                      maxWidth: Breakpoints.formMaxWidth,
                      horizontal: 20,
                      top: 20,
                      bottom: 40,
                    ),
                    children: [
                      FadeSlideIn(
                        child: AppCard(
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Column(
                              children: [
                                for (final (i, state) in states.indexed) ...[
                                  if (i > 0) Divider(height: 1, thickness: 1, indent: 70, color: c.divider),
                                  _PermissionRow(
                                    state: state,
                                    busy: _busy.contains(state.permission),
                                    onAction: () => _act(state),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      Reveal(
                        visible: pending > 0,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: FadeSlideIn(
                            index: 1,
                            child: FilledButton.icon(
                              onPressed: _requestingAll ? null : _requestAll,
                              icon: _requestingAll
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.done_all_rounded, size: 20),
                              label: Text(S.allowAll, maxLines: 1, overflow: TextOverflow.ellipsis),
                              style: FilledButton.styleFrom(
                                backgroundColor: c.accent,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final AppPermissionState state;
  final bool busy;
  final VoidCallback onAction;

  const _PermissionRow({required this.state, required this.busy, required this.onAction});

  IconData get _icon => switch (state.permission) {
        AppPermission.notification => Icons.notifications_none_rounded,
        AppPermission.camera => Icons.photo_camera_outlined,
        AppPermission.photos => Icons.photo_library_outlined,
        AppPermission.photosAddOnly => Icons.add_photo_alternate_outlined,
        AppPermission.microphone => Icons.mic_none_rounded,
        AppPermission.location => Icons.location_on_outlined,
        AppPermission.biometrics => Icons.fingerprint_rounded,
      };

  String get _title => switch (state.permission) {
        AppPermission.notification => S.alerts,
        AppPermission.camera => S.camera,
        AppPermission.photos => S.photosRead,
        AppPermission.photosAddOnly => S.photosSave,
        AppPermission.microphone => S.microphone,
        AppPermission.location => S.location,
        AppPermission.biometrics => state.faceId ? 'Face ID' : S.biometrics,
      };

  String get _description => switch (state.permission) {
        AppPermission.notification => S.orderUpdatesChatMessagesAnnouncements,
        AppPermission.camera => S.scanBarcodesTakeBookPhotos,
        AppPermission.photos => S.chooseBookPhotosProfilePicturesChat,
        AppPermission.photosAddOnly => S.saveQrCodesPhotos,
        AppPermission.microphone => S.recordVoiceMessagesChats,
        AppPermission.location => S.showNearestSmartLockersTheirDistance,
        AppPermission.biometrics => S.quickSignPaymentConfirmation,
      };

  (String, Color) _status(AppColors c) => switch (state.status) {
        AppPermissionStatus.granted => (S.allowed, c.success),
        AppPermissionStatus.limited => (S.limited, c.warning),
        AppPermissionStatus.denied => (S.notAllowed, c.textSecondary),
        AppPermissionStatus.restricted => (S.restricted, c.warning),
        AppPermissionStatus.permanentlyDenied => (S.denied, c.danger),
      };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (label, color) = _status(c);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: busy ? null : onAction,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Motion.base,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (state.isGranted ? c.accent : c.textSecondary).withValues(alpha: c.isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: state.permission == AppPermission.biometrics && state.faceId
                      ? Center(child: FaceIdIcon(size: 22, color: state.isGranted ? c.accent : c.textSecondary))
                      : Icon(_icon, size: 22, color: state.isGranted ? c.accent : c.textSecondary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
                          ),
                          SwitchIn(
                            duration: Motion.micro,
                            child: StatusBadge(key: ValueKey(state.status), label: label, color: color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, height: 1.35, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 124),
                  child: SwitchIn(
                    duration: Motion.micro,
                    child: busy
                        ? SizedBox(
                            key: const ValueKey('busy'),
                            width: 44,
                            height: 32,
                            child: Center(
                              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
                            ),
                          )
                        : _actionButton(c),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(AppColors c) {
    const padding = EdgeInsets.symmetric(horizontal: 14);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    const textStyle = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600);

    if (state.canRequest) {
      return FilledButton(
        key: const ValueKey('request'),
        onPressed: onAction,
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          minimumSize: const Size(0, 34),
          padding: padding,
          shape: shape,
          textStyle: textStyle,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(S.allow, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }
    return OutlinedButton(
      key: const ValueKey('settings'),
      onPressed: onAction,
      style: OutlinedButton.styleFrom(
        foregroundColor: state.isGranted ? c.textSecondary : c.accent,
        side: BorderSide(color: state.isGranted ? c.border : c.accent.withValues(alpha: 0.5)),
        minimumSize: const Size(0, 34),
        padding: padding,
        shape: shape,
        textStyle: textStyle,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(state.isGranted ? S.settings : S.openSettings, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
