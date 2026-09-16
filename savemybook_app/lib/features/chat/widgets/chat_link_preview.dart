import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../i18n/strings.dart';
import '../../../models/chat.dart';
import '../../../models/link_preview.dart';
import '../../../services/api_service.dart';
import '../../../utils/api_helpers.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/state_views.dart';
import '../../books/book_detail_screen.dart';
import '../media/chat_network_image.dart';
import 'chat_bubbles.dart';

typedef LinkPreviewFetch = Future<({LinkPreview? preview, bool settled})> Function(String url);

class LinkPreviewStore {
  LinkPreviewStore._();

  static const _capacity = 300;
  static const _retryDelay = Duration(minutes: 1);

  static LinkPreviewFetch fetcher = (url) => ApiService().fetchLinkPreview(url);

  static final Map<String, LinkPreview?> _results = {};
  static final Map<String, DateTime> _retryAt = {};
  static final Map<String, Future<LinkPreview?>> _pending = {};

  static bool has(String url) => _results.containsKey(url);

  static LinkPreview? peek(String url) => _results[url];

  static Future<LinkPreview?> load(String url) {
    if (_results.containsKey(url)) return Future.value(_results[url]);
    final retryAt = _retryAt[url];
    if (retryAt != null && DateTime.now().isBefore(retryAt)) return Future.value(null);
    return _pending[url] ??= _fetch(url);
  }

  static Future<LinkPreview?> _fetch(String url) async {
    try {
      final result = await fetcher(url);
      if (result.settled) {
        _retryAt.remove(url);
        _results[url] = result.preview;
        while (_results.length > _capacity) {
          _results.remove(_results.keys.first);
        }
      } else {
        _retryAt[url] = DateTime.now().add(_retryDelay);
      }
      return result.preview;
    } catch (_) {
      _retryAt[url] = DateTime.now().add(_retryDelay);
      return null;
    } finally {
      _pending.remove(url);
    }
  }

  static void clear() {
    _results.clear();
    _retryAt.clear();
    _pending.clear();
  }

  static final RegExp _scheme = RegExp(r'^(https?://|www\.)', caseSensitive: false);
  static final RegExp _fullWidthStop = RegExp(r'[，。！？、；：「」『』（）【】《》〈〉]');
  static final RegExp _trailing = RegExp(r'''[.,;:!?'"\]}>…]+$''');

  static String? firstUrl(String text, {List<ChatMention> mentions = const []}) {
    final valid = ChatMention.validFor(text, mentions);
    for (final match in ChatLinkText.pattern.allMatches(text)) {
      if (valid.any((m) => match.start < m.end && match.end > m.start)) continue;
      var raw = match.group(0)!;
      if (!_scheme.hasMatch(raw)) continue;
      final stop = _fullWidthStop.firstMatch(raw);
      if (stop != null) raw = raw.substring(0, stop.start);
      raw = _trimTrailing(raw);
      if (raw.toLowerCase().startsWith('www.')) raw = 'https://$raw';
      final uri = Uri.tryParse(raw);
      if (uri == null || !uri.host.contains('.') || uri.host.startsWith('.') || uri.host.endsWith('.')) continue;
      return raw;
    }
    return null;
  }

  static String _trimTrailing(String value) {
    var result = value;
    while (true) {
      final before = result;
      result = result.replaceFirst(_trailing, '');
      if (result.endsWith(')') && '('.allMatches(result).length < ')'.allMatches(result).length) {
        result = result.substring(0, result.length - 1);
      }
      if (result == before) return result;
    }
  }
}

class ChatLinkPreviewCard extends StatefulWidget {
  final String url;
  final bool isMine;
  final double width;

  const ChatLinkPreviewCard({super.key, required this.url, required this.isMine, required this.width});

  static Future<bool> Function(Uri uri) openUrl = (uri) {
    final inApp = !kIsWeb && (Platform.isIOS || Platform.isAndroid);
    return launchUrl(uri, mode: inApp ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication);
  };

  @override
  State<ChatLinkPreviewCard> createState() => _ChatLinkPreviewCardState();
}

class _ChatLinkPreviewCardState extends State<ChatLinkPreviewCard> {
  LinkPreview? _preview;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ChatLinkPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resolve();
  }

  void _resolve() {
    final url = widget.url;
    if (LinkPreviewStore.has(url)) {
      _preview = LinkPreviewStore.peek(url);
      return;
    }
    _preview = null;
    LinkPreviewStore.load(url).then((preview) {
      if (!mounted || widget.url != url) return;
      setState(() => _preview = preview);
    });
  }

  Future<void> _open(LinkPreview preview) async {
    final token = preview.bookToken;
    if (preview.isBook && token != null) {
      final book = await runBusy(context, () => ApiService().fetchBookByShareToken(token));
      if (!mounted) return;
      if (book == null) {
        showAppSnackBar(context, S.bookNoLongerListed, isError: true);
        return;
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)));
      return;
    }
    final uri = Uri.tryParse(widget.url);
    var opened = false;
    if (uri != null) {
      try {
        opened = await ChatLinkPreviewCard.openUrl(uri);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && mounted) showAppSnackBar(context, S.unableOpenLink, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.standard,
      alignment: AlignmentDirectional.topStart,
      child: preview == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ChatLinkPreviewView(
                preview: preview,
                isMine: widget.isMine,
                width: widget.width,
                onTap: () => _open(preview),
              ),
            ),
    );
  }
}

class ChatLinkPreviewView extends StatelessWidget {
  final LinkPreview preview;
  final bool isMine;
  final double width;
  final VoidCallback? onTap;

  const ChatLinkPreviewView({super.key, required this.preview, required this.isMine, required this.width, this.onTap});

  static Map<String, String>? _headersFor(String url) {
    final token = ApiService.authToken;
    if (token == null || !url.startsWith('$kApiHost/api/')) return null;
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final mine = isMine;
    final panel = mine
        ? Colors.white.withValues(alpha: 0.16)
        : (c.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.045));
    final primary = mine ? Colors.white : c.textPrimary;
    final secondary = mine ? Colors.white.withValues(alpha: 0.78) : c.textSecondary;
    final radius = BorderRadius.circular(12);

    final site = Row(
      children: [
        Icon(preview.isBook ? Icons.menu_book_rounded : Icons.link_rounded, size: 13, color: secondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            preview.siteName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: secondary, height: 1.2),
          ),
        ),
      ],
    );

    final title = Text(
      preview.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primary, height: 1.3),
    );

    final Widget body;
    if (preview.isBook) {
      body = Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            BookThumbnail(imageUrl: preview.imageUrl, width: 46, height: 62, radius: 8),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  site,
                  const SizedBox(height: 3),
                  title,
                  if (preview.price != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      '\$${preview.price!.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: mine ? Colors.white : c.accent),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: secondary),
          ],
        ),
      );
    } else {
      final image = preview.imageUrl;
      final description = preview.description;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (image != null)
            AspectRatio(
              aspectRatio: 1.91,
              child: ChatNetworkImage(url: image, headers: _headersFor(image), iconSize: 24),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                site,
                const SizedBox(height: 3),
                title,
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: secondary, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: preview.title,
      excludeSemantics: true,
      child: PressableScale(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: ClipRRect(
            borderRadius: radius,
            child: ColoredBox(color: panel, child: body),
          ),
        ),
      ),
    );
  }
}
