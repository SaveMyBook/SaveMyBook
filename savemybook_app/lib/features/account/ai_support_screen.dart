import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ai.dart';
import '../../services/ai_status.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../chat/widgets/chat_bubbles.dart';
import 'ai_consent_sheet.dart';
import 'support_ticket_screen.dart';
import '../../i18n/strings.dart';

enum AiChatState { sent, sending, failed }

class AiChatItem {
  final String id;
  final bool isUser;
  final String content;
  AiChatState state;
  String? error;
  bool blocked;
  bool suggestHandoff;
  final bool animate;

  AiChatItem({
    required this.id,
    required this.isUser,
    required this.content,
    this.state = AiChatState.sent,
    this.error,
    this.blocked = false,
    this.suggestHandoff = false,
    this.animate = true,
  });
}

class AiSupportScreen extends StatefulWidget {
  final List<AiChatItem>? initialItems;

  const AiSupportScreen({super.key, this.initialItems});

  @override
  State<AiSupportScreen> createState() => _AiSupportScreenState();
}

class _AiSupportScreenState extends State<AiSupportScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<AiChatItem> _items = [];
  bool _loading = true;
  bool _waiting = false;
  bool _busy = false;
  bool _consenting = false;
  String? _loadError;
  String? _blockedMessage;
  int _localSeq = 0;

  List<String> get _suggestions => [S.howDoIListBook, S.howDoIPickUpFrom, S.howDoIRequestRefund, S.howDoWalletCoinsWork];

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
    final result = await _api.fetchAiSupportSession();
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
          for (final m in result.data?.messages ?? const <AiSupportMessage>[])
            AiChatItem(id: 'm${m.messageId}', isUser: m.isUser, content: m.content, animate: false),
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

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _waiting) return;
    if (!await _ensureConsent()) return;
    if (preset == null) _input.clear();
    final item = AiChatItem(id: 'l${++_localSeq}', isUser: true, content: text, state: AiChatState.sending);
    setState(() {
      for (final i in _items) {
        i.suggestHandoff = false;
      }
      _items.add(item);
    });
    HapticFeedback.lightImpact();
    await _deliver(item);
  }

  Future<bool> _ensureConsent() async {
    if (AiStatus.value.consented) return true;
    if (_consenting) return false;
    _consenting = true;
    final agreed = await ensureAiConsent(context);
    _consenting = false;
    return agreed && mounted;
  }

  Future<void> _deliver(AiChatItem item) async {
    if (!await _ensureConsent()) return;
    setState(() {
      _waiting = true;
      item.state = AiChatState.sending;
      item.error = null;
    });
    _scrollToEnd();
    final result = await _api.sendAiSupportMessage(item.content);
    if (!mounted) return;
    if (result.needsConsent) {
      AiStatus.markConsentRevoked();
      setState(() {
        _waiting = false;
        item.state = AiChatState.failed;
        item.error = result.error;
      });
      await _deliver(item);
      return;
    }
    setState(() {
      _waiting = false;
      if (!result.isOk || result.data == null) {
        item.state = AiChatState.failed;
        item.error = result.error;
        item.blocked = result.isQuotaOrDisabled;
        return;
      }
      item.state = AiChatState.sent;
      final reply = result.data!;
      _items.add(AiChatItem(
        id: 'm${reply.reply.messageId}_${++_localSeq}',
        isUser: false,
        content: reply.reply.content,
        suggestHandoff: reply.suggestHandoff,
      ));
    });
    if (item.state == AiChatState.failed) {
      HapticFeedback.heavyImpact();
    }
    _scrollToEnd();
  }

  Future<void> _escalate() async {
    if (_busy) return;
    final hasConversation = _items.any((i) => i.isUser && i.state == AiChatState.sent);
    if (!hasConversation) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewTicketScreen()));
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: S.talkPerson,
      message: S.supportRequestCreatedFromConversationOur,
      confirmLabel: S.transfer4,
      icon: Icons.support_agent_rounded,
    );
    if (!confirmed || !mounted) return;
    _busy = true;
    final result = await runBusy(context, () => _api.escalateAiSupport(), message: S.creatingSupportRequest);
    _busy = false;
    if (!mounted || result == null) return;
    if (!result.isOk) {
      showAppSnackBar(context, result.error ?? '', isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    showAppSnackBar(context, S.transferredSupportTeam);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: result.data!)),
    );
  }

  Future<void> _newConversation() async {
    if (_busy || _waiting) return;
    if (_items.isEmpty) return;
    final confirmed = await showConfirmDialog(
      context,
      title: S.newConversation,
      message: S.currentConversationEnd,
      confirmLabel: S.newConversation,
      icon: Icons.add_comment_outlined,
    );
    if (!confirmed || !mounted) return;
    _busy = true;
    final error = await runBusy(context, () => _api.closeAiSupportSession());
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
            title: S.aiSupport,
            icon: Icons.support_agent_rounded,
            actions: [
              if (_items.isNotEmpty) HeaderIconButton(icon: Icons.add_comment_outlined, onTap: _newConversation),
            ],
          ),
          ResponsiveListPadding(
            maxWidth: Breakpoints.readingMaxWidth,
            top: 8,
            bottom: 0,
            builder: (context, padding) => Padding(padding: padding, child: _toolbar(c)),
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

  Widget _toolbar(AppColors c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: TextButton.icon(
            onPressed: _escalate,
            style: TextButton.styleFrom(foregroundColor: c.accent, visualDensity: VisualDensity.compact),
            icon: const Icon(Icons.support_agent_rounded, size: 18),
            label: Text(S.talkPerson, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
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
              FadeSlideIn(child: AiAvatar(size: 64)),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 1,
                child: Text(S.howCanWeHelp,
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary)),
              ),
              const SizedBox(height: 20),
              if (_blockedMessage == null)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, s) in _suggestions.indexed)
                      FadeSlideIn(
                        index: i + 2,
                        child: PressableScale(
                          scale: 0.95,
                          onTap: () => _send(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: c.border),
                            ),
                            child: Text(s, style: TextStyle(fontSize: 13, color: c.textPrimary)),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageList(AppColors c) {
    return LayoutBuilder(
      key: const ValueKey('list'),
      builder: (context, constraints) {
        final maxBubble = math.min(constraints.maxWidth, Breakpoints.readingMaxWidth) * 0.78;
        return ListView.builder(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: responsiveListPadding(constraints, maxWidth: Breakpoints.readingMaxWidth, horizontal: 14, top: 12, bottom: 16),
          itemCount: _items.length + (_waiting ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= _items.length) {
              return Padding(
                key: const ValueKey('typing'),
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: ChatEntrance(
                  animate: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [const AiAvatar(size: 30), const SizedBox(width: 8), const ChatTypingBubble()],
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
                      : _assistantMessage(c, item, maxBubble, groupStart, groupEnd),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _userMessage(AppColors c, AiChatItem item, double maxWidth, bool groupStart, bool groupEnd) {
    final failed = item.state == AiChatState.failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
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
                    opacity: item.state == AiChatState.sending ? 0.7 : 1,
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

  Widget _assistantMessage(AppColors c, AiChatItem item, double maxWidth, bool groupStart, bool groupEnd) {
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
                    groupEnd: groupEnd,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: AiMarkdownText(item.content, style: TextStyle(fontSize: 15, height: 1.5, color: c.textPrimary)),
                  ),
                ),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.emphasized,
          alignment: Alignment.topLeft,
          child: item.suggestHandoff
              ? Padding(
                  padding: const EdgeInsets.only(left: 38, top: 8),
                  child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: _handoffCard(c)),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _handoffCard(AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent_rounded, size: 18, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(S.ourSupportTeamCanHelpWith,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.textPrimary)),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _escalate,
              style: TextButton.styleFrom(foregroundColor: c.accent, visualDensity: VisualDensity.compact),
              child: Text(S.talkPerson, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
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
            ? Row(
                children: [
                  Expanded(child: _inlineNotice(c, blocked, icon: Icons.info_outline_rounded, color: c.warning)),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _escalate,
                    style: TextButton.styleFrom(foregroundColor: c.accent),
                    child: Text(S.contactSupport, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _input,
                      hint: S.typeQuestion,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
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

class AiAvatar extends StatelessWidget {
  final double size;

  const AiAvatar({super.key, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accent, c.isDark ? const Color(0xFF9C7CF0) : const Color(0xFF7B5CE6)],
        ),
      ),
      child: Icon(Icons.auto_awesome_rounded, size: size * 0.52, color: Colors.white),
    );
  }
}

class AiMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const AiMarkdownText(this.text, {super.key, required this.style});

  static final _bullet = RegExp(r'^\s*(?:[-*•・]|•)\s+');
  static final _numbered = RegExp(r'^\s*(\d{1,2})[.)、]\s+');
  static final _heading = RegExp(r'^\s*#{1,6}\s+');
  static final _bold = RegExp(r'\*\*(.+?)\*\*');

  List<InlineSpan> _inline(String line, TextStyle base) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _bold.allMatches(line)) {
      if (m.start > last) spans.add(TextSpan(text: line.substring(last, m.start)));
      spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.bold)));
      last = m.end;
    }
    if (last < line.length) spans.add(TextSpan(text: line.substring(last).replaceAll('`', '')));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final lines = text.trim().replaceAll('\r\n', '\n').split('\n');
    final children = <Widget>[];
    var previousBlank = false;
    for (final raw in lines) {
      if (raw.trim().isEmpty) {
        if (!previousBlank && children.isNotEmpty) children.add(const SizedBox(height: 6));
        previousBlank = true;
        continue;
      }
      previousBlank = false;
      final bullet = _bullet.firstMatch(raw);
      final numbered = bullet == null ? _numbered.firstMatch(raw) : null;
      final heading = bullet == null && numbered == null ? _heading.firstMatch(raw) : null;
      if (bullet != null || numbered != null) {
        final body = raw.substring((bullet ?? numbered)!.end);
        children.add(Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: numbered != null ? 20 : 14,
                child: Text(numbered != null ? '${numbered.group(1)}.' : '•', style: style),
              ),
              Expanded(child: Text.rich(TextSpan(children: _inline(body, style)), style: style)),
            ],
          ),
        ));
      } else if (heading != null) {
        children.add(Text.rich(
          TextSpan(children: _inline(raw.substring(heading.end), style)),
          style: style.copyWith(fontWeight: FontWeight.bold),
        ));
      } else {
        children.add(Text.rich(TextSpan(children: _inline(raw.trimRight(), style)), style: style));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children);
  }
}
