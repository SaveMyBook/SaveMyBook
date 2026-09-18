import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../i18n/strings.dart';
import '../../models/book.dart';
import '../../models/chat.dart';
import '../../services/api_service.dart';
import '../../services/voice_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/animations.dart';
import 'media/chat_album.dart';
import 'media/chat_media_upload.dart';
import 'mentions/chat_mention_controller.dart';
import 'settings/chat_room_settings_screen.dart';
import 'transfer/transfer_card.dart';
import 'transfer/transfer_flow.dart';
import 'widgets/chat_bubbles.dart';
import 'widgets/chat_composer_banners.dart';
import 'widgets/chat_conversation_overlays.dart';
import 'widgets/chat_entry.dart';
import 'widgets/chat_format.dart';
import 'widgets/chat_input_accessories.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_link_preview.dart';
import 'widgets/chat_message_meta.dart';
import 'widgets/chat_room_header.dart';
import 'widgets/chat_scroll_anchor.dart';
import 'widgets/chat_sheets.dart';
import 'widgets/chat_typing_row.dart';
import 'widgets/reservation_card.dart';
import 'widgets/swipe_to_reply.dart';
import '../../widgets/image_save_feedback.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/state_views.dart';
import '../books/book_detail_screen.dart';
import '../orders/cart_screen.dart';
import '../books/seller_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final int roomId;
  final String partnerName;

  final VoidCallback? onClose;

  const ChatRoomScreen({super.key, required this.roomId, this.partnerName = '', this.onClose});

  bool get embedded => onClose != null;

  static final List<_ChatRoomScreenState> _mounted = [];

  static int? get activeRoomId {
    for (final state in _mounted.reversed) {
      if (state._isOnScreen) return state.widget.roomId;
    }
    return null;
  }

  static bool isShowing(int? roomId) => roomId != null && activeRoomId == roomId;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 3);
  static const _typingInterval = Duration(seconds: 3);
  static const _editWindow = Duration(minutes: 15);
  static const _recallWindow = Duration(hours: 1);
  static const _pageSize = 40;
  static const _replyableKinds = {'text', 'image', 'album', 'voice'};
  // 用來比對伺服器回傳的中文錯誤訊息，必須維持 const，翻譯抽取才會略過它。
  static const _unreachableMarker = '無法接收訊息';

  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  late final ChatMentionController _mentions = ChatMentionController(_controller);
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final Key _centerKey = const ValueKey('chat_center');
  final GlobalKey _typingKey = GlobalKey();

  final List<ChatMessage> _messages = [];
  final Set<int> _ids = {};
  final List<ChatPendingMessage> _pending = [];
  final Map<int, ChatReservation> _reservations = {};
  final Map<int, ChatTransfer> _transfers = {};
  final Map<int, String> _clientKeys = {};
  final Map<int, String> _localImages = {};
  final Map<int, List<String>> _localAlbums = {};
  final Set<String> _fresh = {};
  final Set<int> _busyReservations = {};
  final Set<int> _busyTransfers = {};

  final Map<int, String> _aliases = {};
  final Map<int, int> _membersRead = {};
  final Map<int, String> _senderNames = {};
  final Map<int, String> _senderAvatars = {};
  Map<int, ChatMember> _members = const {};
  ChatRoomInfo? _roomInfo;

  final ValueNotifier<List<int>> _typingIds = ValueNotifier(const []);
  final ValueNotifier<ChatTypingVisibility> _typingVisibility = ValueNotifier((shown: false, animate: false));
  final ValueNotifier<String?> _highlight = ValueNotifier(null);
  final Map<String, BuildContext> _anchors = {};
  ChatReply? _replyTo;
  ChatMessage? _editing;
  String _draftBeforeEdit = '';
  List<ChatMention> _draftMentionsBeforeEdit = const [];
  int? _unreadFromId;
  final ValueNotifier<int> _unseen = ValueNotifier(0);
  final ValueNotifier<bool> _showJump = ValueNotifier(false);

  List<ChatEntry> _entries = const [];
  Map<String, int> _keyIndex = const {};
  int _baseCount = 0;
  int _pivotId = 0;

  ChatPartner? _partner;
  Book? _reserveBook;
  int? _checkedBookId;
  int _readUpto = 0;

  bool _isGroup = false;
  String _roomTitle = '';
  String? _roomAvatarUrl;
  int _memberCount = 0;

  bool _loading = true;
  bool _loadError = false;
  bool _hasMore = false;
  bool _loadingOlder = false;
  DateTime _olderFailedAt = DateTime(0);
  bool _polling = false;
  int _failures = 0;
  bool _offline = false;
  bool _partnerUnavailable = false;
  bool _muted = false;
  bool _blocked = false;
  bool _updatingControls = false;
  bool _quickRepliesOpen = false;

  Timer? _pollTimer;
  Future<void> _sendQueue = Future.value();
  int _pendingSeq = 0;
  DateTime _lastTypingPing = DateTime(0);
  bool _typingSent = false;

  int get _myId => ApiService.currentUser?.userId ?? 0;

  @override
  void initState() {
    super.initState();
    ChatRoomScreen._mounted.add(this);
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onTextChanged);
    _scroll.addListener(_onScroll);
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    ChatRoomScreen._mounted.remove(this);
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _stopTyping();
    VoicePlayback.instance.stop();
    _api.fetchUnreadChatCount();
    _mentions.dispose();
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    _typingIds.dispose();
    _typingVisibility.dispose();
    _highlight.dispose();
    _unseen.dispose();
    _showJump.dispose();
    super.dispose();
  }

  bool get _isOnScreen {
    if (!mounted) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return false;
    return ModalRoute.of(context)?.isCurrent ?? false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _poll(force: true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pollTimer?.cancel();
      _pollTimer = null;
      _stopTyping();
      VoicePlayback.instance.stop();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  bool get _isAtBottom {
    if (!_scroll.hasClients) return true;
    final p = _scroll.position;
    return p.pixels - p.minScrollExtent < 80;
  }

  bool get _hasNewer => _messages.isNotEmpty && _messages.last.messageId > _pivotId;

  bool _isRead(ChatMessage m) => m.isRead || (m.messageId > 0 && m.messageId <= _readUpto);

  Future<void> _load() async {
    if (!_loading || _loadError) {
      setState(() {
        _loading = true;
        _loadError = false;
      });
    }

    final result = await _api.fetchChatMessages(widget.roomId, limit: _pageSize);
    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _loading = false;
        _loadError = true;
      });
      return;
    }

    final firstUnread = result.messages.where((m) => m.senderId != _myId && !m.isRead && m.messageId > 0);
    setState(() {
      _unreadFromId = firstUnread.isEmpty ? null : firstUnread.first.messageId;
      _messages.clear();
      _ids.clear();
      _mergeMessages(result.messages);
      if (result.partner.userId != 0) _partner = result.partner;
      _applyRoom(result);
      _readUpto = result.readUpto;
      _hasMore = result.hasMore;
      _reservations
        ..clear()
        ..addAll(result.reservations);
      _transfers
        ..clear()
        ..addAll(result.transfers);
      _applyControls(result);
      _pivotId = _messages.isEmpty ? 0 : _messages.last.messageId;
      _loading = false;
      _loadError = false;
      _offline = false;
      _failures = 0;
      _rebuildEntries();
    });
    _setTyping(_typingFrom(result));
    if (_isGroup) _loadRoomInfo();
    _refreshReservable();
    _fillViewportWithOlder();
    _revealUnread();
  }

  Future<void> _loadRoomInfo() async {
    final (info, _) = await _api.fetchChatRoomInfo(widget.roomId);
    if (!mounted || info == null) return;
    setState(() => _setRoomInfo(info));
  }

  void _setRoomInfo(ChatRoomInfo info) {
    _roomInfo = info;
    _members = {for (final m in info.members) m.userId: m};
    if (info.isGroup) {
      _isGroup = true;
      if (info.name.isNotEmpty) _roomTitle = info.name;
      _roomAvatarUrl = info.avatarUrl;
      if (info.members.isNotEmpty) _memberCount = info.members.length;
    }
    _syncMentionCandidates();
  }

  void _syncMentionCandidates() {
    _mentions.enabled = _isGroup;
    _mentions.members = [
      for (final m in _roomInfo?.members ?? const <ChatMember>[])
        if (m.userId != _myId)
          ChatMentionCandidate(
            userId: m.userId,
            name: _nameOf(m.userId, fallback: m.displayName),
            nickname: m.nickname,
            avatarUrl: m.avatarUrl,
          ),
    ];
  }

  bool _applyRoom(ChatFetchResult result) {
    var changed = false;
    if (!mapEquals(_aliases, result.aliases) && (result.aliases.isNotEmpty || _aliases.isNotEmpty)) {
      _aliases
        ..clear()
        ..addAll(result.aliases);
      changed = true;
    }
    result.membersRead.forEach((userId, lastRead) {
      if ((_membersRead[userId] ?? -1) < lastRead) {
        _membersRead[userId] = lastRead;
        changed = true;
      }
    });
    if (result.roomTitle.isEmpty && result.roomType != 'group') return changed;
    final isGroup = result.roomType == 'group';
    if (_isGroup != isGroup ||
        _roomTitle != result.roomTitle ||
        _roomAvatarUrl != result.roomAvatarUrl ||
        (isGroup && _memberCount != result.memberCount)) {
      _isGroup = isGroup;
      _roomTitle = result.roomTitle;
      _roomAvatarUrl = result.roomAvatarUrl;
      _memberCount = result.memberCount;
      changed = true;
    }
    if (changed) _syncMentionCandidates();
    return changed;
  }

  void _revealUnread() {
    final id = _unreadFromId;
    if (id == null) return;
    final index = _messages.indexWhere((m) => m.messageId == id);
    if (index < 0 || _messages.length - index < 8) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEntry(_keyFor(_messages[index]), flash: false, alignment: 0.9));
  }

  Future<bool> _scrollToEntry(String entryId, {bool flash = true, double alignment = 0.5}) async {
    final target = _keyIndex[entryId];
    if (target == null || !_scroll.hasClients) return false;
    for (var attempt = 0; attempt < 60 && mounted; attempt++) {
      final ctx = _anchors[entryId];
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(ctx, alignment: alignment, duration: Motion.enter, curve: Motion.emphasized);
        if (flash && mounted) {
          _highlight.value = entryId;
          Timer(const Duration(milliseconds: 1400), () {
            if (mounted && _highlight.value == entryId) _highlight.value = null;
          });
        }
        return true;
      }
      final visible = _anchors.keys.map((k) => _keyIndex[k]).whereType<int>().toList();
      if (visible.isEmpty) return false;
      final older = target < visible.reduce(math.min);
      final p = _scroll.position;
      final next = (p.pixels + (older ? 1 : -1) * p.viewportDimension * 0.8).clamp(p.minScrollExtent, p.maxScrollExtent);
      if ((next - p.pixels).abs() < 1) return false;
      _scroll.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
    }
    return false;
  }

  Future<void> _jumpToMessage(int messageId) async {
    FocusScope.of(context).unfocus();
    var pages = 0;
    while (!_ids.contains(messageId) && _hasMore && pages < 10 && mounted) {
      final before = _messages.length;
      await _loadOlder();
      if (_messages.length == before) break;
      pages++;
    }
    if (!mounted) return;
    final index = _messages.indexWhere((m) => m.messageId == messageId);
    final found = index >= 0 && await _scrollToEntry(_keyFor(_messages[index]));
    if (found || !mounted) return;
    final beforeHistory = _messages.isNotEmpty && messageId < _messages.first.messageId && !_hasMore;
    showAppSnackBar(context, beforeHistory ? S.originalMessageUnavailable : S.originalMessageNotFound, isError: !beforeHistory);
  }

  String _nameOf(int userId, {String fallback = ''}) {
    if (userId == _myId) return S.you2;
    final alias = _aliases[userId];
    if (alias != null && alias.isNotEmpty) return alias;
    final partner = _partner;
    if (!_isGroup && partner != null && partner.userId == userId && partner.displayName.isNotEmpty) {
      return partner.displayName;
    }
    final member = _members[userId];
    if (member != null) return member.displayName;
    final sender = _senderNames[userId];
    if (sender != null && sender.isNotEmpty) return sender;
    if (fallback.isNotEmpty) return fallback;
    if (!_isGroup && widget.partnerName.isNotEmpty) return widget.partnerName;
    return S.user;
  }

  String? _avatarOf(int userId) {
    final partner = _partner;
    if (!_isGroup && partner != null && partner.userId == userId) return partner.avatarUrl;
    return _members[userId]?.avatarUrl ?? _senderAvatars[userId];
  }

  String get _title {
    if (_isGroup) return _roomTitle.isNotEmpty ? _roomTitle : S.chat;
    final partner = _partner;
    if (partner != null && partner.userId != 0) return _nameOf(partner.userId);
    if (_roomTitle.isNotEmpty) return _roomTitle;
    return widget.partnerName.isEmpty ? S.chat : widget.partnerName;
  }

  bool get _canCompose => !_loading && !_loadError && !_partnerUnavailable && !_blocked;

  void _startReply(ChatMessage m) {
    if (!_canCompose || m.isRecalled || m.messageId <= 0) return;
    if (_editing != null) _cancelEdit();
    HapticFeedback.selectionClick();
    setState(() => _replyTo = ChatReply.of(m, senderName: _nameOf(m.senderId, fallback: m.senderName)));
    _focus.requestFocus();
  }

  ChatReply? _takeReply() {
    final reply = _replyTo;
    if (reply != null) setState(() => _replyTo = null);
    return reply;
  }

  bool _canEdit(ChatMessage m) {
    final created = m.createdAt;
    return m.senderId == _myId &&
        m.kind == 'text' &&
        m.messageId > 0 &&
        created != null &&
        DateTime.now().difference(created) < _editWindow;
  }

  void _startEdit(ChatMessage m) {
    if (!_canCompose || !_canEdit(m)) return;
    HapticFeedback.selectionClick();
    final text = m.text;
    setState(() {
      if (_editing == null) {
        _draftBeforeEdit = _controller.text;
        _draftMentionsBeforeEdit = _mentions.mentions;
      }
      _editing = m;
      _replyTo = null;
      _quickRepliesOpen = false;
    });
    _stopTyping();
    _controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    _mentions.setMentions(m.mentions);
    _focus.requestFocus();
  }

  void _cancelEdit() {
    if (_editing == null) return;
    final draft = _draftBeforeEdit;
    _controller.value = TextEditingValue(text: draft, selection: TextSelection.collapsed(offset: draft.length));
    _mentions.setMentions(_draftMentionsBeforeEdit);
    setState(() {
      _editing = null;
      _draftBeforeEdit = '';
      _draftMentionsBeforeEdit = const [];
    });
  }

  Future<void> _submitEdit(String raw) async {
    final target = _editing;
    if (target == null) return;
    final (:text, :mentions) = _mentions.take(raw);
    if (text.isEmpty) return;
    if (text.length > 2000) {
      showAppSnackBar(context, S.messagesCanUp2000Characters, isError: true);
      return;
    }
    final index = _messages.indexWhere((m) => m.messageId == target.messageId);
    if (index < 0 || _messages[index].isRecalled) {
      _cancelEdit();
      return;
    }
    final original = _messages[index];
    if (text == original.text.trim() && listEquals(mentions, original.mentions)) {
      _cancelEdit();
      return;
    }
    if (!_canEdit(original)) {
      showAppSnackBar(context, S.canOnlyEditMessagesSentWithin, isError: true);
      _cancelEdit();
      return;
    }

    HapticFeedback.lightImpact();
    final optimistic = original.copyWith(body: text, editedAt: DateTime.now().toUtc(), mentions: mentions);
    _cancelEdit();
    setState(() {
      _messages[index] = optimistic;
      _rebuildEntries();
    });

    final (updated, error) = await _api.editChatMessage(widget.roomId, target.messageId, text, mentions: mentions);
    if (!mounted) return;
    final i = _messages.indexWhere((m) => m.messageId == target.messageId);
    if (i < 0) return;
    if (updated == null) {
      if (identical(_messages[i], optimistic)) {
        setState(() {
          _messages[i] = original;
          _rebuildEntries();
        });
      }
      showAppSnackBar(context, error ?? S.actionFailed, isError: true);
      if (_editing == null && _replyTo == null && _controller.text.trim().isEmpty && _canEdit(original)) {
        _startEdit(original);
        _controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
        _mentions.setMentions(mentions);
      }
      return;
    }
    if (_messages[i].isRecalled) return;
    setState(() {
      _messages[i] = _messages[i].copyWith(
        body: updated.text.isEmpty ? text : updated.text,
        editedAt: updated.editedAt ?? optimistic.editedAt,
        mentions: updated.text.isEmpty ? mentions : updated.mentions,
      );
      _rebuildEntries();
    });
  }

  void _fillViewportWithOlder() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasMore || !_scroll.hasClients) return;
      final p = _scroll.position;
      if (p.maxScrollExtent - p.pixels < 600) _loadOlder();
    });
  }

  void _close() {
    _pollTimer?.cancel();
    final onClose = widget.onClose;
    onClose != null ? onClose() : Navigator.of(context).maybePop();
  }

  Future<void> _poll({bool force = false}) async {
    if (_polling || _loading || _loadError || !mounted) return;
    if (!force && ModalRoute.isCurrentOf(context) == false) return;
    _polling = true;

    try {
      final afterId = _messages.isEmpty ? 0 : _messages.last.messageId;
      final result = await _api.fetchChatMessages(widget.roomId, afterId: afterId, limit: 100);
      if (!mounted) return;

      if (!result.ok && (result.status == 404 || result.status == 403)) {
        _pollTimer?.cancel();
        showAppSnackBar(context, result.error ?? S.chatNotFound, isError: true);
        _close();
        return;
      }
      if (!result.ok) {
        _failures++;
        if (_failures >= 2 && !_offline) setState(() => _offline = true);
        return;
      }
      _failures = 0;
      _applyIncoming(result);
    } finally {
      _polling = false;
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _loading || _messages.isEmpty) return;
    if (DateTime.now().difference(_olderFailedAt) < const Duration(seconds: 5)) return;
    _loadingOlder = true;
    setState(() {});

    final result = await _api.fetchChatMessages(widget.roomId, beforeId: _messages.first.messageId, limit: _pageSize);
    if (!mounted) return;

    setState(() {
      _loadingOlder = false;
      if (!result.ok) {
        _olderFailedAt = DateTime.now();
        return;
      }
      _hasMore = result.hasMore;
      _mergeMessages(result.messages);
      if (result.readUpto > _readUpto) _readUpto = result.readUpto;
      _mergeReservations(result.reservations);
      _mergeTransfers(result.transfers);
      _rebuildEntries();
    });
    if (result.ok) _fillViewportWithOlder();
  }

  void _applyIncoming(ChatFetchResult result) {
    final atBottom = _isAtBottom;
    final settled = !_scroll.hasClients || !_scroll.position.isScrollingNotifier.value;
    var changed = false;

    if (_offline) {
      _offline = false;
      changed = true;
    }

    final partner = result.partner;
    if (partner.userId != 0 &&
        (_partner?.userId != partner.userId ||
            _partner?.nickname != partner.nickname ||
            _partner?.alias != partner.alias ||
            _partner?.avatarUrl != partner.avatarUrl)) {
      _partner = partner;
      changed = true;
    }

    if (result.readUpto > _readUpto) {
      _readUpto = result.readUpto;
      changed = true;
    }

    if (_applyRoom(result)) changed = true;
    if (!_updatingControls && _applyControls(result)) changed = true;

    for (final id in result.recalledIds) {
      if (!_ids.contains(id)) continue;
      final i = _messages.indexWhere((m) => m.messageId == id);
      if (i < 0 || _messages[i].isRecalled) continue;
      final url = _messages[i].voice?.url;
      if (url != null && VoicePlayback.instance.isActive(url)) VoicePlayback.instance.stop();
      _messages[i] = _messages[i].copyWith(kind: 'recalled');
      if (_editing?.messageId == id) _cancelEdit();
      changed = true;
    }

    for (final edit in result.edited) {
      if (!_ids.contains(edit.messageId)) continue;
      final i = _messages.indexWhere((m) => m.messageId == edit.messageId);
      if (i < 0) continue;
      final m = _messages[i];
      final sameMentions = edit.mentions == null || listEquals(edit.mentions, m.mentions);
      if (m.isRecalled || (m.isEdited && m.text == edit.body && sameMentions)) continue;
      _messages[i] = m.copyWith(
        body: edit.body,
        editedAt: edit.editedAt ?? DateTime.now().toUtc(),
        mentions: edit.mentions,
      );
      changed = true;
    }

    if (_mergeReservations(result.reservations)) changed = true;
    if (_mergeTransfers(result.transfers)) changed = true;

    final fresh = result.messages.where((m) => m.messageId > 0 && !_ids.contains(m.messageId)).toList();
    if (fresh.isNotEmpty) {
      _mergeMessages(fresh);
      final keys = [for (final m in fresh) _keyFor(m)];
      _markFresh(keys);
      if (!atBottom) {
        final fromOthers = fresh.where((m) => m.senderId != _myId).length;
        if (fromOthers > 0) _unseen.value += fromOthers;
      }
      changed = true;
    }

    if (changed) {
      setState(() {
        if (atBottom && settled) _repivot();
        _rebuildEntries();
      });
    }
    _setTyping(_typingFrom(result));

    if (fresh.isNotEmpty) {
      if (atBottom && settled) _settleToBottom();
      if (fresh.any((m) => m.kind == 'book')) _refreshReservable();
      if (fresh.any((m) => m.senderId != _myId)) _api.fetchUnreadChatCount();
    }
  }

  List<int> _typingFrom(ChatFetchResult result) {
    if (_blocked || _partnerUnavailable) return const [];
    if (result.roomType == 'group' || _isGroup) {
      return result.typingUserIds.where((id) => id != _myId).toList();
    }
    final partnerId = result.partner.userId != 0 ? result.partner.userId : (_partner?.userId ?? 0);
    return result.partnerTyping && partnerId != 0 ? [partnerId] : const [];
  }

  void _setTyping(List<int> ids) {
    if (!listEquals(_typingIds.value, ids)) _typingIds.value = ids;
    _syncTypingRow();
  }

  void _syncTypingRow() {
    final wanted = _typingIds.value.isNotEmpty && !_hasNewer;
    final shown = _typingVisibility.value.shown;
    if (wanted == shown) return;
    if (wanted) {
      if (_isAtBottom) _typingVisibility.value = (shown: true, animate: true);
      return;
    }
    if (_isAtBottom || !_scroll.hasClients) {
      _typingVisibility.value = (shown: false, animate: true);
      return;
    }
    // 輸入中列位於清單最底端；使用者往上捲時直接移除會讓畫面內容跳動，須同步扣回捲動位置。
    final height = _typingKey.currentContext?.size?.height ?? 0;
    final p = _scroll.position;
    if (height > 0) p.correctPixels(math.max(p.minScrollExtent, p.pixels - height));
    _typingVisibility.value = (shown: false, animate: false);
  }

  bool _applyControls(ChatFetchResult result) {
    final unavailable = !result.canSend && !result.blocked;
    if (_muted == result.muted && _blocked == result.blocked && _partnerUnavailable == unavailable) return false;
    _muted = result.muted;
    _blocked = result.blocked;
    _partnerUnavailable = unavailable;
    if (_blocked || _partnerUnavailable) {
      _typingIds.value = const [];
      _editing = null;
    }
    return true;
  }

  Future<void> _openSettings() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<ChatRoomSettingsResult>(
      context,
      MaterialPageRoute(builder: (_) => ChatRoomSettingsScreen(roomId: widget.roomId)),
    );
    if (!mounted) return;
    if (result == ChatRoomSettingsResult.left) {
      _close();
      return;
    }
    if (_loadError) {
      _load();
      return;
    }
    if (_isGroup) _loadRoomInfo();
    _poll(force: true);
  }

  Future<void> _unblock() async {
    final partner = _partner;
    if (partner == null || partner.userId == 0) return;
    setState(() => _updatingControls = true);
    final error = await _api.setUserBlocked(partner.userId, false);
    if (!mounted) return;
    setState(() {
      _updatingControls = false;
      if (error == null) _blocked = false;
    });
    showAppSnackBar(context, error ?? S.userUnblocked, isError: error != null);
    if (error == null) _poll(force: true);
  }

  bool _mergeReservations(Map<int, ChatReservation> incoming) {
    var changed = false;
    incoming.forEach((id, next) {
      final current = _reservations[id];
      if (current == null ||
          current.status != next.status ||
          current.isHolding != next.isHolding ||
          current.pickupDeadline != next.pickupDeadline ||
          current.bookStatus != next.bookStatus) {
        _reservations[id] = next;
        changed = true;
      }
    });
    return changed;
  }

  bool _mergeTransfers(Map<int, ChatTransfer> incoming) {
    var changed = false;
    incoming.forEach((id, next) {
      final current = _transfers[id];
      if (current == null ||
          current.status != next.status ||
          current.respondedAt != next.respondedAt ||
          current.expiresAt != next.expiresAt) {
        _transfers[id] = next;
        changed = true;
      }
    });
    return changed;
  }

  void _mergeMessages(Iterable<ChatMessage> incoming) {
    var needsSort = false;
    for (final m in incoming) {
      if (m.messageId <= 0) continue;
      if (m.senderId != _myId) {
        if (m.senderName.isNotEmpty) _senderNames[m.senderId] = m.senderName;
        final avatar = m.senderAvatarUrl;
        if (avatar != null && avatar.isNotEmpty) _senderAvatars[m.senderId] = avatar;
      }
      if (_ids.contains(m.messageId)) {
        final i = _messages.indexWhere((x) => x.messageId == m.messageId);
        if (i >= 0) _messages[i] = m;
        continue;
      }
      if (_messages.isNotEmpty && m.messageId < _messages.last.messageId) needsSort = true;
      _messages.add(m);
      _ids.add(m.messageId);
    }
    if (needsSort) _messages.sort((a, b) => a.messageId.compareTo(b.messageId));
  }

  String _keyFor(ChatMessage m) => _clientKeys[m.messageId] ?? 'm${m.messageId}';

  void _markFresh(Iterable<String> keys) {
    final list = keys.toList();
    _fresh.addAll(list);
    Timer(const Duration(milliseconds: 800), () => _fresh.removeAll(list));
  }

  void _repivot({bool force = false}) {
    if (_messages.isEmpty) return;
    final newest = _messages.last.messageId;
    if (_pivotId == newest) return;
    if (_scroll.hasClients) {
      final p = _scroll.position;
      if (p.minScrollExtent < 0) {
        if (p.isScrollingNotifier.value && !force) return;
        p.correctPixels(math.max(0, p.pixels - p.minScrollExtent));
      }
    }
    _pivotId = newest;
  }

  void _enqueue(ChatPendingMessage p) {
    _sendQueue = _sendQueue.then((_) => _deliver(p)).catchError((Object _) => _failPending(p, null));
  }

  void _rebuildEntries() {
    final entries = <ChatEntry>[
      for (final m in _messages) ChatEntry.message(_keyFor(m), m),
      for (final p in _pending) ChatEntry.pending(p),
    ];
    final newer = _messages.where((m) => m.messageId > _pivotId).length;
    _baseCount = newer == 0 ? entries.length : _messages.length - newer;
    _entries = entries;
    _keyIndex = {for (var i = 0; i < entries.length; i++) entries[i].id: i};
  }

  void _settleToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final p = _scroll.position;
      if (p.pixels - p.minScrollExtent > 1) {
        _scroll.animateTo(p.minScrollExtent, duration: Motion.base, curve: Motion.enterCurve);
      }
    });
  }

  Future<void> _jumpToBottom() async {
    if (!_scroll.hasClients) return;
    HapticFeedback.selectionClick();
    for (var attempt = 0; attempt < 3; attempt++) {
      final p = _scroll.position;
      final distance = p.pixels - p.minScrollExtent;
      if (distance <= 1) break;
      if (distance > p.viewportDimension * 3) {
        _scroll.jumpTo(p.minScrollExtent + p.viewportDimension);
      }
      await _scroll.animateTo(_scroll.position.minScrollExtent, duration: Motion.enter, curve: Motion.emphasized);
      if (!mounted) return;
    }
    _unseen.value = 0;
    _repivotWhenSettled();
  }

  void _repivotWhenSettled() {
    if (!mounted || !_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.isScrollingNotifier.value || p.pixels - p.minScrollExtent > 4) return;
    if (_hasNewer) {
      setState(() {
        _repivot();
        _rebuildEntries();
      });
    }
    _syncTypingRow();
  }

  void _onScroll() {
    final p = _scroll.position;
    final fromBottom = p.pixels - p.minScrollExtent;
    _showJump.value = fromBottom > 320;
    if (fromBottom < 40) {
      if (_unseen.value != 0) _unseen.value = 0;
      if (_typingIds.value.isNotEmpty && !_typingVisibility.value.shown) _syncTypingRow();
    }
    if (p.maxScrollExtent - p.pixels < 600) _loadOlder();
  }

  void _onTextChanged() {
    if (_editing != null) return;
    if (_controller.text.trim().isEmpty) {
      _stopTyping();
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastTypingPing) < _typingInterval) return;
    _lastTypingPing = now;
    _typingSent = true;
    _api.sendTyping(widget.roomId);
  }

  void _stopTyping() {
    if (!_typingSent) return;
    _typingSent = false;
    _lastTypingPing = DateTime(0);
    _api.sendTyping(widget.roomId, typing: false);
  }

  Future<void> _refreshReservable() async {
    if (_isGroup) return;
    final partnerId = _partner?.userId ?? 0;
    if (partnerId == 0) return;

    ChatBookCard? card;
    for (final m in _messages.reversed) {
      if (m.kind == 'book') {
        card = m.bookCard;
        break;
      }
    }
    if (card == null || card.bookId == _checkedBookId) return;
    _checkedBookId = card.bookId;

    final book = await _api.fetchBookDetail(card.bookId);
    if (!mounted) return;
    final eligible = book != null &&
        book.sellerId == partnerId &&
        book.status == 'on_sale' &&
        (book.reservedUntil == null || book.reservedForMe);
    setState(() => _reserveBook = eligible ? book : null);
  }

  bool get _canReserve {
    final book = _reserveBook;
    if (_isGroup || book == null || _partnerUnavailable || _blocked) return false;
    return !_reservations.values.any((r) =>
        r.bookId == book.bookId &&
        r.buyerId == _myId &&
        ((r.isPending && (r.createdAt == null || DateTime.now().difference(r.createdAt!) < const Duration(hours: 24))) ||
            r.isConfirmed));
  }

  bool get _canTransfer => _canCompose && !_offline && (_isGroup || (_partner?.userId ?? 0) != 0);

  void _addPending(ChatPendingMessage p) {
    _stopTyping();
    setState(() {
      _quickRepliesOpen = false;
      _repivot(force: true);
      _pending.add(p);
      _markFresh([p.key]);
      _rebuildEntries();
    });
    _jumpNearBottom();
    _settleToBottom();
    _enqueue(p);
  }

  void _jumpNearBottom() {
    if (!_scroll.hasClients) return;
    final distance = _scroll.position.pixels - _scroll.position.minScrollExtent;
    if (distance > _scroll.position.viewportDimension * 3) _scroll.jumpTo(0);
  }

  String _nextKey() => 'p${++_pendingSeq}';

  void _onSend(String raw) {
    if (_editing != null) {
      _submitEdit(raw);
    } else {
      _sendText(raw, fromComposer: true);
    }
  }

  void _sendText(String raw, {bool fromComposer = false}) {
    final (:text, :mentions) = fromComposer ? _mentions.take(raw) : (text: raw.trim(), mentions: const <ChatMention>[]);
    if (text.isEmpty) return;
    if (text.length > 2000) {
      showAppSnackBar(context, S.messagesCanUp2000Characters, isError: true);
      return;
    }
    HapticFeedback.lightImpact();
    if (fromComposer) {
      _controller.clear();
      _mentions.clear();
    }
    _unreadFromId = null;
    _addPending(ChatPendingMessage(key: _nextKey(), kind: 'text', text: text, replyTo: _takeReply(), mentions: mentions));
  }

  Future<void> _deliver(ChatPendingMessage p) async {
    if (!_pending.contains(p)) return;

    Object content = p.text;
    if (p.slots.isNotEmpty) {
      final uploadError = await uploadChatSlots(_api, p.slots);
      if (uploadError != null) return _failPending(p, uploadError);
      final urls = [for (final slot in p.slots) slot.url!];
      content = p.kind == 'album' ? urls : urls.first;
    } else if (p.kind != 'text') {
      var url = p.uploadedUrl;
      if (url == null) {
        final (uploaded, error) = await _api.uploadVoice(p.localPath!);
        if (uploaded == null) return _failPending(p, error);
        url = p.uploadedUrl = uploaded;
      }
      content = url;
    }

    final (message, error) = await _api.sendChatMessage(
      widget.roomId,
      content,
      type: p.kind,
      durationSeconds: p.kind == 'voice' ? p.seconds : null,
      replyToId: p.replyTo?.messageId,
      mentions: p.mentions,
    );
    if (message == null) return _failPending(p, error);

    _clientKeys[message.messageId] = p.key;
    if (p.kind == 'image' && p.localPath != null) _localImages[message.messageId] = p.localPath!;
    if (p.kind == 'album') _localAlbums[message.messageId] = [for (final slot in p.slots) slot.localPath];
    if (p.kind == 'voice') VoiceRecorder.deleteFile(p.localPath);
    if (!mounted) return;

    final atBottom = _isAtBottom;
    setState(() {
      _pending.remove(p);
      _mergeMessages([message]);
      if (atBottom) _repivot();
      _rebuildEntries();
    });
  }

  void _insertSentMessage(ChatMessage message) {
    final transfer = message.transfer;
    setState(() {
      if (transfer != null) _transfers[transfer.transferId] = transfer;
      _quickRepliesOpen = false;
      _mergeMessages([message]);
      _markFresh([_keyFor(message)]);
      _repivot(force: true);
      _rebuildEntries();
    });
    _jumpNearBottom();
    _settleToBottom();
  }

  void _failPending(ChatPendingMessage p, String? error) {
    if (!mounted || !_pending.contains(p)) return;
    final message = error ?? S.messageCouldNotSent;
    setState(() {
      p.state = ChatSendState.failed;
      if (message.contains(_unreachableMarker)) _partnerUnavailable = true;
      _rebuildEntries();
    });
    showAppSnackBar(context, message, isError: true);
  }

  void _retryPending(ChatPendingMessage p) {
    if (_offline || _partnerUnavailable) {
      showAppSnackBar(context, S.canTSendRightNowPlease, isError: true);
      return;
    }
    setState(() {
      p.state = ChatSendState.sending;
      _rebuildEntries();
    });
    _enqueue(p);
  }

  void _discardPending(ChatPendingMessage p) {
    if (p.kind == 'voice') VoiceRecorder.deleteFile(p.localPath);
    setState(() {
      _pending.remove(p);
      _rebuildEntries();
    });
  }

  Future<void> _openAttachSheet() async {
    if (_editing != null) _cancelEdit();
    FocusScope.of(context).unfocus();
    final choice = await showChatAttachSheet(context, canReserve: _canReserve, canTransfer: _canTransfer);
    if (!mounted || choice == null) return;

    switch (choice) {
      case ChatAttachChoice.camera:
        _pickImages(ImageSource.camera);
      case ChatAttachChoice.gallery:
        _pickImages(ImageSource.gallery);
      case ChatAttachChoice.transfer:
        _startTransfer(request: false);
      case ChatAttachChoice.request:
        _startTransfer(request: true);
      case ChatAttachChoice.reserve:
        _requestReservation();
      case ChatAttachChoice.quickReplies:
        setState(() => _quickRepliesOpen = true);
    }
  }

  Future<void> _pickImages(ImageSource source) async {
    final picker = ImagePicker();
    List<XFile> files;
    try {
      if (source == ImageSource.camera) {
        final shot = await picker.pickImage(source: source, maxWidth: 2048, maxHeight: 2048, imageQuality: 85);
        files = shot == null ? const [] : [shot];
      } else {
        files = await picker.pickMultiImage(maxWidth: 2048, maxHeight: 2048, imageQuality: 85, limit: 9);
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          source == ImageSource.camera ? S.couldNotOpenCameraCheckPermission : S.couldNotOpenPhotosCheckPermission,
          isError: true,
        );
      }
      return;
    }
    if (!mounted) return;

    final sized = [
      for (final file in files.take(kChatAlbumMax))
        (path: file.path, bytes: await File(file.path).length().catchError((_) => -1)),
    ];
    if (!mounted) return;
    final (:groups, :skipped) = groupImagesForSend(sized);
    for (final paths in groups) {
      _addPending(ChatPendingMessage.images(key: _nextKey(), paths: paths, replyTo: _takeReply()));
    }
    if (skipped > 0) showAppSnackBar(context, S.imagesMust10MbSmaller, isError: true);
  }

  void _sendVoice(VoiceClip clip) {
    final size = File(clip.path).existsSync() ? File(clip.path).lengthSync() : 0;
    if (size == 0) {
      showAppSnackBar(context, S.recordingFailedPleaseTryAgain, isError: true);
      return;
    }
    if (size > 5 * 1024 * 1024) {
      VoiceRecorder.deleteFile(clip.path);
      showAppSnackBar(context, S.voiceMessageTooLargePleaseRecord, isError: true);
      return;
    }
    if (_editing != null) _cancelEdit();
    _addPending(ChatPendingMessage(key: _nextKey(), kind: 'voice', localPath: clip.path, seconds: clip.seconds, replyTo: _takeReply()));
  }

  void _onVoiceUnavailable(VoiceStartResult result) {
    if (result == VoiceStartResult.permissionGranted) {
      showAppSnackBar(context, S.microphoneAllowedPressHoldAgainRecord);
    } else if (result == VoiceStartResult.denied) {
      showAppSnackBar(context, S.microphoneAccessNeededRecordTurnSettings, isError: true);
    } else if (result == VoiceStartResult.failed) {
      showAppSnackBar(context, S.couldnTStartRecordingPleaseTry, isError: true);
    }
  }

  Future<void> _showMessageMenu(ChatEntry entry) async {
    final pending = entry.pending;
    if (pending != null) {
      if (pending.state == ChatSendState.failed) _showPendingMenu(pending);
      return;
    }
    final m = entry.message!;
    if (m.isRecalled || !_replyableKinds.contains(m.kind)) return;

    final isMine = m.senderId == _myId;
    final created = m.createdAt;
    final canReply = _canCompose;
    final isText = m.kind == 'text';
    final images = m.imageUrls;
    final canEdit = _canCompose && _canEdit(m);
    final canRecall = isMine && created != null && DateTime.now().difference(created) < _recallWindow;
    final canReport = !isMine;

    HapticFeedback.mediumImpact();
    final preview = m.preview.replaceAll('\n', ' ');
    final choice = await showOptionSheet<String>(
      context,
      title: preview.length > 40 ? '${preview.substring(0, 40)}…' : preview,
      options: [
        if (canReply) SheetOption(value: 'reply', label: S.reply, icon: Icons.reply_rounded),
        if (isText) SheetOption(value: 'copy', label: S.copy, icon: Icons.copy_rounded),
        if (isText) SheetOption(value: 'select', label: S.selectText, icon: Icons.text_fields_rounded),
        if (images.isNotEmpty) SheetOption(value: 'save', label: S.saveImage, icon: Icons.download_rounded),
        if (canEdit) SheetOption(value: 'edit', label: S.actionEdit, icon: Icons.edit_outlined),
        if (canRecall) SheetOption(value: 'recall', label: S.unsend, icon: Icons.undo_rounded),
        if (canReport)
          SheetOption(value: 'report', label: S.report, icon: Icons.flag_outlined, color: AppColors.of(context).danger),
      ],
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case 'reply':
        _startReply(m);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.text));
        if (!mounted) return;
        HapticFeedback.selectionClick();
        showAppSnackBar(context, S.messageCopied);
      case 'select':
        showChatSelectableTextSheet(context, m.text);
      case 'save':
        saveImagesWithFeedback(context, images, showProgressDialog: true);
      case 'edit':
        final current = _messages.where((x) => x.messageId == m.messageId).firstOrNull;
        if (current != null) _startEdit(current);
      case 'recall':
        _recall(m);
      case 'report':
        _report(m);
    }
  }

  Future<void> _showPendingMenu(ChatPendingMessage p) async {
    final choice = await showOptionSheet<String>(
      context,
      title: S.messageCouldNotSent,
      options: [
        SheetOption(value: 'retry', label: S.resend, icon: Icons.refresh_rounded),
        SheetOption(value: 'delete', label: S.actionDelete, icon: Icons.delete_outline_rounded, color: AppColors.of(context).danger),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == 'retry') {
      _retryPending(p);
    } else if (choice == 'delete') {
      _discardPending(p);
    }
  }

  Future<void> _recall(ChatMessage m) async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.unsendMessage,
      message: S.neitherAbleSeeMessageSContent,
      confirmLabel: S.unsend,
      isDestructive: true,
      icon: Icons.undo_rounded,
    );
    if (!confirmed || !mounted) return;

    final (updated, error) = await runBusy(context, () => _api.recallChatMessage(widget.roomId, m.messageId)) ??
        (null, S.actionFailed);
    if (!mounted) return;
    if (updated == null) {
      showAppSnackBar(context, error ?? S.actionFailed, isError: true);
      return;
    }
    final url = m.voice?.url;
    if (url != null && VoicePlayback.instance.isActive(url)) VoicePlayback.instance.stop();
    if (_editing?.messageId == m.messageId) _cancelEdit();
    setState(() {
      _mergeMessages([updated.kind == 'recalled' ? updated : m.copyWith(kind: 'recalled')]);
      _rebuildEntries();
    });
  }

  Future<void> _report(ChatMessage m) async {
    final reason = await showTextInputDialog(
      context,
      title: S.reportMessage,
      hint: S.describeProblemLeast5Characters,
      maxLines: 3,
      confirmLabel: S.actionSubmit,
    );
    if (reason == null || !mounted) return;
    if (reason.length < 5) {
      showAppSnackBar(context, S.reasonNeedsLeast5Characters, isError: true);
      return;
    }
    final error = await runBusy(
      context,
      () => _api.submitReport(targetType: 'message', targetId: m.messageId, reason: reason),
    );
    if (!mounted) return;
    showAppSnackBar(context, error ?? S.reportSubmittedWeLookInto, isError: error != null);
  }

  Future<void> _startTransfer({required bool request}) async {
    final candidates = await _transferCandidates();
    if (!mounted || candidates == null) return;
    final message = await startCoinTransfer(context, roomId: widget.roomId, request: request, candidates: candidates);
    if (!mounted || message == null) return;
    _insertSentMessage(message);
    _poll(force: true);
  }

  Future<List<ChatMember>?> _transferCandidates() async {
    if (!_isGroup) {
      final partner = _partner;
      if (partner == null || partner.userId == 0) return null;
      return [
        ChatMember(
          userId: partner.userId,
          nickname: partner.nickname,
          avatarUrl: partner.avatarUrl,
          alias: _aliases[partner.userId] ?? partner.alias,
        ),
      ];
    }
    var info = _roomInfo;
    if (info == null) {
      final (fetched, error) = await runBusy(context, () => _api.fetchChatRoomInfo(widget.roomId)) ?? (null, S.actionFailed);
      if (!mounted) return null;
      if (fetched == null) {
        showAppSnackBar(context, error ?? S.actionFailed, isError: true);
        return null;
      }
      setState(() => _setRoomInfo(fetched));
      info = fetched;
    }
    return info.members.where((m) => m.userId != _myId).toList();
  }

  Future<void> _onTransferAction(ChatTransfer t, TransferAction action) async {
    final id = t.transferId;
    if (_busyTransfers.contains(id)) return;
    final counterpart = t.fromUserId == _myId ? t.toUserId : t.fromUserId;
    setState(() => _busyTransfers.add(id));
    final updated = await respondToTransfer(context, transfer: t, action: action, counterpartName: _nameOf(counterpart));
    if (!mounted) return;
    setState(() {
      _busyTransfers.remove(id);
      if (updated != null) _transfers[updated.transferId] = updated;
    });
    if (updated == null) _poll(force: true);
  }

  Future<void> _requestReservation() async {
    final book = _reserveBook;
    if (book == null) return;
    final request = await showReservationRequestSheet(
      context,
      title: book.title,
      price: book.price,
      imageUrl: book.imageUrl.isEmpty ? null : book.imageUrl,
    );
    if (request == null || !mounted) return;

    final (reservation, error) = await runBusy(
          context,
          () => _api.requestReservation(widget.roomId, bookId: book.bookId, hours: request.hours, message: request.note),
        ) ??
        (null, S.actionFailed);
    if (!mounted) return;

    if (reservation == null) {
      showAppSnackBar(context, error ?? S.actionFailed, isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _reservations[reservation.reservationId] = reservation);
    showAppSnackBar(context, S.reservationSentWaitingSeller);
    _poll(force: true);
  }

  Future<void> _onReservationAction(ChatReservation r, ReservationAction action) async {
    if (action == ReservationAction.buy) return _buyReserved(r);

    final String title;
    final String? message;
    final String confirmLabel;
    final bool destructive;
    final String apiAction;
    final String done;
    if (action == ReservationAction.accept) {
      title = S.acceptReservation;
      message = S.p0HeldThemP1HoursNo(r.bookTitle, r.hours);
      confirmLabel = S.accept;
      destructive = false;
      apiAction = 'accept';
      done = S.reservationAccepted;
    } else if (action == ReservationAction.decline) {
      title = S.declineReservation;
      message = null;
      confirmLabel = S.decline2;
      destructive = true;
      apiAction = 'decline';
      done = S.reservationDeclined;
    } else {
      title = S.cancelReservation;
      message = S.p0NoLongerHeld(r.bookTitle);
      confirmLabel = S.cancelReservation2;
      destructive = true;
      apiAction = 'cancel';
      done = S.reservationCanceled;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: S.notNow2,
      isDestructive: destructive,
      icon: Icons.event_available_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyReservations.add(r.reservationId));
    final (updated, error) = await _api.respondReservation(r.reservationId, apiAction);
    if (!mounted) return;

    setState(() {
      _busyReservations.remove(r.reservationId);
      if (updated != null) _reservations[updated.reservationId] = updated;
    });
    if (updated == null) {
      showAppSnackBar(context, error ?? S.actionFailed, isError: true);
      _poll(force: true);
      return;
    }
    HapticFeedback.selectionClick();
    showAppSnackBar(context, done);
    if (updated.buyerId == _myId) {
      _checkedBookId = null;
      _refreshReservable();
    }
  }

  Future<void> _buyReserved(ChatReservation r) async {
    final error = await runBusy(context, () => _api.addToCart(r.bookId));
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  Future<void> _openBook(int bookId) async {
    final book = await runBusy(context, () => _api.fetchBookDetail(bookId));
    if (!mounted) return;
    if (book == null) {
      showAppSnackBar(context, S.bookNoLongerListed, isError: true);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)));
  }

  void _openProfile(int userId) {
    if (userId == 0 || userId == _myId) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerScreen(
          sellerId: userId,
          sellerName: _nameOf(userId),
          sellerAvatarUrl: _avatarOf(userId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final inputEnabled = !_loading && !_loadError && !_offline && !_partnerUnavailable && !_blocked;
    final partner = _partner;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          ChatRoomHeader(
            title: _title,
            isGroup: _isGroup,
            avatarUrl: _isGroup ? _roomAvatarUrl : partner?.avatarUrl,
            showAvatar: _isGroup || (partner != null && partner.userId != 0),
            memberCount: _memberCount,
            muted: _muted,
            showBack: !widget.embedded,
            onOpenSettings: _loading ? null : _openSettings,
          ),
          Expanded(
            child: SwitchIn(
              child: _loading
                  ? const LoadingView(key: ValueKey('loading'))
                  : _loadError
                      ? EmptyView(
                          key: const ValueKey('error'),
                          icon: Icons.cloud_off_rounded,
                          message: S.couldnTLoadConversationPleaseTry,
                          actionLabel: S.reload,
                          onAction: _load,
                        )
                      : KeyedSubtree(key: const ValueKey('list'), child: _buildConversation()),
            ),
          ),
          ChatInputBar(
            controller: _controller,
            focusNode: _focus,
            enabled: inputEnabled,
            disabledHint: _blocked
                ? S.blockedUser
                : _partnerUnavailable
                    ? S.accountCanTReceiveMessagesRight
                    : null,
            top: _buildInputTop(c),
            quickRepliesOpen: _quickRepliesOpen,
            onSend: _onSend,
            onAttach: _openAttachSheet,
            onToggleQuickReplies: () => setState(() => _quickRepliesOpen = !_quickRepliesOpen),
            onVoice: _sendVoice,
            onVoiceUnavailable: _onVoiceUnavailable,
            onVoiceTooShort: () => showAppSnackBar(context, S.holdMicTalkReleaseSend),
            mentions: _isGroup ? _mentions : null,
          ),
        ],
      ),
    );
  }

  Widget _buildConversation() {
    final newerCount = _entries.length - _baseCount;

    return Stack(
      children: [
        NotificationListener<ScrollEndNotification>(
          onNotification: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _repivotWhenSettled());
            return false;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: CustomScrollView(
              controller: _scroll,
              reverse: true,
              center: _centerKey,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildRow(_baseCount + i),
                    childCount: newerCount,
                    findChildIndexCallback: (key) {
                      final index = key is ValueKey<String> ? _keyIndex[key.value] : null;
                      if (index == null || index < _baseCount) return null;
                      return index - _baseCount;
                    },
                  ),
                ),
                SliverList(
                  key: _centerKey,
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => i == 0 ? _buildTypingRow() : _buildRow(_baseCount - i),
                    childCount: _baseCount + 1,
                    findChildIndexCallback: (key) {
                      if (key == _typingKey) return 0;
                      final index = key is ValueKey<String> ? _keyIndex[key.value] : null;
                      if (index == null || index >= _baseCount) return null;
                      return _baseCount - index;
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: _entries.isEmpty ? const SizedBox.shrink() : ChatHistoryHead(loading: _hasMore || _loadingOlder),
                ),
              ],
            ),
          ),
        ),
        if (_entries.isEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: EmptyView(icon: Icons.chat_bubble_outline_rounded, message: S.sendFirstMessage),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 10,
          child: ChatJumpToBottomButton(showJump: _showJump, unseen: _unseen, onTap: _jumpToBottom),
        ),
      ],
    );
  }

  Widget _buildTypingRow() {
    return ChatTypingRow(
      key: _typingKey,
      visibility: _typingVisibility,
      userIds: _typingIds,
      avatarOf: _avatarOf,
    );
  }

  Widget? _buildInputTop(AppColors c) {
    final children = <Widget>[];
    final editing = _editing;
    final reply = _replyTo;
    if (editing != null && _canCompose) {
      children.add(ChatEditComposer(
        key: ValueKey('edit_${editing.messageId}'),
        original: editing.text,
        onClose: _cancelEdit,
      ));
    } else if (reply != null && _canCompose) {
      children.add(ChatReplyComposer(
        key: ValueKey('reply_${reply.messageId}'),
        reply: reply,
        senderName: reply.senderName,
        onClose: () => setState(() => _replyTo = null),
      ));
    }

    if (_offline) {
      children.add(ChatStatusBanner(
        icon: Icons.wifi_off_rounded,
        text: S.connectionUnstableMessagesCanTSent,
        color: c.warning,
        actionLabel: S.retry,
        onAction: () => _poll(force: true),
      ));
    } else if (_blocked) {
      children.add(ChatStatusBanner(
        icon: Icons.block_rounded,
        text: S.blockedUser,
        color: c.danger,
        actionLabel: S.unblock,
        onAction: _updatingControls ? null : _unblock,
      ));
    } else if (_partnerUnavailable) {
      children.add(ChatStatusBanner(icon: Icons.block_rounded, text: S.accountCanTReceiveMessagesRight, color: c.danger));
    }

    final composing = _canCompose && editing == null;
    final hasConversation = _pending.isNotEmpty || _messages.any((m) => _replyableKinds.contains(m.kind));
    final showQuick = composing && (_quickRepliesOpen || (!hasConversation && !_isGroup));
    final quickReplies = [S.stillAvailable, S.couldLowerPriceBit, S.whenCanPutLocker];

    final chips = <Widget>[
      if (composing && _canReserve)
        ChatSuggestionChip(
          icon: Icons.event_available_rounded,
          label: S.reserveBook,
          highlighted: true,
          onTap: _requestReservation,
        ),
      if (showQuick)
        for (final reply in quickReplies)
          ChatSuggestionChip(
            label: reply,
            onTap: _offline ? null : () => _sendText(reply),
          ),
    ];

    if (chips.isNotEmpty) {
      children.add(ChatSuggestionStrip(chips: chips));
    }

    if (children.isEmpty) return null;
    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  bool _joins(ChatEntry? a, ChatEntry b) {
    if (a == null || a.isCentered || b.isCentered || a.senderId != b.senderId) return false;
    final x = a.createdAt;
    final y = b.createdAt;
    if (x == null || y == null) return true;
    return chatSameDay(x, y) && y.difference(x).abs() < const Duration(minutes: 5);
  }

  Widget _buildRow(int index) {
    final entry = _entries[index];
    final prev = index > 0 ? _entries[index - 1] : null;
    final next = index + 1 < _entries.length ? _entries[index + 1] : null;
    final created = entry.createdAt;
    final showDate = created != null && (prev == null || !chatSameDay(prev.createdAt, created));

    final Widget body;
    if (entry.isCentered) {
      body = _buildCentered(entry);
    } else {
      final groupStart = showDate || !_joins(prev, entry);
      final groupEnd = next == null || !_joins(entry, next);
      body = Padding(
        padding: EdgeInsets.only(top: groupStart ? 10 : 2),
        child: _buildBubbleRow(entry, next, groupStart, groupEnd),
      );
    }

    final showUnread = _unreadFromId != null && entry.message?.messageId == _unreadFromId;

    return KeyedSubtree(
      key: ValueKey<String>(entry.id),
      child: ChatRowAnchor(
        id: entry.id,
        anchors: _anchors,
        child: ChatEntrance(
          animate: _fresh.contains(entry.id),
          fromRight: entry.senderId == _myId,
          child: Padding(
            padding: EdgeInsets.only(bottom: next == null ? 14 : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showDate) ChatDateSeparator(date: created),
                if (showUnread) const ChatUnreadDivider(),
                ChatHighlightFlash(id: entry.id, highlight: _highlight, child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCentered(ChatEntry entry) {
    final m = entry.message!;
    final isMine = m.senderId == _myId;

    if (m.kind == 'recalled') {
      final name = _nameOf(m.senderId, fallback: m.senderName);
      return ChatSystemLine(
        text: isMine ? S.unsentMessage : (_isGroup ? S.p0UnsentMessage(name) : S.theyUnsentMessage),
        icon: Icons.undo_rounded,
      );
    }

    if (m.kind == 'book') {
      final card = m.bookCard;
      if (card == null) return const SizedBox.shrink();
      return ChatBookCardView(card: card, onTap: () => _openBook(card.bookId));
    }

    return ChatSystemLine(text: m.text);
  }

  Widget _buildBubbleRow(ChatEntry entry, ChatEntry? next, bool groupStart, bool groupEnd) {
    final c = AppColors.of(context);
    final isMine = entry.senderId == _myId;
    final width = MediaQuery.sizeOf(context).width;
    final isCard = entry.kind == 'reservation' || entry.kind == 'transfer';
    final maxBubble = isCard ? math.min(width * 0.78, 340.0) : math.min(width * 0.7, 420.0);
    final meta = _buildMeta(entry, next, isMine, groupEnd);
    final message = entry.message;
    final canSwipeReply =
        message != null && !message.isRecalled && message.messageId > 0 && _canCompose && _replyableKinds.contains(message.kind);

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxBubble),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: isCard ? null : () => _showMessageMenu(entry),
        child: _buildContent(entry, isMine, groupStart, groupEnd),
      ),
    );

    Widget line = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: isMine
          ? [
              if (meta != null) ...[meta, const SizedBox(width: 5)],
              Flexible(child: bubble),
            ]
          : [
              Flexible(child: bubble),
              if (meta != null) ...[const SizedBox(width: 5), meta],
            ],
    );

    final showName = !isMine && _isGroup && groupStart;
    if (showName) {
      line = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 3),
            child: Text(
              _nameOf(entry.senderId, fallback: message?.senderName ?? ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: c.textSecondary, height: 1.3),
            ),
          ),
          line,
        ],
      );
    }

    return SwipeToReply(
      onReply: canSwipeReply ? () => _startReply(message) : null,
      child: Padding(
        padding: EdgeInsets.only(left: isMine ? 40 : 10, right: isMine ? 12 : 28),
        child: Row(
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine) ...[
              SizedBox(
                width: 32,
                child: groupStart
                    ? UserAvatar(
                        imageUrl: _avatarOf(entry.senderId),
                        radius: 16,
                        onTap: () => _openProfile(entry.senderId),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(child: line),
          ],
        ),
      ),
    );
  }

  int _readCount(ChatMessage m) {
    if (m.messageId <= 0) return 0;
    if (!_isGroup) return _isRead(m) ? 1 : 0;
    var count = 0;
    for (final lastRead in _membersRead.values) {
      if (lastRead >= m.messageId) count++;
    }
    return count;
  }

  Widget? _buildMeta(ChatEntry entry, ChatEntry? next, bool isMine, bool groupEnd) {
    final pending = entry.pending;
    if (pending != null) {
      if (pending.state == ChatSendState.failed) return ChatSendFailedMark(onTap: () => _showPendingMenu(pending));
      return const ChatSendingLabel();
    }

    final m = entry.message!;
    final readCount = isMine ? _readCount(m) : 0;
    final nextMessage = next?.message;
    final sameAsNext = readCount > 0 &&
        next != null &&
        nextMessage != null &&
        nextMessage.senderId == _myId &&
        _joins(entry, next) &&
        _readCount(nextMessage) == readCount;
    final showRead = readCount > 0 && !sameAsNext;
    if (!groupEnd && !showRead && !m.isEdited) return null;

    return ChatMessageTime(
      createdAt: m.createdAt,
      isMine: isMine,
      readLabel: showRead ? (_isGroup ? S.readByP0(readCount) : S.read) : null,
      edited: m.isEdited && !m.isRecalled,
    );
  }

  Widget _buildContent(ChatEntry entry, bool isMine, bool groupStart, bool groupEnd) {
    final pending = entry.pending;
    final m = entry.message;
    final sending = pending?.state == ChatSendState.sending;
    final failed = pending?.state == ChatSendState.failed;
    final reply = entry.replyTo;

    ChatReplyQuote quote({bool divider = true}) => ChatReplyQuote(
          reply: reply!,
          senderName: _nameOf(reply.senderId, fallback: reply.senderName),
          isMine: isMine,
          divider: divider,
          onTap: () => _jumpToMessage(reply.messageId),
        );

    if (entry.kind == 'reservation' && m != null) {
      final id = m.reservationId ?? 0;
      var reservation = _reservations[id];
      final payload = m.payload;
      if (reservation == null && payload != null && payload['status'] != null) {
        reservation = ChatReservation.fromJson(payload);
      }
      if (reservation == null) {
        return ChatSystemLine(text: S.reservationDetailsArenTAvailableRight, icon: Icons.event_busy_rounded);
      }
      final r = reservation;
      return ReservationCardView(
        reservation: r,
        myId: _myId,
        isMine: isMine,
        groupStart: groupStart,
        groupEnd: groupEnd,
        busy: _busyReservations.contains(r.reservationId),
        onAction: (action) => _onReservationAction(r, action),
        onOpenBook: () => _openBook(r.bookId),
      );
    }

    if (entry.kind == 'transfer' && m != null) {
      final transfer = _transfers[m.transferId ?? 0] ?? m.transfer;
      if (transfer == null) {
        return ChatSystemLine(text: S.transferDetailsUnavailable, icon: Icons.payments_outlined);
      }
      final width = MediaQuery.sizeOf(context).width;
      return SizedBox(
        width: math.min(width * 0.64, 260.0),
        child: TransferCardView(
          transfer: transfer,
          myId: _myId,
          isMine: isMine,
          groupStart: groupStart,
          groupEnd: groupEnd,
          nameOf: _nameOf,
          busy: _busyTransfers.contains(transfer.transferId),
          onAction: (action) => _onTransferAction(transfer, action),
        ),
      );
    }

    if (entry.kind == 'image' || entry.kind == 'album') {
      final VoidCallback? onFailedTap = failed && pending != null ? () => _showPendingMenu(pending) : null;
      final Widget image;
      if (entry.kind == 'album') {
        final urls = m?.imageUrls ?? const <String>[];
        final heroPrefix = 'chat_album_${entry.id}';
        image = ChatAlbumView(
          key: ValueKey('album_${entry.id}'),
          urls: m == null ? [for (final _ in pending!.slots) null] : urls,
          localPaths: m == null ? const [] : (_localAlbums[m.messageId] ?? const []),
          slots: pending?.slots ?? const [],
          heroPrefix: heroPrefix,
          onFailedTap: onFailedTap,
          onOpen: (index) => ImageViewer.openGallery(
            context,
            imageUrls: urls,
            initialIndex: index,
            heroTags: [for (var i = 0; i < urls.length; i++) ChatAlbumView.heroTag(heroPrefix, i)],
          ),
        );
      } else {
        final url = m?.imageUrl;
        final local = pending?.localPath ?? (m == null ? null : _localImages[m.messageId]);
        final heroTag = 'chat_image_${entry.id}';
        image = GestureDetector(
          onTap: url != null ? () => ImageViewer.open(context, imageUrl: url, heroTag: heroTag, allowSave: true) : onFailedTap,
          child: ChatImageThumb(
            url: url,
            localPath: local,
            heroTag: heroTag,
            uploading: sending,
            failed: failed,
            progress: pending?.slots.firstOrNull?.progress,
          ),
        );
      }
      if (reply == null) return image;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ChatBubbleShell(
            isMine: isMine,
            groupStart: groupStart,
            groupEnd: false,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: IntrinsicWidth(child: quote(divider: false)),
          ),
          const SizedBox(height: 3),
          image,
        ],
      );
    }

    if (entry.kind == 'voice') {
      final voice = m?.voice;
      final url = voice?.url;
      final body = ChatVoiceBody(
        url: url == null || url.isEmpty ? null : url,
        seconds: pending?.seconds ?? voice?.durationSeconds ?? 0,
        isMine: isMine,
        uploading: sending,
        failed: failed,
      );
      if (reply == null) {
        return ChatBubbleShell(
          isMine: isMine,
          groupStart: groupStart,
          groupEnd: groupEnd,
          padding: const EdgeInsets.fromLTRB(7, 7, 12, 7),
          child: body,
        );
      }
      return ChatBubbleShell(
        isMine: isMine,
        groupStart: groupStart,
        groupEnd: groupEnd,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [quote(), Align(alignment: AlignmentDirectional.centerStart, child: body)],
          ),
        ),
      );
    }

    final value = pending?.text ?? m?.text ?? '';
    final sharedToken = reply == null ? LinkPreviewStore.bookTokenOf(value) : null;
    if (sharedToken != null) {
      return ChatSharedBookCard(
        token: sharedToken,
        isMine: isMine,
        width: math.min(math.min(MediaQuery.sizeOf(context).width * 0.7, 420.0), 320.0),
      );
    }
    final linkText = ChatLinkText(
      text: value,
      isMine: isMine,
      mentions: entry.mentions,
      myId: _myId,
      onMentionTap: _openProfile,
    );
    final previewUrl = LinkPreviewStore.firstUrl(value, mentions: entry.mentions);
    final Widget text = previewUrl == null
        ? linkText
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              linkText,
              ChatLinkPreviewCard(
                url: previewUrl,
                isMine: isMine,
                width: math.min(math.min(MediaQuery.sizeOf(context).width * 0.7, 420.0) - 26, 300.0),
              ),
            ],
          );
    if (reply == null) {
      return ChatBubbleShell(isMine: isMine, groupStart: groupStart, groupEnd: groupEnd, child: text);
    }
    return ChatBubbleShell(
      isMine: isMine,
      groupStart: groupStart,
      groupEnd: groupEnd,
      padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [quote(), text],
        ),
      ),
    );
  }
}
