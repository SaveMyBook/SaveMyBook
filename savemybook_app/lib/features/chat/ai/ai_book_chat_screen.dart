import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/ai.dart';
import '../../../models/book.dart';
import '../../../services/ai_status.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/app_forms.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/responsive.dart';
import '../../../widgets/state_views.dart';
import '../../account/ai_consent_sheet.dart';
import '../../account/ai_support_screen.dart';
import '../../books/book_detail_screen.dart';
import '../widgets/chat_bubbles.dart';
import '../../../i18n/strings.dart';

enum AiBookChatState { sent, sending, failed }

class AiBookChatItem {
  final String id;
  final bool isUser;
  final String content;
  final List<AiBookSuggestion> books;
  final List<String> suggestions;
  AiBookChatState state;
  String? error;
  bool blocked;
  final bool animate;

  AiBookChatItem({
    required this.id,
    required this.isUser,
    required this.content,
    this.books = const [],
    this.suggestions = const [],
    this.state = AiBookChatState.sent,
    this.error,
    this.blocked = false,
    this.animate = true,
  });
}

class AiBookChatScreen extends StatefulWidget {
  final List<AiBookChatItem>? initialItems;

  const AiBookChatScreen({super.key, this.initialItems});

  @override
  State<AiBookChatScreen> createState() => _AiBookChatScreenState();
}

