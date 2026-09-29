import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/app_colors.dart';

class CabinetMatchCodeField extends StatefulWidget {
  static const length = 2;

  final TextEditingController controller;
  final bool enabled;
  final bool autofocus;
  final VoidCallback? onSubmitted;
  final String? semanticLabel;

  const CabinetMatchCodeField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
    this.semanticLabel,
  });

  @override
  State<CabinetMatchCodeField> createState() => _CabinetMatchCodeFieldState();
}

class _CabinetMatchCodeFieldState extends State<CabinetMatchCodeField> {
  static const _boxWidth = 56.0;
  static const _boxHeight = 64.0;
  static const _gap = 12.0;

  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant CabinetMatchCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Widget _box(AppColors c, String text, int index) {
    final active =
        widget.enabled &&
        _focus.hasFocus &&
        (index == text.length || (index == CabinetMatchCodeField.length - 1 && text.length == CabinetMatchCodeField.length));
    return Container(
      width: _boxWidth,
      height: _boxHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? c.accent : c.border, width: 1.4),
      ),
      child: Text(
        index < text.length ? text[index] : '',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: widget.enabled ? c.textPrimary : c.textHint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = widget.controller.text;
    return SizedBox(
      width: _boxWidth * CabinetMatchCodeField.length + _gap * (CabinetMatchCodeField.length - 1),
      height: _boxHeight,
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < CabinetMatchCodeField.length; i++) ...[if (i > 0) const SizedBox(width: _gap), _box(c, text, i)],
            ],
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              alwaysIncludeSemantics: true,
              child: Semantics(
                label: widget.semanticLabel,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  readOnly: !widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(CabinetMatchCodeField.length)],
                  autocorrect: false,
                  enableSuggestions: false,
                  enableInteractiveSelection: false,
                  showCursor: false,
                  onSubmitted: (_) => widget.onSubmitted?.call(),
                  decoration: const InputDecoration(border: InputBorder.none, counterText: '', isCollapsed: true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
