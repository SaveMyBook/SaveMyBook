import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../i18n/strings.dart';
import '../utils/app_colors.dart';
import '../utils/motion.dart';

class AppSelectOption<T> {
  final T value;
  final String label;
  final Widget? labelWidget;
  final String? subtitle;
  final String? caption;
  final IconData? icon;
  final Color? iconColor;
  final String? trailing;
  final String? badge;
  final Color? badgeColor;
  final bool enabled;
  final String? disabledReason;

  const AppSelectOption({
    required this.value,
    required this.label,
    this.labelWidget,
    this.subtitle,
    this.caption,
    this.icon,
    this.iconColor,
    this.trailing,
    this.badge,
    this.badgeColor,
    this.enabled = true,
    this.disabledReason,
  });

  bool matches(String query) {
    final q = query.toLowerCase();
    return [label, subtitle, caption, trailing].any((s) => s != null && s.toLowerCase().contains(q));
  }
}

class _Picked<T> {
  final T value;
  const _Picked(this.value);
}

Future<T?> showAppPicker<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<AppSelectOption<T>> options,
  T? selected,
  bool? searchable,
  String? searchHint,
  String? emptyText,
  Widget? header,
}) async {
  final picked = await _openPicker<T>(
    context,
    title: title,
    subtitle: subtitle,
    options: options,
    selected: selected,
    hasSelection: selected != null,
    searchable: searchable,
    searchHint: searchHint,
    emptyText: emptyText,
    header: header,
  );
  return picked?.value;
}

Future<_Picked<T>?> _openPicker<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<AppSelectOption<T>> options,
  required T? selected,
  required bool hasSelection,
  bool? searchable,
  String? searchHint,
  String? emptyText,
  Widget? header,
}) {
  final c = AppColors.of(context);
  FocusManager.instance.primaryFocus?.unfocus();

  return showModalBottomSheet<_Picked<T>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.sheetBg,
    barrierColor: c.scrim,
    sheetAnimationStyle: const AnimationStyle(duration: Motion.enter, reverseDuration: Motion.base),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    clipBehavior: Clip.antiAlias,
    builder: (_) => _AppPickerSheet<T>(
      title: title,
      subtitle: subtitle,
      options: options,
      selected: selected,
      hasSelection: hasSelection,
      searchable: searchable ?? options.length > 8,
      searchHint: searchHint,
      emptyText: emptyText,
      header: header,
    ),
  );
}

class _AppPickerSheet<T> extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<AppSelectOption<T>> options;
  final T? selected;
  final bool hasSelection;
  final bool searchable;
  final String? searchHint;
  final String? emptyText;
  final Widget? header;

  const _AppPickerSheet({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.hasSelection,
    required this.searchable,
    required this.searchHint,
    required this.emptyText,
    required this.header,
  });

  @override
  State<_AppPickerSheet<T>> createState() => _AppPickerSheetState<T>();
}

class _AppPickerSheetState<T> extends State<_AppPickerSheet<T>> {
  final _search = TextEditingController();
  final _selectedKey = GlobalKey();
  late bool _hasSelection = widget.hasSelection;
  late T? _selected = widget.selected;
  String _query = '';
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _selectedKey.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(ctx, alignment: 0.4, duration: Motion.enter, curve: Motion.enterCurve);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _isSelected(AppSelectOption<T> option) => _hasSelection && option.value == _selected;

  Future<void> _choose(AppSelectOption<T> option) async {
    if (_closing) return;
    if (!option.enabled) {
      HapticFeedback.lightImpact();
      return;
    }
    _closing = true;
    HapticFeedback.selectionClick();
    setState(() {
      _selected = option.value;
      _hasSelection = true;
    });
    await Future<void>.delayed(Motion.micro);
    if (mounted) Navigator.of(context).pop(_Picked<T>(option.value));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final media = MediaQuery.of(context);
    final visible = _query.isEmpty ? widget.options : widget.options.where((o) => o.matches(_query)).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: c.iconInactive.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded, color: c.iconInactive, size: 22),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            ?widget.header,
            if (widget.searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  style: TextStyle(color: c.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.searchHint ?? S.actionSearch,
                    hintStyle: TextStyle(color: c.textHint, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: c.iconInactive, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close_rounded, size: 18, color: c.iconInactive),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                    filled: true,
                    fillColor: c.inputFill,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.accent, width: 1.4),
                    ),
                  ),
                ),
              ),
            Flexible(
              child: AnimatedSwitcher(
                duration: Motion.micro,
                child: visible.isEmpty
                    ? Padding(
                        key: const ValueKey('empty'),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 40, color: c.iconInactive),
                            const SizedBox(height: 10),
                            Text(
                              widget.emptyText ?? S.noMatchingOptions,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: c.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        key: const ValueKey('list'),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(10, 2, 10, 12 + media.padding.bottom),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final option in visible)
                              _PickerTile<T>(
                                key: _isSelected(option) ? _selectedKey : null,
                                option: option,
                                selected: _isSelected(option),
                                onTap: () => _choose(option),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile<T> extends StatelessWidget {
  final AppSelectOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  const _PickerTile({super.key, required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = option.enabled;
    final tint = option.iconColor ?? (selected ? c.accent : c.textSecondary);
    final radius = BorderRadius.circular(14);

    return Semantics(
      selected: selected,
      enabled: enabled,
      button: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: AnimatedContainer(
              duration: Motion.base,
              curve: Motion.standard,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: selected ? c.accent.withValues(alpha: c.isDark ? 0.16 : 0.09) : Colors.transparent,
                borderRadius: radius,
              ),
              child: Opacity(
                opacity: enabled ? 1 : 0.5,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (option.icon != null) ...[
                      AnimatedContainer(
                        duration: Motion.base,
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: selected ? 0.16 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(option.icon, size: 19, color: tint),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(child: _buildText(c, enabled)),
                    if (option.trailing != null) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 96),
                        child: Text(
                          option.trailing!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? c.accent : c.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 22,
                      child: AnimatedSwitcher(
                        duration: Motion.base,
                        switchInCurve: Motion.pop,
                        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                        child: selected
                            ? Icon(Icons.check_circle_rounded, key: const ValueKey('on'), size: 22, color: c.accent)
                            : const SizedBox(key: ValueKey('off'), width: 22, height: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildText(AppColors c, bool enabled) {
    final badgeColor = option.badgeColor ?? c.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: option.labelWidget ??
                  Text(
                    option.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected ? c.accent : c.textPrimary,
                    ),
                  ),
            ),
            if (option.badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  option.badge!,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
            ],
          ],
        ),
        if (option.subtitle != null && option.subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            option.subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 1.35, color: c.textSecondary),
          ),
        ],
        if (option.caption != null && option.caption!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            option.caption!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, height: 1.35, color: c.textHint),
          ),
        ],
        if (!enabled && option.disabledReason != null) ...[
          const SizedBox(height: 3),
          Text(
            option.disabledReason!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.danger),
          ),
        ],
      ],
    );
  }
}

