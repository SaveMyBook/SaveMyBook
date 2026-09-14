import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../i18n/strings.dart';
import '../../models/chat.dart';
import '../../services/voice_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../animations.dart';
import '../state_views.dart';
import 'chat_format.dart';

class ChatDateSeparator extends StatelessWidget {
  final DateTime date;

  const ChatDateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: c.isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            chatDayLabel(date),
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.textSecondary),
          ),
        ),
      ),
    );
  }
}

class ChatSystemLine extends StatelessWidget {
  final String text;
  final IconData? icon;

  const ChatSystemLine({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: c.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: c.textHint),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatBubbleShell extends StatelessWidget {
  final bool isMine;
  final bool groupStart;
  final bool groupEnd;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Widget child;

  const ChatBubbleShell({
    super.key,
    required this.isMine,
    required this.groupStart,
    required this.groupEnd,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const big = Radius.circular(18);
    const small = Radius.circular(6);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (isMine ? chatMineBubble(c) : chatTheirsBubble(c)),
        borderRadius: BorderRadius.only(
          topLeft: !isMine && !groupStart ? small : big,
          bottomLeft: !isMine && !groupEnd ? small : big,
          topRight: isMine && !groupStart ? small : big,
          bottomRight: isMine && !groupEnd ? small : big,
        ),
        boxShadow: isMine || c.isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: child,
    );
  }
}

class ChatLinkText extends StatefulWidget {
  final String text;
  final bool isMine;

  const ChatLinkText({super.key, required this.text, required this.isMine});

  static final RegExp pattern = RegExp(
    r'(https?:\/\/[^\s]+|www\.[^\s]+|(?:\+886|0)9\d{2}[- ]?\d{3}[- ]?\d{3}|0\d{1,2}[- ]?\d{3,4}[- ]?\d{4})',
  );

  @override
  State<ChatLinkText> createState() => _ChatLinkTextState();
}

class _ChatLinkTextState extends State<ChatLinkText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    showAppSnackBar(context, S.copiedP0(value));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = widget.isMine ? Colors.white : c.textPrimary;
    final style = TextStyle(fontSize: 15, height: 1.4, color: color);
    final text = widget.text;

    _disposeRecognizers();
    final matches = ChatLinkText.pattern.allMatches(text).toList();
    if (matches.isEmpty) return Text(text, style: style);

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) spans.add(TextSpan(text: text.substring(cursor, m.start)));
      final value = m.group(0)!;
      final recognizer = TapGestureRecognizer()..onTap = () => _copy(value);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: value,
        recognizer: recognizer,
        style: TextStyle(
          decoration: TextDecoration.underline,
          decorationColor: widget.isMine ? Colors.white70 : c.accent,
          color: widget.isMine ? Colors.white : c.accent,
          fontWeight: FontWeight.w500,
        ),
      ));
      cursor = m.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

class ChatImageThumb extends StatefulWidget {
  final String? url;
  final String? localPath;
  final String? heroTag;
  final bool uploading;
  final bool failed;

  const ChatImageThumb({
    super.key,
    this.url,
    this.localPath,
    this.heroTag,
    this.uploading = false,
    this.failed = false,
  });

  @override
  State<ChatImageThumb> createState() => _ChatImageThumbState();
}

class _ChatImageThumbState extends State<ChatImageThumb> {
  static final Map<String, double> _aspects = {};

  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageProvider? _provider;

  String? get _cacheKey => widget.localPath ?? widget.url;

  ImageProvider? _buildProvider() {
    final path = widget.localPath;
    if (path != null && File(path).existsSync()) return FileImage(File(path));
    final url = widget.url;
    return url == null ? null : NetworkImage(url);
  }