class _AiBookChatScreenState extends State<AiBookChatScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<AiBookChatItem> _items = [];
  bool _loading = true;
  bool _waiting = false;
  bool _busy = false;
  bool _consenting = false;
  String? _loadError;
  String? _blockedMessage;
  int _localSeq = 0;

  List<String> get _starters => [S.mysteryNovelMyCommute, S.programmingBooksBeginners, S.booksUnder200Coins, S.popularLiteraryFictionRightNow];

  @override
  void initState() {
    super.initState();
    final preset = widget.initialItems;
    if (preset == null) {
      _load();
    } else {
      _items.addAll(preset);
      _loading = false;
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final result = await _api.fetchAiBookChatSession();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!result.isOk) {
        if (result.isQuotaOrDisabled) {
          _blockedMessage = result.error;
        } else {
          _loadError = result.error;
        }
        return;
      }
      _items
        ..clear()
        ..addAll([
          for (final m in result.data?.messages ?? const <AiBookChatMessage>[])
            AiBookChatItem(id: 'm${m.messageId}', isUser: m.isUser, content: m.content, books: m.books, animate: false),
        ]);
    });
    _scrollToEnd(jump: true);
  }

  void _scrollToEnd({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (jump) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(target, duration: Motion.enter, curve: Motion.standard);
      }
    });
  }

  Future<bool> _ensureConsent() async {
    if (AiStatus.value.consented) return true;
    if (_consenting) return false;
    _consenting = true;
    final agreed = await ensureAiConsent(context);
    _consenting = false;
    return agreed && mounted;
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _waiting) return;
    if (!await _ensureConsent()) return;
    if (preset == null) _input.clear();
    final item = AiBookChatItem(id: 'l${++_localSeq}', isUser: true, content: text, state: AiBookChatState.sending);
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        if (_items[i].suggestions.isNotEmpty) _items[i] = _withoutSuggestions(_items[i]);
      }
      _items.add(item);
    });
    HapticFeedback.lightImpact();
    await _deliver(item);
  }

  AiBookChatItem _withoutSuggestions(AiBookChatItem item) => AiBookChatItem(
        id: item.id,
        isUser: item.isUser,
        content: item.content,
        books: item.books,
        state: item.state,
        error: item.error,
        blocked: item.blocked,
        animate: false,
      );

  Future<void> _deliver(AiBookChatItem item) async {
    if (!await _ensureConsent()) return;
    setState(() {
      _waiting = true;
      item.state = AiBookChatState.sending;
      item.error = null;
    });
    _scrollToEnd();
    final result = await _api.sendAiBookChatMessage(item.content);
    if (!mounted) return;
    if (result.needsConsent) {
      AiStatus.markConsentRevoked();
      setState(() {
        _waiting = false;
        item.state = AiBookChatState.failed;
        item.error = result.error;
      });
      await _deliver(item);
      return;
    }
    setState(() {
      _waiting = false;
      if (!result.isOk || result.data == null) {
        item.state = AiBookChatState.failed;
        item.error = result.error;
        item.blocked = result.isQuotaOrDisabled;
        return;
      }
      item.state = AiBookChatState.sent;
      final reply = result.data!.reply;
      _items.add(AiBookChatItem(
        id: 'm${reply.messageId}_${++_localSeq}',
        isUser: false,
        content: reply.content,
        books: reply.books,
        suggestions: reply.suggestions,
      ));
    });
    if (item.state == AiBookChatState.failed) HapticFeedback.heavyImpact();
    _scrollToEnd();
  }

  Future<void> _newConversation() async {
    if (_busy || _waiting || _items.isEmpty) return;
    final confirmed = await showConfirmDialog(
      context,
      title: S.newConversation,
      message: S.currentConversationEnd,
      confirmLabel: S.newConversation,
      icon: Icons.add_comment_outlined,
    );
    if (!confirmed || !mounted) return;
    _busy = true;
    final error = await runBusy(context, () => _api.closeAiBookChatSession());
    _busy = false;
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _items.clear());
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    showAppSnackBar(context, S.copied2);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: S.aiBookAdvisor,
            icon: Icons.auto_stories_rounded,
            actions: [
              if (_items.isNotEmpty) HeaderIconButton(icon: Icons.add_comment_outlined, onTap: _newConversation),
            ],
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SwitchIn(
                child: _loading
                    ? const LoadingView(key: ValueKey('loading'))
                    : _loadError != null
                        ? ErrorView(key: const ValueKey('error'), message: _loadError, onRetry: _load)
                        : _items.isEmpty
                            ? _emptyState(c)
                            : _messageList(c),
              ),
            ),
          ),
          if (!_loading && _loadError == null) _bottom(c),
        ],
      ),
    );
  }

  Widget _emptyState(AppColors c) {
    return LayoutBuilder(
      key: const ValueKey('empty'),
      builder: (context, constraints) => SingleChildScrollView(
        padding: responsiveListPadding(constraints, maxWidth: Breakpoints.readingMaxWidth, horizontal: 24, top: 24, bottom: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.max(0, constraints.maxHeight - 48)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FadeSlideIn(child: AiAvatar(size: 64)),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 1,
                child: Text(S.tellMeWhatBookLooking,
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary)),
              ),
              const SizedBox(height: 6),
              FadeSlideIn(
                index: 2,
                child: Text(S.allRecommendationsComeFromBooksCurrently,
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary)),
              ),
              const SizedBox(height: 20),
              if (_blockedMessage == null)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, s) in _starters.indexed) FadeSlideIn(index: i + 3, child: _pill(c, s)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(AppColors c, String label) {
    return PressableScale(
      scale: 0.95,
      onTap: _waiting ? null : () => _send(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: c.textPrimary)),
      ),
    );
  }

  Widget _messageList(AppColors c) {
    return LayoutBuilder(
      key: const ValueKey('list'),
      builder: (context, constraints) {
        final contentWidth = math.min(constraints.maxWidth, Breakpoints.readingMaxWidth);
        final maxBubble = contentWidth * 0.78;
        return ListView.builder(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: responsiveListPadding(constraints, maxWidth: Breakpoints.readingMaxWidth, horizontal: 14, top: 12, bottom: 16),
          itemCount: _items.length + (_waiting ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= _items.length) {
              return const Padding(
                key: ValueKey('typing'),
                padding: EdgeInsets.only(top: 4, bottom: 8),
                child: ChatEntrance(
                  animate: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [AiAvatar(size: 30), SizedBox(width: 8), ChatTypingBubble()],
                  ),
                ),
              );
            }
            final item = _items[i];
            final previous = i > 0 ? _items[i - 1] : null;
            final next = i + 1 < _items.length ? _items[i + 1] : null;
            final groupStart = previous == null || previous.isUser != item.isUser;
            final groupEnd = next == null || next.isUser != item.isUser;
            return KeyedSubtree(
              key: ValueKey(item.id),
              child: ChatEntrance(
                animate: item.animate,
                fromRight: item.isUser,
                child: Padding(
                  padding: EdgeInsets.only(top: groupStart && i > 0 ? 10 : 2),
                  child: item.isUser
                      ? _userMessage(c, item, maxBubble, groupStart, groupEnd)
                      : _assistantMessage(c, item, maxBubble, contentWidth, groupStart, groupEnd),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _userMessage(AppColors c, AiBookChatItem item, double maxWidth, bool groupStart, bool groupEnd) {
    final failed = item.state == AiBookChatState.failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (failed && !item.blocked)
              IconButton(
                tooltip: S.resend,
                onPressed: _waiting ? null : () => _deliver(item),
                icon: Icon(Icons.refresh_rounded, color: c.danger, size: 20),
              ),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: GestureDetector(
                  onLongPress: () => _copy(item.content),
                  child: AnimatedOpacity(
                    duration: Motion.micro,
                    opacity: item.state == AiBookChatState.sending ? 0.7 : 1,
                    child: ChatBubbleShell(
                      isMine: true,
                      groupStart: groupStart,
                      groupEnd: groupEnd,
                      child: Text(item.content, style: const TextStyle(fontSize: 15, height: 1.45, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (failed)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: item.blocked
                ? _inlineNotice(c, item.error ?? '', icon: Icons.block_rounded, color: c.warning, maxWidth: maxWidth)
                : Text(item.error?.isNotEmpty == true ? item.error! : S.failedSend,
                    textAlign: TextAlign.end, style: TextStyle(fontSize: 11.5, color: c.danger)),
          ),
      ],
    );
  }

  Widget _assistantMessage(AppColors c, AiBookChatItem item, double maxWidth, double contentWidth, bool groupStart, bool groupEnd) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(width: 30, child: groupEnd ? const AiAvatar(size: 30) : null),
            const SizedBox(width: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: GestureDetector(
                  onLongPress: () => _copy(item.content),
                  child: ChatBubbleShell(
                    isMine: false,
                    groupStart: groupStart,
                    groupEnd: groupEnd && item.books.isEmpty,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: AiMarkdownText(item.content, style: TextStyle(fontSize: 15, height: 1.5, color: c.textPrimary)),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (item.books.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              height: AiBookChatCard.height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(left: 38, right: 8),
                itemCount: item.books.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => FadeSlideIn(index: i, offsetY: 10, child: AiBookChatCard(suggestion: item.books[i])),
              ),
            ),
          ),
        if (item.suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 38, top: 10),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: math.max(0, contentWidth - 38)),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final s in item.suggestions) _pill(c, s)],
              ),
            ),
          ),
      ],
    );
  }

  Widget _inlineNotice(AppColors c, String text, {required IconData icon, required Color color, double? maxWidth}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.4, color: c.textPrimary))),
          ],
        ),
      ),
    );
  }

  Widget _bottom(AppColors c) {
    final blocked = _blockedMessage;
    return ResponsiveListPadding(
      maxWidth: Breakpoints.readingMaxWidth,
      top: 10,
      bottom: MediaQuery.paddingOf(context).bottom + 10,
      builder: (context, padding) => Container(
        padding: padding,
        decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.divider))),
        child: blocked != null
            ? _inlineNotice(c, blocked, icon: Icons.info_outline_rounded, color: c.warning)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _input,
                      hint: S.describeBookLooking,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 500,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _input,
                    builder: (_, value, _) {
                      final ready = value.text.trim().isNotEmpty && !_waiting;
                      return PressableScale(
                        onTap: ready ? _send : null,
                        child: AnimatedContainer(
                          duration: Motion.micro,
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: ready ? c.accent : c.accent.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: _waiting
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
                        ),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

class AiBookChatCard extends StatelessWidget {
  final AiBookSuggestion suggestion;

  const AiBookChatCard({super.key, required this.suggestion});

  static const double width = 158;
  static const double height = 208;
  static const double _imageHeight = 96;

  Book get book => suggestion.book;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return PressableScale(
      scale: 0.96,
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => BookDetailScreen(book: book))),
      child: Container(
        width: width,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AppNetworkImage(url: book.hasImage ? book.imageUrl : null, width: width, height: _imageHeight, fallbackIconSize: 26),
                Positioned(top: 4, right: 4, child: _favoriteButton(c)),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w600, color: c.textPrimary),
                    ),
                    if (suggestion.reason != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        suggestion.reason!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, height: 1.25, color: c.textSecondary),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('\$${book.price.toInt()}',
                                maxLines: 1, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.accent)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            book.conditionText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.conditionColor(book.conditionLevel)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _favoriteButton(AppColors c) {
    return ValueListenableBuilder<Set<int>>(
      valueListenable: ApiService.favoriteBookIds,
      builder: (context, ids, _) {
        final saved = ids.contains(book.bookId);
        return Material(
          color: Colors.black.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              HapticFeedback.selectionClick();
              final error = await ApiService().toggleFavorite(book.bookId);
              if (error != null && context.mounted) showAppSnackBar(context, error, isError: true);
            },
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 16, color: saved ? c.danger : Colors.white),
            ),
          ),
        );
      },
    );
  }
}
