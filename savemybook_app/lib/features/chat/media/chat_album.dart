import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/chat_entry.dart';
import 'chat_network_image.dart';

class ChatAlbumView extends StatelessWidget {
  static const gap = 3.0;
  static const radius = 16.0;
  static const pairTileMax = 150.0;
  static const stripTile = 140.0;

  final List<String?> urls;
  final List<String?> localPaths;
  final List<ChatUploadSlot> slots;
  final String heroPrefix;
  final ValueChanged<int>? onOpen;
  final VoidCallback? onFailedTap;

  const ChatAlbumView({
    super.key,
    required this.urls,
    this.localPaths = const [],
    this.slots = const [],
    required this.heroPrefix,
    this.onOpen,
    this.onFailedTap,
  });

  int get count => math.max(urls.length, math.max(localPaths.length, slots.length));

  static String heroTag(String prefix, int index) => '$prefix#$index';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 280.0;
      final n = count;
      if (n <= 2) {
        final tile = math.min(pairTileMax, (maxWidth - gap) / 2).floorToDouble();
        return ClipRRect(
          key: const ValueKey('chat_album_pair'),
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            width: tile * n + gap * (n - 1),
            height: tile,
            child: Row(
              children: [
                for (var i = 0; i < n; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  SizedBox(width: tile, height: tile, child: _tile(i)),
                ],
              ],
            ),
          ),
        );
      }

      final tile = math.min(stripTile, math.max(88.0, (maxWidth - 2 * gap) / 2.4)).floorToDouble();
      final width = math.min(maxWidth, n * tile + (n - 1) * gap);
      return SizedBox(
        key: const ValueKey('chat_album_strip'),
        width: width,
        height: tile,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: n,
                separatorBuilder: (_, _) => const SizedBox(width: gap),
                itemBuilder: (_, i) => SizedBox(
                  width: tile,
                  height: tile,
                  child: ClipRRect(borderRadius: BorderRadius.circular(radius * 0.6), child: _tile(i)),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IgnorePointer(child: _CountBadge(count: n)),
            ),
          ],
        ),
      );
    });
  }

  Widget _tile(int index) {
    final url = index < urls.length ? urls[index] : null;
    final local = index < localPaths.length ? localPaths[index] : null;
    final slot = index < slots.length ? slots[index] : null;

    Widget image = ChatNetworkImage(url: url, localPath: local ?? slot?.localPath, iconSize: 24);
    if (url != null) image = Hero(tag: heroTag(heroPrefix, index), child: image);

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: url != null && onOpen != null ? () => onOpen!(index) : onFailedTap,
          child: image,
        ),
        if (slot != null) IgnorePointer(ignoring: onFailedTap == null, child: _UploadOverlay(slot: slot, onFailedTap: onFailedTap)),
      ],
    );
  }
}

class _UploadOverlay extends StatelessWidget {
  final ChatUploadSlot slot;
  final VoidCallback? onFailedTap;

  const _UploadOverlay({required this.slot, this.onFailedTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([slot.progress, slot.failed]),
      builder: (context, _) {
        final failed = slot.failed.value;
        if (!failed && slot.uploaded) return const SizedBox.shrink();
        final progress = slot.progress.value;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: failed ? onFailedTap : null,
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.38),
            child: Center(
              child: failed
                  ? const Icon(Icons.error_outline_rounded, color: Colors.white, size: 28)
                  : SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        value: progress <= 0.02 ? null : progress,
                        strokeWidth: 2.6,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_outlined, size: 13, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.2),
          ),
        ],
      ),
    );
  }
}
