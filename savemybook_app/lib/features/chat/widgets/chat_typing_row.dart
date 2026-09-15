import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/app_tiles.dart';
import 'chat_bubbles.dart';

typedef ChatTypingVisibility = ({bool shown, bool animate});

class ChatTypingRow extends StatefulWidget {
  final ValueListenable<ChatTypingVisibility> visibility;
  final ValueListenable<List<int>> userIds;
  final String? Function(int userId) avatarOf;

  const ChatTypingRow({super.key, required this.visibility, required this.userIds, required this.avatarOf});

  @override
  State<ChatTypingRow> createState() => _ChatTypingRowState();
}

class _ChatTypingRowState extends State<ChatTypingRow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.base,
    reverseDuration: Motion.micro,
    value: widget.visibility.value.shown ? 1 : 0,
  );
  late final Animation<double> _size = CurvedAnimation(parent: _controller, curve: Motion.emphasized, reverseCurve: Motion.exitCurve);
  late final Animation<double> _scale = Tween(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Motion.pop));
  List<int> _lastIds = const [];

  @override
  void initState() {
    super.initState();
    widget.visibility.addListener(_onVisibility);
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(covariant ChatTypingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibility != widget.visibility) {
      oldWidget.visibility.removeListener(_onVisibility);
      widget.visibility.addListener(_onVisibility);
      _onVisibility();
    }
  }

  @override
  void dispose() {
    widget.visibility.removeListener(_onVisibility);
    _controller.dispose();
    super.dispose();
  }

  void _onVisibility() {
    final v = widget.visibility.value;
    if (!v.animate) {
      _controller.value = v.shown ? 1 : 0;
    } else if (v.shown) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.reverse) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hidden = _controller.isDismissed;
    return TickerMode(
      enabled: !hidden,
      child: SizeTransition(
        sizeFactor: _size,
        axisAlignment: 1,
        child: hidden
            ? const SizedBox(width: double.infinity)
            : FadeTransition(
                opacity: _controller,
                child: ValueListenableBuilder<List<int>>(
                  valueListenable: widget.userIds,
                  builder: (context, ids, _) {
                    if (ids.isNotEmpty) _lastIds = ids;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 28, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _TypingAvatars(ids: _lastIds, avatarOf: widget.avatarOf),
                          const SizedBox(width: 8),
                          ScaleTransition(
                            scale: _scale,
                            alignment: Alignment.bottomLeft,
                            child: const ChatTypingBubble(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _TypingAvatars extends StatelessWidget {
  final List<int> ids;
  final String? Function(int userId) avatarOf;

  const _TypingAvatars({required this.ids, required this.avatarOf});

  @override
  Widget build(BuildContext context) {
    final shown = ids.take(3).toList();
    if (shown.length <= 1) {
      return SizedBox(
        width: 32,
        child: shown.isEmpty ? null : UserAvatar(imageUrl: avatarOf(shown.first), radius: 16),
      );
    }
    final c = AppColors.of(context);
    const radius = 12.0;
    const step = 15.0;
    const ring = 1.5;
    return SizedBox(
      width: (radius + ring) * 2 + step * (shown.length - 1),
      height: (radius + ring) * 2,
      child: Stack(
        children: [
          for (var i = shown.length - 1; i >= 0; i--)
            Positioned(
              left: step * i,
              child: Container(
                padding: const EdgeInsets.all(ring),
                decoration: BoxDecoration(color: c.scaffold, shape: BoxShape.circle),
                child: UserAvatar(imageUrl: avatarOf(shown[i]), radius: radius),
              ),
            ),
        ],
      ),
    );
  }
}