class AppSelect<T> extends StatefulWidget {
  final T? value;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T>? onChanged;
  final String? hint;
  final String? title;
  final String? sheetSubtitle;
  final String? errorText;
  final bool loading;
  final IconData? leadingIcon;
  final bool? searchable;
  final String? emptyText;
  final Widget? sheetHeader;

  const AppSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
    this.title,
    this.sheetSubtitle,
    this.errorText,
    this.loading = false,
    this.leadingIcon,
    this.searchable,
    this.emptyText,
    this.sheetHeader,
  });

  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>> {
  bool _open = false;

  AppSelectOption<T>? get _current {
    for (final option in widget.options) {
      if (option.value == widget.value) return option;
    }
    return null;
  }

  bool get _enabled => widget.onChanged != null && !widget.loading;

  Future<void> _openSheet() async {
    if (!_enabled || _open) return;
    final onChanged = widget.onChanged!;
    setState(() => _open = true);
    final picked = await _openPicker<T>(
      context,
      title: widget.title ?? widget.hint ?? S.actionSelect,
      subtitle: widget.sheetSubtitle,
      options: widget.options,
      selected: widget.value,
      hasSelection: _current != null,
      searchable: widget.searchable,
      emptyText: widget.emptyText,
      header: widget.sheetHeader,
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (picked != null && picked.value != widget.value) onChanged(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final current = _current;
    final hasError = widget.errorText != null;
    final borderColor = hasError ? c.danger : (_open ? c.accent : Colors.transparent);

    final text = widget.loading
        ? (widget.hint ?? S.loading)
        : current?.label ?? widget.hint ?? S.actionSelect;
    final textColor = !_enabled
        ? c.textHint
        : current == null
            ? c.textHint
            : c.textPrimary;
    final icon = current?.icon ?? widget.leadingIcon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: _enabled,
          label: text,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openSheet,
            child: AnimatedContainer(
              duration: Motion.base,
              curve: Motion.standard,
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
              decoration: BoxDecoration(
                color: c.inputFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: 1.4),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 17, color: _enabled && current != null ? (current.iconColor ?? c.accent) : c.iconInactive),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Motion.micro,
                      layoutBuilder: (currentChild, previous) => Stack(
                        alignment: Alignment.centerLeft,
                        children: [...previous, ?currentChild],
                      ),
                      child: current?.labelWidget != null && !widget.loading
                          ? KeyedSubtree(key: ValueKey(current!.value), child: current.labelWidget!)
                          : Text(
                              text,
                              key: ValueKey(text),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, color: textColor),
                            ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (widget.loading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.iconInactive),
                    )
                  else
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: Motion.base,
                      curve: Motion.standard,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: _open ? c.accent : c.iconInactive,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.standard,
          alignment: Alignment.topLeft,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 5, left: 4),
                  child: Text(
                    widget.errorText!,
                    style: TextStyle(fontSize: 12, color: c.danger),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class AppSelectChip<T> extends StatefulWidget {
  final T value;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final String title;
  final IconData icon;
  final bool highlighted;
  final bool iconOnly;

  const AppSelectChip({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.title,
    this.icon = Icons.filter_list_rounded,
    this.highlighted = false,
    this.iconOnly = false,
  });

  @override
  State<AppSelectChip<T>> createState() => _AppSelectChipState<T>();
}

class _AppSelectChipState<T> extends State<AppSelectChip<T>> {
  bool _open = false;

  Future<void> _openSheet() async {
    if (_open) return;
    setState(() => _open = true);
    final picked = await _openPicker<T>(
      context,
      title: widget.title,
      options: widget.options,
      selected: widget.value,
      hasSelection: true,
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (picked != null && picked.value != widget.value) widget.onChanged(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    String? label;
    for (final option in widget.options) {
      if (option.value == widget.value) label = option.label;
    }
    final active = widget.highlighted;
    final fg = active ? Colors.white : c.textPrimary;

    return Semantics(
      button: true,
      label: '${widget.title} ${label ?? ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openSheet,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.standard,
          height: 44,
          constraints: const BoxConstraints(minWidth: 44, maxWidth: 160),
          padding: EdgeInsets.symmetric(horizontal: widget.iconOnly ? 0 : 12),
          decoration: BoxDecoration(
            color: active ? c.accent : c.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _open && !active ? c.accent : Colors.transparent, width: 1.4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 20, color: active ? Colors.white : c.textPrimary),
              if (!widget.iconOnly && label != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: Motion.base,
                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
