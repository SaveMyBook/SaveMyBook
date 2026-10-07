import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../utils/app_colors.dart';

/// 主從版面：寬度足夠（平板橫向）時左側列表、右側內容；寬度不足時只顯示列表，開啟內容改為推入新頁面。
///
/// 列表內以 [MasterDetail.open] 開啟內容，以 [MasterDetail.selectedId] 標示目前選取的項目。
/// 右側內容有自己的 Navigator：內容頁再推入的頁面留在右側；內容頁自行 pop 時右側回到提示畫面。
class MasterDetail extends StatefulWidget {
  final Widget master;
  final double masterWidth;
  final double minSplitWidth;
  final IconData placeholderIcon;
  final String? placeholderText;

  const MasterDetail({
    super.key,
    required this.master,
    this.masterWidth = 380,
    this.minSplitWidth = 840,
    this.placeholderIcon = Icons.touch_app_outlined,
    this.placeholderText,
  });

  static _MasterDetailState? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MasterDetailScope>()?.state;

  /// 目前是否左右並排顯示。
  static bool isSplit(BuildContext context) => _of(context)?._split ?? false;

  /// 右側目前顯示的項目（以 [open] 傳入的 id 比對）；未並排或未選取時為 null。
  static Object? selectedId(BuildContext context) {
    final state = _of(context);
    return state != null && state._split ? state._current?.id : null;
  }

  /// 開啟內容：並排時顯示在右側（同一個 id 已開啟則不重新建立），否則推入新頁面。
  /// 回傳值與 Navigator.push 相同：內容頁 pop 時的結果；並排時被其他項目取代則為 null。
  static Future<T?> open<T>(BuildContext context, Widget page, {Object? id}) {
    final state = context.getInheritedWidgetOfExactType<_MasterDetailScope>()?.state;
    if (state == null || !state._split) {
      return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
    }
    return state._show<T>(page, id);
  }

  /// 關閉右側內容（例如項目已刪除）。
  static void close(BuildContext context) => _of(context)?._clear();

  @override
  State<MasterDetail> createState() => _MasterDetailState();
}

class _Detail {
  final Object? id;
  final Widget page;
  final Completer<Object?> done = Completer<Object?>();
  final Key key = UniqueKey();

  _Detail(this.id, this.page);

  void finish([Object? result]) {
    if (!done.isCompleted) done.complete(result);
  }
}

class _MasterDetailState extends State<MasterDetail> {
  _Detail? _current;
  bool _split = false;

  Future<T?> _show<T>(Widget page, Object? id) {
    final current = _current;
    if (current != null && id != null && current.id == id) {
      return current.done.future.then((v) => v as T?);
    }
    current?.finish();
    final next = _Detail(id, page);
    setState(() => _current = next);
    return next.done.future.then((v) => v as T?);
  }

  void _clear() {
    final current = _current;
    if (current == null) return;
    current.finish();
    setState(() => _current = null);
  }

  @override
  void dispose() {
    _current?.finish();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= widget.minSplitWidth;
        // 由並排改為單欄（旋轉或分割畫面）時右側內容無處顯示，結束之
        if (_split && !split && _current != null) {
          final current = _current!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _current == current) _clear();
          });
        }
        _split = split;
        final scope = _MasterDetailScope(state: this, selected: _current?.id, split: split, child: widget.master);
        if (!split) return scope;
        final c = AppColors.of(context);
        return Row(
          children: [
            SizedBox(width: widget.masterWidth, child: scope),
            VerticalDivider(width: 1, thickness: 1, color: c.divider),
            Expanded(
              child: _current == null
                  ? _Placeholder(icon: widget.placeholderIcon, text: widget.placeholderText ?? S.selectItemToView)
                  : _DetailPane(key: _current!.key, detail: _current!, onRemoved: _onRemoved),
            ),
          ],
        );
      },
    );
  }

  void _onRemoved(_Detail detail, Object? result) {
    detail.finish(result);
    if (_current == detail && mounted) setState(() => _current = null);
  }
}

class _MasterDetailScope extends InheritedWidget {
  final _MasterDetailState state;
  final Object? selected;
  final bool split;

  const _MasterDetailScope({required this.state, required this.selected, required this.split, required super.child});

  @override
  bool updateShouldNotify(_MasterDetailScope oldWidget) => selected != oldWidget.selected || split != oldWidget.split;
}

class _DetailPane extends StatefulWidget {
  final _Detail detail;
  final void Function(_Detail detail, Object? result) onRemoved;

  const _DetailPane({super.key, required this.detail, required this.onRemoved});

  @override
  State<_DetailPane> createState() => _DetailPaneState();
}

class _DetailPaneState extends State<_DetailPane> {
  final _navigator = GlobalKey<NavigatorState>();
  late final _page = _RootPage(child: widget.detail.page, onPopped: (result) => widget.onRemoved(widget.detail, result));

  @override
  Widget build(BuildContext context) {
    // 右側的根頁面無法返回：頁首依 Navigator.canPop 自動隱藏返回鍵；系統返回鍵先返回右側的上一頁
    return NavigatorPopHandler<Object?>(
      onPopWithResult: (_) => _navigator.currentState?.maybePop(),
      child: HeroControllerScope.none(
        child: _PaneNavigator(
          key: _navigator,
          pages: [_page],
          onDidRemovePage: (_) {},
        ),
      ),
    );
  }
}

class _PaneNavigator extends Navigator {
  const _PaneNavigator({super.key, super.pages, super.onDidRemovePage});

  @override
  NavigatorState createState() => _PaneNavigatorState();
}

// 右側內容清空堆疊（登出、回首頁）時交給外層 Navigator，否則登入頁或首頁會出現在右側
class _PaneNavigatorState extends NavigatorState {
  @override
  Future<T?> pushAndRemoveUntil<T extends Object?>(Route<T> newRoute, RoutePredicate predicate) {
    final outer = context.findAncestorStateOfType<NavigatorState>();
    if (outer == null) return super.pushAndRemoveUntil<T>(newRoute, predicate);
    return outer.pushAndRemoveUntil<T>(newRoute, predicate);
  }
}

/// 右側的根頁面：記下 route 以取得內容頁 pop 時的結果。
class _RootPage extends Page<Object?> {
  final Widget child;
  final void Function(Object? result) onPopped;

  const _RootPage({required this.child, required this.onPopped}) : super(key: const ValueKey('detail-root'));

  @override
  Route<Object?> createRoute(BuildContext context) {
    final route = MaterialPageRoute<Object?>(settings: this, builder: (_) => child);
    route.popped.then(onPopped);
    return route;
  }
}

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Placeholder({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // 使用的頁面不一定在 Scaffold 內，沒有 Material 時文字會出現除錯用的黃色底線
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: c.textHint),
            const SizedBox(height: 12),
            Text(text, style: TextStyle(fontSize: 14, color: c.textSecondary)),
          ],
        ),
      ),
    );
  }
}
