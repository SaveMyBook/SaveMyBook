import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../i18n/strings.dart';
import '../../../services/voice_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../mentions/chat_mention_controller.dart';
import '../mentions/chat_mention_panel.dart';
import 'chat_format.dart';
import 'voice_recorder_panel.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String? disabledHint;
  final Widget? top;
  final ChatMentionController? mentions;
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
    this.mentions,
    this.quickRepliesOpen = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> with WidgetsBindingObserver {
  static double _keyboardHeight = 0;

  final VoiceRecorder _recorder = VoiceRecorder();
  bool _voiceOpen = false;
  bool _voiceBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.focusNode.onKeyEvent = _onKey;
    widget.focusNode.addListener(_onFocusChanged);
  }

  // 硬體鍵盤按 Enter 直接送出、Shift+Enter 換行；輸入法組字中的 Enter 用來確認選字，不可攔截。
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final mentions = widget.mentions;
    if (mentions != null && mentions.showing && !widget.controller.value.composing.isValid) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        mentions.dismiss();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        mentions.select(mentions.candidates.first);
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey != LogicalKeyboardKey.enter && event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed || widget.controller.value.composing.isValid) {
      return KeyEventResult.ignored;
    }
    if (mentions != null && mentions.showing) {
      mentions.select(mentions.candidates.first);
      return KeyEventResult.handled;
    }
    _submit();
    return KeyEventResult.handled;
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      if (oldWidget.focusNode.onKeyEvent == _onKey) oldWidget.focusNode.onKeyEvent = null;
      widget.focusNode
        ..onKeyEvent = _onKey
        ..addListener(_onFocusChanged);
    }
    if (!widget.enabled && _voiceOpen) {
      _voiceOpen = false;
      _voiceBusy = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.focusNode.removeListener(_onFocusChanged);
    if (widget.focusNode.onKeyEvent == _onKey) widget.focusNode.onKeyEvent = null;
    _recorder.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final view = View.maybeOf(context);
    if (view == null) return;
    final inset = view.viewInsets.bottom / view.devicePixelRatio;
    if (inset > _keyboardHeight) _keyboardHeight = inset;
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus || !_voiceOpen) return;
    // 錄音或試聽中不讓鍵盤把面板收掉，否則錄到一半的內容會跟著被丟棄。
    if (_voiceBusy) {
      widget.focusNode.unfocus();
      return;
    }
    setState(() => _voiceOpen = false);
  }

  void _openVoice() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() => _voiceOpen = true);
  }

  void _closeVoice({bool focusInput = false}) {
    if (_voiceBusy) return;
    setState(() => _voiceOpen = false);
    if (focusInput) widget.focusNode.requestFocus();
  }

  double _panelHeight(BuildContext context, double bottom) {
    final screen = MediaQuery.sizeOf(context).height;
    final base = 256 + bottom;
    final preferred = _keyboardHeight > base ? math.min(_keyboardHeight, 360.0) : base;
    return math.min(preferred, math.max(base * 0.8, screen * 0.45));
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
    final voiceOpen = _voiceOpen && widget.enabled;

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
          if (widget.mentions != null) _buildMentionPanel(widget.mentions!),
          AnimatedPadding(
            duration: Motion.base,
            curve: Motion.standard,
            padding: EdgeInsets.fromLTRB(8, 8, 8, voiceOpen ? 8 : bottom + 8),
            child: IgnorePointer(
              ignoring: _voiceBusy,
              child: AnimatedOpacity(
                duration: Motion.micro,
                opacity: _voiceBusy ? 0.45 : 1,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _buildComposer(c)),
                    const SizedBox(width: 8),
                    _buildTrailingButton(c, voiceOpen),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.standard,
            alignment: Alignment.topCenter,
            child: voiceOpen
                ? DecoratedBox(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
                    child: VoiceRecorderPanel(
                      recorder: _recorder,
                      height: _panelHeight(context, bottom),
                      bottomInset: bottom,
                      onSend: widget.onVoice,
                      onUnavailable: widget.onVoiceUnavailable,
                      onBusyChanged: (busy) => setState(() => _voiceBusy = busy),
                      onClose: _closeVoice,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildMentionPanel(ChatMentionController mentions) {
    return ListenableBuilder(
      listenable: Listenable.merge([mentions, widget.focusNode]),
      builder: (context, _) {
        final visible = widget.enabled && mentions.showing && widget.focusNode.hasFocus && !_voiceOpen;
        return AnimatedSize(
          duration: Motion.micro,
          curve: Motion.standard,
          alignment: Alignment.bottomCenter,
          child: visible ? ChatMentionPanel(controller: mentions) : const SizedBox(width: double.infinity),
        );
      },
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
              inputFormatters: [LengthLimitingTextInputFormatter(2000), ?widget.mentions?.formatter],
              style: TextStyle(color: c.textPrimary, fontSize: 15, height: 1.35),
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.enabled ? S.writeMessage : (widget.disabledHint ?? S.writeMessage),
                hintMaxLines: 1,
                hintStyle: TextStyle(color: c.textHint, fontSize: 14.5, overflow: TextOverflow.ellipsis),
                filled: true,
                fillColor: c.inputFill,
                contentPadding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                // 右側區塊固定 40×44：快速回覆按鈕只淡入淡出，輸入框高度不隨有沒有文字改變，輸入列才不會跳動。
                suffixIconConstraints: const BoxConstraints.tightFor(width: 40, height: 44),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (_, value, _) {
                    final showQuick = value.text.isEmpty && widget.enabled;
                    return AnimatedOpacity(
                      duration: Motion.micro,
                      opacity: showQuick ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !showQuick,
                        child: IconButton(
                          onPressed: widget.onToggleQuickReplies,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(width: 40, height: 44),
                          icon: Icon(
                            widget.quickRepliesOpen ? Icons.keyboard_arrow_down_rounded : Icons.bolt_rounded,
                            size: 22,
                            color: widget.quickRepliesOpen ? c.accent : c.iconInactive,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrailingButton(AppColors c, bool voiceOpen) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        final active = widget.enabled;
        final String mode;
        if (hasText && !_voiceBusy) {
          mode = 'send';
        } else if (voiceOpen) {
          mode = 'keyboard';
        } else {
          mode = 'mic';
        }

        final VoidCallback? onTap;
        final IconData icon;
        final String tooltip;
        switch (mode) {
          case 'send':
            onTap = _submit;
            icon = Icons.send_rounded;
            tooltip = S.send;
          case 'keyboard':
            onTap = () => _closeVoice(focusInput: true);
            icon = Icons.keyboard_rounded;
            tooltip = S.switchKeyboard;
          default:
            onTap = _openVoice;
            icon = Icons.mic_rounded;
            tooltip = S.voiceMessage;
        }

        final filled = active && mode == 'send';
        return Tooltip(
          message: tooltip,
          child: Material(
            color: !active
                ? c.inputFill
                : filled
                    ? chatMineBubble(c)
                    : mode == 'keyboard'
                        ? c.accent.withValues(alpha: c.isDark ? 0.24 : 0.12)
                        : c.inputFill,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: active ? onTap : null,
              child: SizedBox(
                width: 44,
                height: 44,
                child: AnimatedSwitcher(
                  duration: Motion.micro,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: CurvedAnimation(parent: animation, curve: Motion.pop),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    icon,
                    key: ValueKey(mode),
                    color: !active
                        ? c.iconInactive
                        : filled
                            ? Colors.white
                            : c.accent,
                    size: mode == 'send' ? 20 : 23,
                  ),
                ),
              ),
            ),
          ),
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
