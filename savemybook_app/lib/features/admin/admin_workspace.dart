import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../i18n/strings.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_info.dart';
import '../../utils/motion.dart';
import '../../widgets/app_header.dart';
import '../../widgets/guards.dart';
import '../../widgets/responsive.dart';

abstract final class AdminSections {
  static const home = 'home';
  static const orders = 'orders';
  static const disputes = 'disputes';
  static const books = 'books';
  static const moderation = 'moderation';
  static const categories = 'categories';
  static const members = 'members';
  static const tiers = 'tiers';
  static const wallets = 'wallets';
  static const cabinets = 'cabinets';
  static const deposits = 'deposits';
  static const maintenance = 'maintenance';
  static const stats = 'stats';
  static const announcements = 'announcements';
  static const tickets = 'tickets';
  static const faq = 'faq';
  static const legal = 'legal';
  static const audit = 'audit';
  static const ai = 'ai';
  static const auth = 'auth';
  static const backups = 'backups';
  static const deletions = 'deletions';
}

class AdminSection {
  final String id;
  final IconData icon;
  final String title;
  final int badge;
  final WidgetBuilder builder;

  const AdminSection({required this.id, required this.icon, required this.title, required this.builder, this.badge = 0});
}

class AdminSectionGroup {
  final String title;
  final List<AdminSection> sections;

  const AdminSectionGroup(this.title, this.sections);
}

class AdminWorkspace extends StatefulWidget {
  final AdminSection home;
  final List<AdminSectionGroup> groups;
  final ValueChanged<String>? onSectionChanged;

  const AdminWorkspace({super.key, required this.home, required this.groups, this.onSectionChanged});

  static const double extendedWidth = 264;
  static const double railWidth = 76;

  /// 不在工作區（手機）時回傳 false，由呼叫端照原本推入頁面；在工作區內直接推入會在原分區再開一份同一個管理頁。
  static bool show(BuildContext context, String id, {Widget? root}) {
    final state = context.findAncestorStateOfType<AdminWorkspaceState>();
    if (state == null) return false;
    state.open(id, root: root);
    return true;
  }

  @override
  State<AdminWorkspace> createState() => AdminWorkspaceState();
}

class _SectionSlot {
  GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
  final routes = _SectionRoutes();
  final heroController = MaterialApp.createMaterialHeroController();
  _SectionNavigator? navigator;
  Widget? root;
  bool canPop = false;

  bool get hasUnsavedChanges => routes.routes.any((route) => route.popDisposition == RoutePopDisposition.doNotPop);

  void reset(Widget? newRoot) {
    key = GlobalKey<NavigatorState>();
    navigator = null;
    root = newRoot;
    canPop = false;
  }

  void dispose() => heroController.dispose();
}

class AdminWorkspaceState extends State<AdminWorkspace> {
  final Map<String, _SectionSlot> _slots = {};
  final Set<String> _opened = {};
  late String _selected = widget.home.id;
  bool _overlay = false;

  String get selectedId => _selected;

  List<AdminSection> get _sections => [widget.home, for (final group in widget.groups) ...group.sections];

  _SectionSlot _slot(String id) => _slots.putIfAbsent(id, _SectionSlot.new);

  @override
  void initState() {
    super.initState();
    _opened.add(_selected);
  }

  @override
  void dispose() {
    for (final slot in _slots.values) {
      slot.dispose();
    }
    super.dispose();
  }