  @override
  void initState() {
    super.initState();
    _provider = _buildProvider();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ChatImageThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.localPath != widget.localPath) {
      _provider = _buildProvider();
      _resolve();
    }
  }

  void _resolve() {
    final key = _cacheKey;
    final provider = _provider;
    if (key == null || provider == null || _aspects.containsKey(key)) return;
    _detach();
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (w > 0 && h > 0) {
        _aspects[key] = w / h;
        if (widget.url != null) _aspects[widget.url!] = w / h;
        if (mounted) setState(() {});
      }
      _detach();
    }, onError: (_, _) => _detach());
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _detach() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  Size _sizeFor(double? aspect, double maxWidth) {
    final limit = math.min(230.0, maxWidth);
    if (aspect == null) return Size(math.min(200, limit), 200);
    final a = aspect.clamp(0.5, 2.2);
    if (a >= 1) {
      final w = limit;
      return Size(w, math.max(110, w / a));
    }
    const h = 260.0;
    return Size(math.max(110, math.min(limit, h * a)), h);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final key = _cacheKey;
    final aspect = key == null ? null : (_aspects[key] ?? (widget.url == null ? null : _aspects[widget.url!]));
    final provider = _provider;

    return LayoutBuilder(builder: (context, constraints) {
      final size = _sizeFor(aspect, constraints.maxWidth.isFinite ? constraints.maxWidth : 230);

      Widget placeholder(IconData icon) => Container(
            width: size.width,
            height: size.height,
            color: c.inputFill,
            alignment: Alignment.center,
            child: Icon(icon, size: 30, color: c.iconInactive),
          );

      Widget image = provider == null
          ? placeholder(Icons.broken_image_outlined)
          : Image(
              image: provider,
              width: size.width,
              height: size.height,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => placeholder(Icons.broken_image_outlined),
              frameBuilder: (_, child, frame, sync) {
                if (sync) return child;
                return Stack(
                  children: [
                    if (frame == null) Shimmer(child: placeholder(Icons.image_outlined)),
                    AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: Motion.base,
                      curve: Curves.easeOut,
                      child: child,
                    ),
                  ],
                );
              },
            );

      if (widget.heroTag != null) image = Hero(tag: widget.heroTag!, child: image);

      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.standard,
          width: size.width,
          height: size.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (widget.uploading || widget.failed)
                Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  alignment: Alignment.center,
                  child: widget.failed
                      ? const Icon(Icons.error_outline_rounded, color: Colors.white, size: 30)
                      : const SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                        ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class ChatVoiceBody extends StatelessWidget {
  final String? url;
  final int seconds;
  final bool isMine;
  final bool uploading;
  final bool failed;

  const ChatVoiceBody({
    super.key,
    required this.url,
    required this.seconds,
    required this.isMine,
    this.uploading = false,
    this.failed = false,
  });

  static const _bars = 26;

  List<double> _heights() {
    final rnd = math.Random((url ?? '$seconds').hashCode);
    return List.generate(_bars, (i) {
      final wave = 0.45 + 0.35 * math.sin(i / _bars * math.pi);
      return (wave + rnd.nextDouble() * 0.4).clamp(0.2, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = isMine ? Colors.white : c.accent;
    final muted = isMine ? Colors.white.withValues(alpha: 0.38) : c.accent.withValues(alpha: 0.28);
    final width = 70 + math.min(seconds, 60) * 1.6;
    final heights = _heights();

    return ValueListenableBuilder<VoicePlaybackState>(
      valueListenable: VoicePlayback.instance.state,
      builder: (context, state, _) {
        final active = url != null && state.url == url;
        final playing = active && state.playing;
        final loading = active && state.loading;
        final progress = active ? state.progress : 0.0;
        final remaining = active && state.duration > Duration.zero
            ? (state.duration - state.position).inMilliseconds / 1000
            : seconds.toDouble();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: url == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  VoicePlayback.instance.toggle(url!, expected: Duration(seconds: seconds));
                },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isMine ? Colors.white.withValues(alpha: 0.2) : c.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: uploading || loading
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                    : failed
                        ? Icon(Icons.error_outline_rounded, size: 20, color: fg)
                        : AnimatedSwitcher(
                            duration: Motion.micro,
                            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                            child: Icon(
                              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              key: ValueKey(playing),
                              size: 22,
                              color: fg,
                            ),
                          ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: SizedBox(
                  width: width,
                  height: 26,
                  child: CustomPaint(
                    painter: _VoiceBarsPainter(heights: heights, progress: progress, active: fg, idle: muted),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                chatDuration(remaining.ceil()),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VoiceBarsPainter extends CustomPainter {
  final List<double> heights;
  final double progress;
  final Color active;
  final Color idle;

  _VoiceBarsPainter({required this.heights, required this.progress, required this.active, required this.idle});

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty) return;
    final step = size.width / heights.length;
    final barWidth = math.max(2.0, step * 0.55);
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < heights.length; i++) {
      final x = step * i + step / 2;
      final h = math.max(3.0, size.height * heights[i]);
      paint
        ..color = (i + 0.5) / heights.length <= progress ? active : idle
        ..strokeWidth = barWidth;
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceBarsPainter old) =>
      old.progress != progress || old.active != active || old.idle != idle || !listEquals(old.heights, heights);
}

class ChatBookCardView extends StatelessWidget {
  final ChatBookCard card;
  final VoidCallback onTap;

  const ChatBookCardView({super.key, required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: math.min(width * 0.82, 360)),
          child: PressableScale(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.border),
                boxShadow: [
                  BoxShadow(color: c.shadow.withValues(alpha: c.isDark ? 0.25 : 0.05), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  BookThumbnail(imageUrl: card.imageUrl, width: 54, height: 72, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.menu_book_rounded, size: 12, color: c.accent),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                S.iQuestionAboutBook,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: c.accent, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          card.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary, height: 1.3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${card.price.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.accent),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.iconInactive, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatTypingBubble extends StatefulWidget {
  const ChatTypingBubble({super.key});

  @override
  State<ChatTypingBubble> createState() => _ChatTypingBubbleState();
}

class _ChatTypingBubbleState extends State<ChatTypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chatTheirsBubble(c),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = (_controller.value - i * 0.18) % 1.0;
                final lift = math.sin(t * math.pi).clamp(0.0, 1.0);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 6,
                  height: 6,
                  transform: Matrix4.translationValues(0, -3 * lift, 0),
                  decoration: BoxDecoration(
                    color: c.textSecondary.withValues(alpha: 0.45 + 0.55 * lift),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              S.typing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatEntrance extends StatefulWidget {
  final bool animate;
  final bool fromRight;
  final Widget child;

  const ChatEntrance({super.key, required this.animate, required this.child, this.fromRight = false});

  @override
  State<ChatEntrance> createState() => _ChatEntranceState();
}

class _ChatEntranceState extends State<ChatEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.enter,
    value: widget.animate ? 0 : 1,
  );
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Motion.emphasized);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _curve,
      axisAlignment: -1,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (_, child) => Opacity(
          opacity: _curve.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset((widget.fromRight ? 16 : -16) * (1 - _curve.value), 10 * (1 - _curve.value)),
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
