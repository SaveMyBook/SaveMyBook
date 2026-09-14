import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../i18n/strings.dart';
import '../../services/voice_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import 'chat_format.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String? disabledHint;
  final Widget? top;
  final bool quickRepliesOpen;
  final ValueChanged<String> onSend;
  final VoidCallback onAttach;
  final VoidCallback onToggleQuickReplies;
  final ValueChanged<VoiceClip> onVoice;
  final ValueChanged<VoiceStartResult> onVoiceUnavailable;
  final VoidCallback onVoiceTooShort;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onAttach,
    required this.onToggleQuickReplies,
    required this.onVoice,
    required this.onVoiceUnavailable,
    required this.onVoiceTooShort,
    this.enabled = true,
    this.disabledHint,
    this.top,
    this.quickRepliesOpen = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final VoiceRecorder _recorder = VoiceRecorder();
  final List<double> _samples = [];
  Timer? _ticker;
  Offset _origin = Offset.zero;
  bool _pressing = false;
  bool _recording = false;
  bool _cancelZone = false;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _beginRecord(Offset position) async {
    if (!widget.enabled || _pressing) return;
    _pressing = true;
    _origin = position;
    _cancelZone = false;
    HapticFeedback.mediumImpact();

    final result = await _recorder.start();
    if (!mounted) return;

    if (result != VoiceStartResult.started) {
      _pressing = false;
      widget.onVoiceUnavailable(result);
      return;
    }
    if (!_pressing) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _recording = true;
      _elapsed = Duration.zero;
      _samples.clear();
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 90), (_) => _tick());
  }

  void _tick() {
    if (!mounted || !_recording) return;
    final elapsed = _recorder.elapsed;
    if (elapsed >= VoiceRecorder.maxDuration) {
      HapticFeedback.heavyImpact();
      _endRecord(send: true);
      return;
    }
    setState(() {
      _elapsed = elapsed;
      _samples.add(_recorder.level.value);
      if (_samples.length > 60) _samples.removeAt(0);
    });
  }

  void _moveRecord(Offset position) {
    if (!_pressing) return;
    final delta = position - _origin;
    final cancel = delta.dx < -80 || delta.dy < -70;
    if (cancel != _cancelZone) {
      HapticFeedback.selectionClick();
      setState(() => _cancelZone = cancel);
    }
  }

  Future<void> _endRecord({required bool send}) async {
    if (!_pressing) return;
    _pressing = false;
    _ticker?.cancel();
    _ticker = null;
    final wasRecording = _recording;
    final discard = !send || _cancelZone;
    if (mounted) {
      setState(() {
        _recording = false;
        _cancelZone = false;
      });
    }

    if (discard) {
      await _recorder.cancel();
      if (wasRecording) HapticFeedback.lightImpact();
      return;
    }

    final clip = await _recorder.stop();
    if (!mounted) {
      VoiceRecorder.deleteFile(clip?.path);
      return;
    }
    if (clip == null) {
      widget.onVoiceTooShort();
      return;
    }
    HapticFeedback.mediumImpact();
    widget.onVoice(clip);
  }

  void _submit() {
    if (!widget.enabled) return;
    final text = widget.controller.text;
    if (text.trim().isEmpty) return;
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        boxShadow: [
          BoxShadow(color: c.shadow.withValues(alpha: c.isDark ? 0.3 : 0.06), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.standard,
            alignment: Alignment.bottomCenter,
            child: widget.top ?? const SizedBox(width: double.infinity),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, bottom + 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.micro,
                    switchInCurve: Motion.enterCurve,
                    switchOutCurve: Motion.exitCurve,
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: _recording ? _buildRecordingPanel(c) : _buildComposer(c),
                  ),
                ),
                const SizedBox(width: 8),
                _buildTrailingButton(c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(AppColors c) {
    return Row(
      key: const ValueKey('composer'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _CircleIconButton(
          icon: Icons.add_rounded,
          color: widget.enabled ? c.accent : c.iconInactive,
          background: c.inputFill,
          onTap: widget.enabled ? widget.onAttach : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              enabled: widget.enabled,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              inputFormatters: [LengthLimitingTextInputFormatter(2000)],
              style: TextStyle(color: c.textPrimary, fontSize: 15, height: 1.35),
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.enabled ? S.writeMessage : (widget.disabledHint ?? S.writeMessage),
                hintMaxLines: 1,
                hintStyle: TextStyle(color: c.textHint, fontSize: 14.5, overflow: TextOverflow.ellipsis),
                filled: true,
                fillColor: c.inputFill,
                contentPadding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 44),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (_, value, _) => AnimatedSwitcher(
                    duration: Motion.micro,
                    child: value.text.isEmpty && widget.enabled
                        ? IconButton(
                            key: const ValueKey('quick'),
                            onPressed: widget.onToggleQuickReplies,
                            icon: Icon(
                              widget.quickRepliesOpen ? Icons.keyboard_arrow_down_rounded : Icons.bolt_rounded,
                              size: 22,
                              color: widget.quickRepliesOpen ? c.accent : c.iconInactive,
                            ),
                          )
                        : const SizedBox(key: ValueKey('none'), width: 12),
                  ),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingPanel(AppColors c) {
    final tint = _cancelZone ? c.danger : c.accent;
    final hint = _cancelZone ? S.releaseCancel : S.slideCancel;

    return Container(
      key: const ValueKey('recording'),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _cancelZone ? c.danger.withValues(alpha: 0.12) : c.inputFill,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _BlinkingDot(color: c.danger),
          const SizedBox(width: 8),
          Text(
            chatDuration(_elapsed.inSeconds),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 26,
              child: CustomPaint(painter: _LiveWavePainter(samples: List.of(_samples), color: tint)),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _cancelZone ? c.danger : c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailingButton(AppColors c) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        final showSend = hasText && !_recording;
        final active = widget.enabled;
        final bg = !active
            ? c.inputFill
            : _cancelZone
                ? c.danger
                : chatMineBubble(c);

        final button = AnimatedScale(
          scale: _recording ? 1.28 : 1,
          duration: Motion.base,
          curve: Motion.pop,
          child: AnimatedContainer(
            duration: Motion.micro,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: _recording
                  ? [
                      BoxShadow(
                        color: bg.withValues(alpha: 0.35),
                        blurRadius: 8 + 18 * _recorder.level.value,
                        spreadRadius: 2 + 8 * _recorder.level.value,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedSwitcher(
              duration: Motion.micro,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(parent: animation, curve: Motion.pop),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                showSend ? Icons.send_rounded : (_cancelZone ? Icons.delete_outline_rounded : Icons.mic_rounded),
                key: ValueKey(showSend ? 'send' : (_cancelZone ? 'trash' : 'mic')),
                color: active ? Colors.white : c.iconInactive,
                size: showSend ? 20 : 22,
              ),
            ),
          ),
        );

        if (showSend) {
          return GestureDetector(onTap: _submit, child: button);
        }

        return Listener(
          onPointerDown: (e) => _beginRecord(e.position),
          onPointerMove: (e) => _moveRecord(e.position),
          onPointerUp: (_) => _endRecord(send: true),
          onPointerCancel: (_) => _endRecord(send: false),
          child: button,
        );
      },
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  const _CircleIconButton({required this.icon, required this.color, required this.background, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, color: color, size: 24)),
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final Color color;

  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.25, end: 1.0).animate(_controller),
      child: Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
}

class _LiveWavePainter extends CustomPainter {
  final List<double> samples;
  final Color color;

  _LiveWavePainter({required this.samples, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const step = 4.5;
    final count = (size.width / step).floor();
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;
    final start = math.max(0, samples.length - count);
    final visible = samples.sublist(start);
    for (var i = 0; i < count; i++) {
      final sampleIndex = visible.length - count + i;
      final level = sampleIndex >= 0 ? visible[sampleIndex] : 0.0;
      final h = math.max(3.0, size.height * (0.15 + 0.85 * level));
      final x = i * step + step / 2;
      paint.color = sampleIndex >= 0 ? color : color.withValues(alpha: 0.25);
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWavePainter old) => true;
}