  void open(String id, {Widget? root, Widget? page}) {
    if (!_sections.any((s) => s.id == id)) return;
    final slot = _slot(id);
    if (root != null) {
      slot.reset(root);
    } else if (page != null) {
      slot.key.currentState?.popUntil((route) => route.isFirst);
    }
    if (_selected == id && root == null && page == null) {
      _reselect(slot);
    } else {
      setState(() {
        _selected = id;
        _opened.add(id);
        _overlay = false;
      });
    }
    widget.onSectionChanged?.call(id);
    if (page != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) slot.key.currentState?.push(MaterialPageRoute<void>(builder: (_) => page));
      });
    }
  }

  void _select(String id) {
    if (id != _selected) HapticFeedback.selectionClick();
    open(id);
  }

  // popUntil 不經過 PopScope，有未儲存的變更時改用 maybePop，由頁面詢問是否捨棄
  void _reselect(_SectionSlot slot) {
    final navigator = slot.key.currentState;
    if (navigator == null || !navigator.canPop()) return;
    if (slot.hasUnsavedChanges) {
      navigator.maybePop();
    } else {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  void _leaveRoot() {
    if (mounted && _selected != widget.home.id) open(widget.home.id);
  }

  Future<void> _handleBack() async {
    if (_overlay) {
      setState(() => _overlay = false);
      return;
    }
    final navigator = _slot(_selected).key.currentState;
    if (navigator is _SectionNavigatorState && await navigator.systemBack()) return;
    if (!mounted) return;
    if (_selected != widget.home.id) {
      open(widget.home.id);
    } else {
      await _exit();
    }
  }

  Future<void> _exit() async {
    final dirty = _opened.any((id) => _slot(id).hasUnsavedChanges);
    if (dirty && !await UnsavedGuard.confirm(context)) return;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final sections = _sections;
    final index = sections.indexWhere((s) => s.id == _selected).clamp(0, sections.length - 1);
    final canExit = Navigator.of(context).canPop();

    return LayoutBuilder(
      builder: (context, constraints) {
        final extended = constraints.maxWidth >= Breakpoints.expanded;
        if (extended) _overlay = false;

        Widget sideNav({required bool extended, required ValueChanged<String> onSelect, VoidCallback? onToggle}) => AdminSideNav(
          home: widget.home,
          groups: widget.groups,
          selectedId: _selected,
          extended: extended,
          onSelect: onSelect,
          onExit: canExit ? _exit : null,
          onToggle: onToggle,
        );

        return PopScope(
          canPop: _selected == widget.home.id && !_slot(_selected).canPop && !_overlay,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBack();
          },
          child: Scaffold(
            backgroundColor: c.scaffold,
            body: Stack(
              children: [
                Row(
                  children: [
                    sideNav(extended: extended, onSelect: _select, onToggle: extended ? null : () => setState(() => _overlay = true)),
                    Expanded(
                      child: MediaQuery.removePadding(
                        context: context,
                        removeLeft: true,
                        child: _SectionScope(
                          sections: sections,
                          child: IndexedStack(
                            index: index,
                            children: [
                              for (final (i, section) in sections.indexed)
                                _opened.contains(section.id)
                                    ? TickerMode(enabled: i == index, child: _buildNavigator(section))
                                    : const SizedBox.shrink(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!extended) ...[
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !_overlay,
                      child: AnimatedOpacity(
                        duration: Motion.base,
                        opacity: _overlay ? 1 : 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _overlay = false),
                          child: ColoredBox(color: c.scrim),
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: Motion.base,
                    curve: Motion.standard,
                    top: 0,
                    bottom: 0,
                    left: _overlay ? 0 : -(AdminWorkspace.extendedWidth + MediaQuery.paddingOf(context).left + 24),
                    child: Material(
                      elevation: 16,
                      child: sideNav(extended: true, onSelect: _select, onToggle: () => setState(() => _overlay = false)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigator(AdminSection section) {
    final slot = _slot(section.id);
    return NotificationListener<NavigationNotification>(
      onNotification: (notification) {
        if (slot.canPop != notification.canHandlePop) {
          slot.canPop = notification.canHandlePop;
          if (section.id == _selected && mounted) setState(() {});
        }
        return true;
      },
      child: HeroControllerScope(
        controller: slot.heroController,
        child: slot.navigator ??= _SectionNavigator(
          key: slot.key,
          routes: slot.routes,
          onLeaveRoot: _leaveRoot,
          rootBuilder: (_) => _SectionRoot(id: section.id, replacement: slot.root),
        ),
      ),
    );
  }
}

class _SectionScope extends InheritedWidget {
  final List<AdminSection> sections;

  const _SectionScope({required this.sections, required super.child});

  @override
  bool updateShouldNotify(_SectionScope oldWidget) => true;
}

// Navigator 只建立一次，第一頁的 builder 不會再執行；改由 InheritedWidget 取得最新的分區設定，待處理數等資料更新時才會重建
class _SectionRoot extends StatelessWidget {
  final String id;
  final Widget? replacement;

  const _SectionRoot({required this.id, this.replacement});

  @override
  Widget build(BuildContext context) {
    final sections = context.dependOnInheritedWidgetOfExactType<_SectionScope>()!.sections;
    if (replacement != null) return replacement!;
    return sections.firstWhere((s) => s.id == id).builder(context);
  }
}

class _SectionRoutes extends NavigatorObserver {
  final List<Route<dynamic>> routes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) routes.clear();
    routes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute == null) return;
    final index = oldRoute == null ? -1 : routes.indexOf(oldRoute);
    if (index >= 0) {
      routes[index] = newRoute;
    } else {
      routes.add(newRoute);
    }
  }
}

class _SectionNavigator extends Navigator {
  final _SectionRoutes routes;
  final VoidCallback onLeaveRoot;

  _SectionNavigator({super.key, required this.routes, required this.onLeaveRoot, required WidgetBuilder rootBuilder})
    : super(
        observers: [routes],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(settings: settings, builder: rootBuilder),
      );

  @override
  NavigatorState createState() => _SectionNavigatorState();
}

// 分區的第一頁被 pop 或取代會留下空白分區，改為回到後台首頁；清空堆疊（登出）交給最上層 Navigator。
class _SectionNavigatorState extends NavigatorState {
  _SectionNavigator get _section => widget as _SectionNavigator;

  Future<bool> systemBack() => super.maybePop();

  @override
  Future<T?> pushAndRemoveUntil<T extends Object?>(Route<T> newRoute, RoutePredicate predicate) {
    if (_section.routes.routes.any(predicate)) return super.pushAndRemoveUntil<T>(newRoute, predicate);
    return Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<T>(newRoute, predicate);
  }

  @override
  Future<T?> pushReplacement<T extends Object?, TO extends Object?>(Route<T> newRoute, {TO? result}) {
    if (!canPop()) return push<T>(newRoute);
    return super.pushReplacement<T, TO>(newRoute, result: result);
  }

  @override
  void pop<T extends Object?>([T? result]) {
    if (!canPop()) {
      _section.onLeaveRoot();
      return;
    }
    super.pop<T>(result);
  }

  @override
  Future<bool> maybePop<T extends Object?>([T? result]) async {
    if (canPop()) return super.maybePop<T>(result);
    if (await super.maybePop<T>(result)) return true;
    if (mounted) _section.onLeaveRoot();
    return true;
  }

  @override
  void popUntil(RoutePredicate predicate) => super.popUntil((route) => route.isFirst || predicate(route));

  @override
  void popUntilWithResult<T extends Object?>(RoutePredicate predicate, T? result) =>
      super.popUntilWithResult<T>((route) => route.isFirst || predicate(route), result);
}

class AdminSideNav extends StatelessWidget {
  final AdminSection home;
  final List<AdminSectionGroup> groups;
  final String selectedId;
  final bool extended;
  final ValueChanged<String> onSelect;
  final VoidCallback? onExit;
  final VoidCallback? onToggle;

  const AdminSideNav({
    super.key,
    required this.home,
    required this.groups,
    required this.selectedId,
    required this.extended,
    required this.onSelect,
    this.onExit,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.standard,
      width: (extended ? AdminWorkspace.extendedWidth : AdminWorkspace.railWidth) + padding.left,
      decoration: BoxDecoration(
        color: c.card,
        border: Border(right: BorderSide(color: c.divider)),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: TabletToolbar.overlayStyle(c),
        child: extended ? _buildExtended(context, c, padding) : _buildRail(context, c, padding),
      ),
    );
  }

  Widget _buildExtended(BuildContext context, AppColors c, EdgeInsets padding) {
    Widget item(AdminSection section) =>
        _SideNavItem(section: section, selected: section.id == selectedId, onTap: () => onSelect(section.id));

    return Padding(
      padding: EdgeInsets.only(left: padding.left),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: padding.top + 6),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 6),
                if (onExit != null) Expanded(child: _ExitButton(onTap: onExit!)) else const Spacer(),
                if (onToggle != null)
                  IconButton(
                    icon: Icon(Icons.menu_open_rounded, color: c.textSecondary),
                    tooltip: S.hideSidebar,
                    onPressed: onToggle,
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined, size: 24, color: c.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.admin,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(12, 0, 12, padding.bottom + 16),
              children: [
                item(home),
                for (final group in groups) ...[_SectionLabel(group.title), for (final section in group.sections) item(section)],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRail(BuildContext context, AppColors c, EdgeInsets padding) {
    Widget item(AdminSection section) => _RailItem(section: section, selected: section.id == selectedId, onTap: () => onSelect(section.id));

    return Padding(
      padding: EdgeInsets.fromLTRB(padding.left, padding.top + 8, 0, 0),
      child: Column(
        children: [
          if (onToggle != null)
            IconButton(
              icon: Icon(Icons.menu_rounded, color: c.textSecondary),
              tooltip: S.showSidebar,
              onPressed: onToggle,
            ),
          if (onExit != null)
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: c.accent),
              tooltip: '${S.actionBack} $kAppName',
              onPressed: onExit,
            ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: padding.bottom + 16),
              child: Column(
                children: [
                  item(home),
                  for (final group in groups) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: SizedBox(width: 32, child: Divider(height: 1, thickness: 1, color: c.divider)),
                    ),
                    for (final section in group.sections) item(section),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExitButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ExitButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: S.actionBack,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: c.accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    kAppName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 0.3),
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  final AdminSection section;
  final bool selected;
  final VoidCallback onTap;

  const _SideNavItem({required this.section, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: section.title,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: selected ? c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(section.icon, size: 21, color: selected ? c.accent : c.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      section.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? c.accent : c.textPrimary,
                      ),
                    ),
                  ),
                  if (section.badge > 0) UnconstrainedBox(child: CountBadge(count: section.badge)),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final AdminSection section;
  final bool selected;
  final VoidCallback onTap;

  const _RailItem({required this.section, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: section.title,
      excludeSemantics: true,
      child: Tooltip(
        message: section.title,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: Motion.base,
                curve: Motion.standard,
                width: 52,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(section.icon, size: 22, color: selected ? c.accent : c.textSecondary),
                      if (section.badge > 0) Positioned(right: -10, top: -6, child: CountBadge(count: section.badge)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
