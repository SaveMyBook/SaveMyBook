import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../i18n/strings.dart';
import '../../../models/chat.dart';
import '../../../services/voice_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/state_views.dart';
import '../media/chat_network_image.dart';
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

BorderRadius chatBubbleRadius({required bool isMine, required bool groupStart, required bool groupEnd}) {
  const big = Radius.circular(18);
  const small = Radius.circular(6);
  return BorderRadius.only(
    topLeft: !isMine && !groupStart ? small : big,
    bottomLeft: !isMine && !groupEnd ? small : big,
    topRight: isMine && !groupStart ? small : big,
    bottomRight: isMine && !groupEnd ? small : big,
  );
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

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (isMine ? chatMineBubble(c) : chatTheirsBubble(c)),
        borderRadius: chatBubbleRadius(isMine: isMine, groupStart: groupStart, groupEnd: groupEnd),
        boxShadow: isMine || c.isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: child,
    );
  }
}

class ChatCardFrame extends StatelessWidget {
  final BorderRadius radius;
  final Widget child;

  const ChatCardFrame({super.key, required this.radius, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: c.isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      // 底色必須畫在裁切範圍內，若由外層 decoration 另外畫，圓角的反鋸齒邊緣會透出一圈底色細線。
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: c.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
          ),
          child: ColoredBox(color: c.card, child: child),
        ),
      ),
    );
  }
}

class ChatLinkText extends StatefulWidget {
  final String text;
  final bool isMine;
  final List<ChatMention> mentions;
  final int myId;
  final ValueChanged<int>? onMentionTap;

  const ChatLinkText({
    super.key,
    required this.text,
    required this.isMine,
    this.mentions = const [],
    this.myId = 0,
    this.onMentionTap,
  });

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

  TapGestureRecognizer _recognizer(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final mine = widget.isMine;
    final color = mine ? Colors.white : c.textPrimary;
    final style = TextStyle(fontSize: 15, height: 1.4, color: color);
    final text = widget.text;

    _disposeRecognizers();
    final mentions = ChatMention.validFor(text, widget.mentions);
    final links = [
      for (final m in ChatLinkText.pattern.allMatches(text))
        if (!mentions.any((x) => m.start < x.end && m.end > x.start)) m,
    ];
    if (links.isEmpty && mentions.isEmpty) return Text(text, style: style);

    final ranges = <(int, int, Object)>[
      for (final m in mentions) (m.start, m.end, m),
      for (final m in links) (m.start, m.end, m),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final (start, end, item) in ranges) {
      if (start < cursor) continue;
      if (start > cursor) spans.add(TextSpan(text: text.substring(cursor, start)));
      final value = text.substring(start, end);
      if (item is ChatMention) {
        final toMe = !mine && (item.isEveryone || (widget.myId != 0 && item.userId == widget.myId));
        final onTap = widget.onMentionTap;
        spans.add(TextSpan(
          text: value,
          recognizer: !item.isEveryone && onTap != null ? _recognizer(() => onTap(item.userId)) : null,
          style: TextStyle(
            color: mine ? Colors.white : c.accent,
            fontWeight: toMe ? FontWeight.w800 : FontWeight.w700,
            backgroundColor: toMe
                ? c.accent.withValues(alpha: c.isDark ? 0.28 : 0.14)
                : null,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: value,
          recognizer: _recognizer(() => _copy(value)),
          style: TextStyle(
            decoration: TextDecoration.underline,
            decorationColor: mine ? Colors.white70 : c.accent,
            color: mine ? Colors.white : c.accent,
            fontWeight: FontWeight.w500,
          ),
        ));
      }
      cursor = end;
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
  final ValueListenable<double>? progress;

  const ChatImageThumb({
    super.key,
    this.url,
    this.localPath,
    this.heroTag,
    this.uploading = false,
    this.failed = false,
    this.progress,
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
                      : ValueListenableBuilder<double>(
                          valueListenable: widget.progress ?? const AlwaysStoppedAnimation<double>(0),
                          builder: (_, value, _) => SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              value: value <= 0.02 || value >= 1 ? null : value,
                              strokeWidth: 2.6,
                              color: Colors.white,
                              backgroundColor: value <= 0.02 || value >= 1 ? null : Colors.white24,
                            ),
                          ),
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
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      label: S.typing,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: chatTheirsBubble(c),
          borderRadius: BorderRadius.circular(19),
          boxShadow: c.isDark
              ? null
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 1))],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_controller.value - i * 0.16) % 1.0;
              final lift = t < 0.5 ? math.sin(t * 2 * math.pi).clamp(0.0, 1.0) : 0.0;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 7,
                height: 7,
                transform: Matrix4.translationValues(0, -4 * lift, 0),
                decoration: BoxDecoration(
                  color: c.textSecondary.withValues(alpha: 0.35 + 0.45 * lift),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ),
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

class ChatReplyThumb extends StatelessWidget {
  final ChatReply reply;
  final double size;
  final bool onBubble;

  const ChatReplyThumb({super.key, required this.reply, this.size = 36, this.onBubble = false});

  static const _icons = {
    'image': Icons.image_rounded,
    'album': Icons.photo_library_rounded,
    'voice': Icons.mic_rounded,
    'transfer': Icons.payments_rounded,
    'book': Icons.menu_book_rounded,
    'reservation': Icons.event_available_rounded,
  };

  static bool has(ChatReply reply) => !reply.isUnavailable && _icons.containsKey(reply.kind);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final url = reply.kind == 'image' || reply.kind == 'album' ? reply.imageUrl : null;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.18),
        child: ChatNetworkImage(url: url, width: size, height: size, iconSize: size * 0.4),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onBubble ? Colors.white.withValues(alpha: 0.2) : c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Icon(_icons[reply.kind] ?? Icons.chat_bubble_outline_rounded, size: size * 0.5, color: onBubble ? Colors.white : c.accent),
    );
  }
}

class ChatReplyQuote extends StatelessWidget {
  final ChatReply reply;
  final String senderName;
  final bool isMine;
  final bool divider;
  final VoidCallback? onTap;

  const ChatReplyQuote({
    super.key,
    required this.reply,
    required this.senderName,
    required this.isMine,
    this.divider = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final unavailable = reply.isUnavailable;
    final text = unavailable
        ? (reply.kind == 'recalled' ? S.messageUnsent : S.originalMessageUnavailable)
        : reply.preview.replaceAll('\n', ' ');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: unavailable ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (ChatReplyThumb.has(reply)) ...[
                ChatReplyThumb(reply: reply, size: 34, onBubble: isMine),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: isMine ? Colors.white : c.textPrimary,
                      ),
                    ),
                    Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: isMine ? Colors.white.withValues(alpha: 0.78) : c.textSecondary,
                        fontStyle: unavailable ? FontStyle.italic : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (divider)
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 7),
              color: isMine ? Colors.white.withValues(alpha: 0.28) : c.divider,
            ),
        ],
      ),
    );
  }
}

class ChatUnreadDivider extends StatelessWidget {
  const ChatUnreadDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final line = Expanded(child: Divider(height: 1, thickness: 1, color: c.accent.withValues(alpha: 0.35)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(S.unreadMessages, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.accent)),
          ),
          line,
        ],
      ),
    );
  }
}
