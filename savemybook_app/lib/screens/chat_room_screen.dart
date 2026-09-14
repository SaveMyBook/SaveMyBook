import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../i18n/strings.dart';
import '../models/book.dart';
import '../models/chat.dart';
import '../services/api_service.dart';
import '../services/voice_service.dart';
import '../utils/app_colors.dart';
import '../utils/motion.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_header.dart';
import '../widgets/app_tiles.dart';
import '../widgets/animations.dart';
import '../widgets/chat/chat_bubbles.dart';
import '../widgets/chat/chat_format.dart';
import '../widgets/chat/chat_input_bar.dart';
import '../widgets/chat/reservation_card.dart';
import '../widgets/image_viewer.dart';
import '../widgets/state_views.dart';
import 'book_detail_screen.dart';
import 'cart_screen.dart';
import 'seller_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final int roomId;
  final String partnerName;

  const ChatRoomScreen({super.key, required this.roomId, this.partnerName = ''});

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

enum _SendState { sending, failed }

class _Pending {
  final String key;
  final String kind;
  final String text;
  final String? localPath;
  final int seconds;
  final DateTime createdAt = DateTime.now();
  String? uploadedUrl;
  _SendState state = _SendState.sending;

  _Pending({required this.key, required this.kind, this.text = '', this.localPath, this.seconds = 0});
}

class _Entry {
  final String key;
  final ChatMessage? message;
  final _Pending? pending;

  const _Entry.message(this.key, ChatMessage this.message) : pending = null;

  const _Entry.pending(_Pending this.pending)
      : key = '',
        message = null;

  String get id => pending?.key ?? key;

  int get senderId => message?.senderId ?? (ApiService.currentUser?.userId ?? 0);

  DateTime? get createdAt => message?.createdAt ?? pending?.createdAt;

  String get kind => message?.kind ?? pending!.kind;

  bool get isCentered => const {'book', 'reservation', 'recalled', 'notice'}.contains(kind);
}

