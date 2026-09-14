import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_colors.dart';
import '../utils/motion.dart';
import 'animations.dart';
import '../i18n/strings.dart';

const int kPinLength = 6;

class PinDots extends StatelessWidget {
  final int filled;
  final bool error;
  final int length;

  const PinDots({super.key, required this.filled, this.error = false, this.length = kPinLength});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tint = error ? c.danger : c.accent;
    return Semantics(
      label: S.p0P1DigitsEntered(filled, length),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(length, (i) {
          final on = i < filled;
          return AnimatedScale(
            scale: on ? 1.0 : 0.88,
            duration: Motion.base,
            curve: Motion.pop,
            child: AnimatedContainer(
              duration: Motion.micro,
              curve: Motion.emphasized,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? tint : Colors.transparent,
                border: Border.all(color: on ? tint : c.iconInactive, width: 2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class ShakeOnError extends StatefulWidget {
  final Widget child;
  final int trigger;

  const ShakeOnError({super.key, required this.child, required this.trigger});

  @override
  State<ShakeOnError> createState() => _ShakeOnErrorState();
}

class _ShakeOnErrorState extends State<ShakeOnError> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(covariant ShakeOnError oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final t = _controller.value;
        final dx = math.sin(t * math.pi * 6) * 12 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

class NumberPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final Widget? leading;
  final bool enabled;
  final VoidCallback? onClear;

  const NumberPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.leading,
    this.enabled = true,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    Widget key(Widget child, VoidCallback? onTap, {String? semantic, VoidCallback? onLongPress}) {
      return Expanded(
        child: Semantics(
          button: true,
          label: semantic,
          child: PressableScale(
            scale: 0.9,
            onTap: enabled ? onTap : null,
            onLongPress: enabled ? onLongPress : null,
            child: SizedBox(height: 60, child: Center(child: child)),
          ),
        ),
      );
    }

    Widget digit(String d) => key(
          Text(d, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500, color: c.textPrimary)),
          () {
            HapticFeedback.selectionClick();
            onDigit(d);
          },
          semantic: d,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: row.map(digit).toList()),
        Row(
          children: [
            key(leading ?? const SizedBox.shrink(), null),
            digit('0'),
            key(
              Icon(Icons.backspace_outlined, color: c.textSecondary),
              () {
                HapticFeedback.selectionClick();
                onDelete();
              },
              semantic: 'delete',
              onLongPress: onClear == null
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      onClear!();
                    },
            ),
          ],
        ),
      ],
    );
  }
}

class PinEntryPanel extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? header;
  final Future<String?> Function(String pin) onCompleted;
  final List<Widget> footer;
  final Widget? padLeading;
  final String? initialError;

  const PinEntryPanel({
    super.key,
    required this.title,
    this.subtitle,
    this.header,
    required this.onCompleted,
    this.footer = const [],
    this.padLeading,
    this.initialError,
  });

  @override
  State<PinEntryPanel> createState() => PinEntryPanelState();
}

class PinEntryPanelState extends State<PinEntryPanel> {
  String _pin = '';
  String? _error;
  int _shake = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final error = widget.initialError;
    if (error == null) return;
    _error = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _shake++);
    });
  }

  void reset({String? error}) {
    if (!mounted) return;
    setState(() {
      _pin = '';
      _error = error;
      if (error != null) _shake++;
    });
  }

  Future<void> _add(String d) async {
    if (_busy || _pin.length >= kPinLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length < kPinLength) return;

    setState(() => _busy = true);
    final error = await widget.onCompleted(_pin);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      HapticFeedback.heavyImpact();
      reset(error: error);
    }
  }

  void _delete() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _clear() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = '');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?widget.header,
        Text(widget.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(widget.subtitle!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.textSecondary)),
        ],
        const SizedBox(height: 24),
        ShakeOnError(trigger: _shake, child: PinDots(filled: _pin.length, error: _error != null)),
        SizedBox(
          height: 44,
          child: Center(
            child: AnimatedSwitcher(
              duration: Motion.micro,
              child: _busy
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
                  : Text(
                      _error ?? '',
                      key: ValueKey(_error),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, height: 1.3, color: c.danger),
                    ),
            ),
          ),
        ),
        NumberPad(onDigit: _add, onDelete: _delete, onClear: _clear, leading: widget.padLeading, enabled: !_busy),
        ...widget.footer,
      ],
    );
  }
}