class _ChatRoomScreenState extends State<ChatRoomScreen> with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 3);
  static const _typingInterval = Duration(seconds: 3);
  static const _recallWindow = Duration(minutes: 2);
  static const _pageSize = 40;
  // 用來比對伺服器回傳的中文錯誤訊息，必須維持 const，翻譯抽取才會略過它。
  static const _unreachableMarker = '無法接收訊息';

  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final Key _centerKey = const ValueKey('chat_center');

  final List<ChatMessage> _messages = [];
  final Set<int> _ids = {};
  final List<_Pending> _pending = [];
  final Map<int, ChatReservation> _reservations = {};
  final Map<int, String> _clientKeys = {};
  final Map<int, String> _localImages = {};
  final Set<String> _fresh = {};
  final Set<int> _busyReservations = {};

  final ValueNotifier<bool> _partnerTyping = ValueNotifier(false);
  final ValueNotifier<int> _unseen = ValueNotifier(0);
  final ValueNotifier<bool> _showJump = ValueNotifier(false);

  List<_Entry> _entries = const [];
  Map<String, int> _keyIndex = const {};
  int _baseCount = 0;
  int _pivotId = 0;

  ChatPartner? _partner;
  Book? _reserveBook;
  int? _checkedBookId;
  int _readUpto = 0;

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
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    _partnerTyping.dispose();
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

    setState(() {
      _messages.clear();
      _ids.clear();
      _mergeMessages(result.messages);
      if (result.partner.userId != 0) _partner = result.partner;
      _readUpto = result.readUpto;
      _hasMore = result.hasMore;
      _reservations
        ..clear()
        ..addAll(result.reservations);
      _partnerTyping.value = result.partnerTyping;
      _applyControls(result);
      _pivotId = _messages.isEmpty ? 0 : _messages.last.messageId;
      _loading = false;
      _loadError = false;
      _offline = false;
      _failures = 0;
      _rebuildEntries();
    });
    _refreshReservable();
    _fillViewportWithOlder();
  }

  void _fillViewportWithOlder() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasMore || !_scroll.hasClients) return;
      final p = _scroll.position;
      if (p.maxScrollExtent - p.pixels < 600) _loadOlder();
    });
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
        Navigator.of(context).maybePop();
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
            _partner?.avatarUrl != partner.avatarUrl)) {
      _partner = partner;
      changed = true;
    }

    if (result.readUpto > _readUpto) {
      _readUpto = result.readUpto;
      changed = true;
    }

    if (!_updatingControls && _applyControls(result)) changed = true;

    for (final id in result.recalledIds) {
      if (!_ids.contains(id)) continue;
      final i = _messages.indexWhere((m) => m.messageId == id);
      if (i < 0 || _messages[i].isRecalled) continue;
      final url = _messages[i].voice?.url;
      if (url != null && VoicePlayback.instance.isActive(url)) VoicePlayback.instance.stop();
      _messages[i] = _messages[i].copyWith(kind: 'recalled');
      changed = true;
    }

    if (_mergeReservations(result.reservations)) changed = true;
    _partnerTyping.value = result.partnerTyping;

    final fresh = result.messages.where((m) => m.messageId > 0 && !_ids.contains(m.messageId)).toList();
    if (fresh.isNotEmpty) {
      _mergeMessages(fresh);
      final keys = [for (final m in fresh) _keyFor(m)];
      _markFresh(keys);
      if (!atBottom) {
        final fromPartner = fresh.where((m) => m.senderId != _myId).length;
        if (fromPartner > 0) _unseen.value += fromPartner;
      }
      changed = true;
    }

    if (!changed) return;

    setState(() {
      if (atBottom && settled) _repivot();
      _rebuildEntries();
    });

    if (fresh.isNotEmpty) {
      if (atBottom && settled) _settleToBottom();
      if (fresh.any((m) => m.kind == 'book')) _refreshReservable();
      if (fresh.any((m) => m.senderId != _myId)) _api.fetchUnreadChatCount();
    }
  }

  bool _applyControls(ChatFetchResult result) {
    final unavailable = !result.canSend && !result.blocked;
    if (_muted == result.muted && _blocked == result.blocked && _partnerUnavailable == unavailable) return false;
    _muted = result.muted;
    _blocked = result.blocked;
    _partnerUnavailable = unavailable;
    if (_blocked || _partnerUnavailable) _partnerTyping.value = false;
    return true;
  }

  Future<void> _showRoomMenu() async {
    final partner = _partner;
    if (partner == null || partner.userId == 0 || _updatingControls) return;
    FocusScope.of(context).unfocus();
    final c = AppColors.of(context);
    final choice = await showOptionSheet<String>(
      context,
      title: partner.nickname,
      options: [
        SheetOption(
          value: 'mute',
          label: _muted ? S.unmute : S.mute,
          icon: _muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
        ),
        SheetOption(
          value: 'block',
          label: _blocked ? S.unblock : S.blockUser,
          icon: _blocked ? Icons.lock_open_rounded : Icons.block_rounded,
          color: _blocked ? null : c.danger,
        ),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == 'mute') {
      await _setMuted(!_muted);
    } else {
      await _setBlocked(!_blocked);
    }
  }

  Future<void> _setMuted(bool muted) async {
    setState(() {
      _updatingControls = true;
      _muted = muted;
    });
    final error = await _api.setChatRoomMuted(widget.roomId, muted);
    if (!mounted) return;
    setState(() {
      _updatingControls = false;
      if (error != null) _muted = !muted;
    });
    showAppSnackBar(context, error ?? (muted ? S.chatMuted : S.chatUnmuted), isError: error != null);
  }

  Future<void> _setBlocked(bool blocked) async {
    final partner = _partner;
    if (partner == null || partner.userId == 0) return;
    if (blocked) {
      final confirmed = await showConfirmDialog(
        context,
        title: S.blockUser,
        message: S.afterBlockP0NeitherCanSend(partner.nickname),
        confirmLabel: S.block,
        isDestructive: true,
        icon: Icons.block_rounded,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _updatingControls = true);
    final error = await _api.setUserBlocked(partner.userId, blocked);
    if (!mounted) return;
    setState(() {
      _updatingControls = false;
      if (error == null) {
        _blocked = blocked;
        if (blocked) {
          _partnerTyping.value = false;
          _quickRepliesOpen = false;
        }
      }
    });
    showAppSnackBar(context, error ?? (blocked ? S.userBlocked : S.userUnblocked), isError: error != null);
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

  void _mergeMessages(Iterable<ChatMessage> incoming) {
    var needsSort = false;
    for (final m in incoming) {
      if (m.messageId <= 0) continue;
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

  void _enqueue(_Pending p) {
    _sendQueue = _sendQueue.then((_) => _deliver(p)).catchError((Object _) => _failPending(p, null));
  }

  void _rebuildEntries() {
    final entries = <_Entry>[
      for (final m in _messages) _Entry.message(_keyFor(m), m),
      for (final p in _pending) _Entry.pending(p),
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
    if (!mounted || !_hasNewer || !_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.isScrollingNotifier.value || p.pixels - p.minScrollExtent > 4) return;
    setState(() {
      _repivot();
      _rebuildEntries();
    });
  }

  void _onScroll() {
    final p = _scroll.position;
    final fromBottom = p.pixels - p.minScrollExtent;
    _showJump.value = fromBottom > 320;
    if (fromBottom < 40 && _unseen.value != 0) _unseen.value = 0;
    if (p.maxScrollExtent - p.pixels < 600) _loadOlder();
  }

  void _onTextChanged() {
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
    if (book == null || _partnerUnavailable || _blocked) return false;
    return !_reservations.values.any((r) =>
        r.bookId == book.bookId &&
        r.buyerId == _myId &&
        ((r.isPending && (r.createdAt == null || DateTime.now().difference(r.createdAt!) < const Duration(hours: 24))) ||
            r.isConfirmed));
  }

  void _addPending(_Pending p) {
    _stopTyping();
    setState(() {
      _quickRepliesOpen = false;
      _repivot(force: true);
      _pending.add(p);
      _markFresh([p.key]);
      _rebuildEntries();
    });
    if (_scroll.hasClients) {
      final distance = _scroll.position.pixels - _scroll.position.minScrollExtent;
      if (distance > _scroll.position.viewportDimension * 3) _scroll.jumpTo(0);
    }
    _settleToBottom();
    _enqueue(p);
  }

  String _nextKey() => 'p${++_pendingSeq}';

  void _sendText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    if (text.length > 2000) {
      showAppSnackBar(context, S.messagesCanUp2000Characters, isError: true);
      return;
    }
    HapticFeedback.lightImpact();
    _controller.clear();
    _addPending(_Pending(key: _nextKey(), kind: 'text', text: text));
  }

  Future<void> _deliver(_Pending p) async {
    if (!_pending.contains(p)) return;

    var content = p.text;
    if (p.kind != 'text') {
      var url = p.uploadedUrl;
      if (url == null) {
        final (uploaded, error) =
            p.kind == 'image' ? await _api.uploadChatImage(p.localPath!) : await _api.uploadVoice(p.localPath!);
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
    );
    if (message == null) return _failPending(p, error);

    _clientKeys[message.messageId] = p.key;
    if (p.kind == 'image' && p.localPath != null) _localImages[message.messageId] = p.localPath!;
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

  void _failPending(_Pending p, String? error) {
    if (!mounted || !_pending.contains(p)) return;
    final message = error ?? S.messageCouldNotSent;
    setState(() {
      p.state = _SendState.failed;
      if (message.contains(_unreachableMarker)) _partnerUnavailable = true;
      _rebuildEntries();
    });
    showAppSnackBar(context, message, isError: true);
  }

  void _retryPending(_Pending p) {
    if (_offline || _partnerUnavailable) {
      showAppSnackBar(context, S.canTSendRightNowPlease, isError: true);
      return;
    }
    setState(() {
      p.state = _SendState.sending;
      _rebuildEntries();
    });
    _enqueue(p);
  }

  void _discardPending(_Pending p) {
    if (p.kind == 'voice') VoiceRecorder.deleteFile(p.localPath);
    setState(() {
      _pending.remove(p);
      _rebuildEntries();
    });
  }

  Future<void> _openAttachSheet() async {
    FocusScope.of(context).unfocus();
    final c = AppColors.of(context);
    final canReserve = _canReserve;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.sheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 8,
                runSpacing: 16,
                children: [
                  _AttachTile(
                    icon: Icons.photo_camera_rounded,
                    label: S.takePhoto,
                    color: const Color(0xFF4F8CC9),
                    onTap: () => Navigator.pop(ctx, 'camera'),
                  ),
                  _AttachTile(
                    icon: Icons.photo_library_rounded,
                    label: S.chooseFromPhotos,
                    color: const Color(0xFF3FA37C),
                    onTap: () => Navigator.pop(ctx, 'gallery'),
                  ),
                  if (canReserve)
                    _AttachTile(
                      icon: Icons.event_available_rounded,
                      label: S.reserveBook,
                      color: const Color(0xFFD98613),
                      onTap: () => Navigator.pop(ctx, 'reserve'),
                    ),
                  _AttachTile(
                    icon: Icons.bolt_rounded,
                    label: S.quickReplies,
                    color: const Color(0xFF8A6FD1),
                    onTap: () => Navigator.pop(ctx, 'quick'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;

    if (choice == 'camera') {
      _pickImages(ImageSource.camera);
    } else if (choice == 'gallery') {
      _pickImages(ImageSource.gallery);
    } else if (choice == 'reserve') {
      _requestReservation();
    } else if (choice == 'quick') {
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

    var skipped = 0;
    for (final file in files.take(9)) {
      final size = await File(file.path).length().catchError((_) => 0);
      if (size > 10 * 1024 * 1024) {
        skipped++;
        continue;
      }
      if (!mounted) return;
      _addPending(_Pending(key: _nextKey(), kind: 'image', localPath: file.path));
    }
    if (skipped > 0 && mounted) showAppSnackBar(context, S.imagesMust10MbSmaller, isError: true);
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
    _addPending(_Pending(key: _nextKey(), kind: 'voice', localPath: clip.path, seconds: clip.seconds));
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

  Future<void> _showMessageMenu(_Entry entry) async {
    final pending = entry.pending;
    if (pending != null) {
      if (pending.state == _SendState.failed) _showPendingMenu(pending);
      return;
    }
    final m = entry.message!;
    if (m.isRecalled) return;

    final isMine = m.senderId == _myId;
    final created = m.createdAt;
    final canRecall = isMine &&
        const {'text', 'image', 'voice'}.contains(m.kind) &&
        created != null &&
        DateTime.now().difference(created) < _recallWindow;
    final canReport = !isMine && const {'text', 'image', 'voice'}.contains(m.kind);
    final isText = m.kind == 'text';

    HapticFeedback.mediumImpact();
    final preview = m.preview.replaceAll('\n', ' ');
    final choice = await showOptionSheet<String>(
      context,
      title: preview.length > 40 ? '${preview.substring(0, 40)}…' : preview,
      options: [
        if (isText) SheetOption(value: 'copy', label: S.copy, icon: Icons.copy_rounded),
        if (isText) SheetOption(value: 'select', label: S.selectText, icon: Icons.text_fields_rounded),
        if (canRecall) SheetOption(value: 'recall', label: S.unsend, icon: Icons.undo_rounded),
        if (canReport)
          SheetOption(value: 'report', label: S.report, icon: Icons.flag_outlined, color: AppColors.of(context).danger),
      ],
    );
    if (!mounted || choice == null) return;

    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.text));
      if (!mounted) return;
      HapticFeedback.selectionClick();
      showAppSnackBar(context, S.messageCopied);
    } else if (choice == 'select') {
      _showSelectableText(m.text);
    } else if (choice == 'recall') {
      _recall(m);
    } else if (choice == 'report') {
      _report(m);
    }
  }

  Future<void> _showPendingMenu(_Pending p) async {
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

  void _showSelectableText(String text) {
    final c = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.sheetBg,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: SelectableText(text, style: TextStyle(fontSize: 16, height: 1.6, color: c.textPrimary)),
        ),
      ),
    );
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
    final String message;
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
      message = S.theyLlNotifiedDeclined;
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

  void _openPartner(String title) {
    final partner = _partner;
    if (partner == null || partner.userId == 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerScreen(
          sellerId: partner.userId,
          sellerName: title,
          sellerAvatarUrl: partner.avatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final nickname = _partner?.nickname ?? '';
    final title = nickname.isNotEmpty ? nickname : widget.partnerName;
    final inputEnabled = !_loading && !_loadError && !_offline && !_partnerUnavailable && !_blocked;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: title.isEmpty ? S.chat : title,
            actionsWidth: 106,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PressableScale(
                  onTap: _partner == null ? null : () => _openPartner(title),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UserAvatar(imageUrl: _partner?.avatarUrl, radius: 15, background: Colors.white24),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: _partner == null || _loading ? null : _showRoomMenu,
                tooltip: S.moreOptions,
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              ),
            ],
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
                      : KeyedSubtree(key: const ValueKey('list'), child: _buildConversation(c)),
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
            onSend: _sendText,
            onAttach: _openAttachSheet,
            onToggleQuickReplies: () => setState(() => _quickRepliesOpen = !_quickRepliesOpen),
            onVoice: _sendVoice,
            onVoiceUnavailable: _onVoiceUnavailable,
            onVoiceTooShort: () => showAppSnackBar(context, S.holdMicTalkReleaseSend),
          ),
        ],
      ),
    );
  }

  Widget _buildConversation(AppColors c) {
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
                    (_, i) => _buildRow(_baseCount - 1 - i),
                    childCount: _baseCount,
                    findChildIndexCallback: (key) {
                      final index = key is ValueKey<String> ? _keyIndex[key.value] : null;
                      if (index == null || index >= _baseCount) return null;
                      return _baseCount - 1 - index;
                    },
                  ),
                ),
                SliverToBoxAdapter(child: _buildListHead(c)),
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
          left: 12,
          bottom: 8,
          child: ValueListenableBuilder<bool>(
            valueListenable: _partnerTyping,
            builder: (_, typing, _) => AnimatedSwitcher(
              duration: Motion.base,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  alignment: Alignment.bottomLeft,
                  scale: CurvedAnimation(parent: animation, curve: Motion.pop),
                  child: child,
                ),
              ),
              child: typing ? const ChatTypingBubble(key: ValueKey('typing')) : const SizedBox.shrink(),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 10,
          child: _buildJumpButton(c),
        ),
      ],
    );
  }

  Widget _buildListHead(AppColors c) {
    if (_entries.isEmpty) return const SizedBox.shrink();
    if (_hasMore || _loadingOlder) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      child: Text(
        S.startConversation,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11.5, color: c.textHint),
      ),
    );
  }

  Widget _buildJumpButton(AppColors c) {
    return AnimatedBuilder(
      animation: Listenable.merge([_showJump, _unseen]),
      builder: (_, _) {
        final unseen = _unseen.value;
        final countLabel = unseen > 99 ? '99+' : '$unseen';
        final visible = _showJump.value || unseen > 0;
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedScale(
            scale: visible ? 1 : 0.6,
            duration: Motion.base,
            curve: visible ? Motion.pop : Motion.exitCurve,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: Motion.micro,
              child: GestureDetector(
                onTap: _jumpToBottom,
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.standard,
                  height: 40,
                  padding: EdgeInsets.symmetric(horizontal: unseen > 0 ? 14 : 10),
                  decoration: BoxDecoration(
                    color: unseen > 0 ? chatMineBubble(c) : c.card,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: c.shadow, blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: unseen > 0 ? Colors.white : c.textPrimary,
                      ),
                      if (unseen > 0) ...[
                        const SizedBox(width: 2),
                        Text(
                          S.p0New(countLabel),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget? _buildInputTop(AppColors c) {
    final children = <Widget>[];

    if (_offline) {
      children.add(_Banner(
        icon: Icons.wifi_off_rounded,
        text: S.connectionUnstableMessagesCanTSent,
        color: c.warning,
        actionLabel: S.retry,
        onAction: () => _poll(force: true),
      ));
    } else if (_blocked) {
      children.add(_Banner(
        icon: Icons.block_rounded,
        text: S.blockedUser,
        color: c.danger,
        actionLabel: S.unblock,
        onAction: _updatingControls ? null : () => _setBlocked(false),
      ));
    } else if (_partnerUnavailable) {
      children.add(_Banner(icon: Icons.block_rounded, text: S.accountCanTReceiveMessagesRight, color: c.danger));
    }

    final hasConversation = _messages.any((m) => const {'text', 'image', 'voice'}.contains(m.kind)) || _pending.isNotEmpty;
    final showQuick = !_loading && !_loadError && !_partnerUnavailable && !_blocked && (_quickRepliesOpen || !hasConversation);
    final quickReplies = [S.stillAvailable, S.couldLowerPriceBit, S.whenCanPutLocker];

    final chips = <Widget>[
      if (_canReserve)
        _Chip(
          icon: Icons.event_available_rounded,
          label: S.reserveBook,
          highlighted: true,
          onTap: _requestReservation,
        ),
      if (showQuick)
        for (final reply in quickReplies)
          _Chip(
            label: reply,
            onTap: _offline ? null : () => _sendText(reply),
          ),
    ];

    if (chips.isNotEmpty) {
      children.add(SizedBox(
        height: 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => FadeSlideIn(index: i, offsetY: 8, child: chips[i]),
        ),
      ));
    }

    if (children.isEmpty) return null;
    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  bool _joins(_Entry? a, _Entry b) {
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

    return KeyedSubtree(
      key: ValueKey<String>(entry.id),
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
              body,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCentered(_Entry entry) {
    final m = entry.message!;
    final isMine = m.senderId == _myId;

    if (m.kind == 'recalled') {
      return ChatSystemLine(
        text: isMine ? S.unsentMessage : S.theyUnsentMessage,
        icon: Icons.undo_rounded,
      );
    }

    if (m.kind == 'book') {
      final card = m.bookCard;
      if (card == null) return const SizedBox.shrink();
      return ChatBookCardView(card: card, onTap: () => _openBook(card.bookId));
    }

    if (m.kind == 'reservation') {
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
        busy: _busyReservations.contains(r.reservationId),
        onAction: (action) => _onReservationAction(r, action),
        onOpenBook: () => _openBook(r.bookId),
      );
    }

    return ChatSystemLine(text: m.text, icon: Icons.info_outline_rounded);
  }

  Widget _buildBubbleRow(_Entry entry, _Entry? next, bool groupStart, bool groupEnd) {
    final isMine = entry.senderId == _myId;
    final width = MediaQuery.sizeOf(context).width;
    final maxBubble = math.min(width * 0.7, 420.0);
    final meta = _buildMeta(entry, next, isMine, groupEnd);

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxBubble),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _showMessageMenu(entry),
        child: _buildContent(entry, isMine, groupStart, groupEnd),
      ),
    );

    final line = Row(
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

    return Padding(
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
                      imageUrl: _partner?.avatarUrl,
                      radius: 16,
                      onTap: () => _openPartner(_partner?.nickname ?? widget.partnerName),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: line),
        ],
      ),
    );
  }

  Widget? _buildMeta(_Entry entry, _Entry? next, bool isMine, bool groupEnd) {
    final c = AppColors.of(context);
    final small = TextStyle(fontSize: 10.5, color: c.textHint, height: 1.25);
    final pending = entry.pending;

    if (pending != null) {
      if (pending.state == _SendState.failed) {
        return GestureDetector(
          onTap: () => _showPendingMenu(pending),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Icon(Icons.error_rounded, size: 20, color: c.danger),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(S.sending, style: small),
      );
    }

    final m = entry.message!;
    final read = isMine && _isRead(m);
    final nextMessage = next?.message;
    final nextReadToo = next != null &&
        nextMessage != null &&
        nextMessage.senderId == _myId &&
        _joins(entry, next) &&
        _isRead(nextMessage);
    final showRead = read && !nextReadToo;
    if (!groupEnd && !showRead) return null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showRead)
          Text(S.read, style: small.copyWith(color: c.accent, fontWeight: FontWeight.w600)),
        Text(chatClock(m.createdAt), style: small),
      ],
    );
  }

  Widget _buildContent(_Entry entry, bool isMine, bool groupStart, bool groupEnd) {
    final pending = entry.pending;
    final m = entry.message;
    final sending = pending?.state == _SendState.sending;
    final failed = pending?.state == _SendState.failed;

    if (entry.kind == 'image') {
      final url = m?.imageUrl;
      final local = pending?.localPath ?? (m == null ? null : _localImages[m.messageId]);
      final heroTag = 'chat_image_${entry.id}';
      return GestureDetector(
        onTap: url != null
            ? () => ImageViewer.open(context, imageUrl: url, heroTag: heroTag)
            : (failed && pending != null ? () => _showPendingMenu(pending) : null),
        child: ChatImageThumb(
          url: url,
          localPath: local,
          heroTag: heroTag,
          uploading: sending,
          failed: failed,
        ),
      );
    }

    if (entry.kind == 'voice') {
      final voice = m?.voice;
      final url = voice?.url;
      return ChatBubbleShell(
        isMine: isMine,
        groupStart: groupStart,
        groupEnd: groupEnd,
        padding: const EdgeInsets.fromLTRB(7, 7, 12, 7),
        child: ChatVoiceBody(
          url: url == null || url.isEmpty ? null : url,
          seconds: pending?.seconds ?? voice?.durationSeconds ?? 0,
          isMine: isMine,
          uploading: sending,
          failed: failed,
        ),
      );
    }

    return ChatBubbleShell(
      isMine: isMine,
      groupStart: groupStart,
      groupEnd: groupEnd,
      child: ChatLinkText(text: pending?.text ?? m?.text ?? '', isMine: isMine),
    );
  }
}

class _AttachTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      width: 76,
      child: PressableScale(
        onTap: onTap,
        haptic: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: c.isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: c.textPrimary, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool highlighted;
  final VoidCallback? onTap;

  const _Chip({required this.label, this.icon, this.highlighted = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = highlighted ? Colors.white : c.textPrimary;
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: highlighted ? chatMineBubble(c) : c.inputFill,
          borderRadius: BorderRadius.circular(18),
          border: highlighted ? null : Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Banner({required this.icon, required this.text, required this.color, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: c.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                text,
                style: TextStyle(fontSize: 12.5, color: c.textPrimary, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: color,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
