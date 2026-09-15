import 'package:flutter/foundation.dart' show listEquals, mergeSort;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../i18n/strings.dart';
import '../../../models/chat.dart';
import 'chat_mention_editing.dart';

class ChatMentionCandidate {
  final int userId;
  final String name;
  final String? nickname;
  final String? avatarUrl;

  const ChatMentionCandidate({required this.userId, required this.name, this.nickname, this.avatarUrl});

  bool get isEveryone => userId == ChatMention.everyone;

  @override
  bool operator ==(Object other) =>
      other is ChatMentionCandidate &&
      other.userId == userId &&
      other.name == name &&
      other.nickname == nickname &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(userId, name, nickname, avatarUrl);
}

class ChatMentionController extends ChangeNotifier {
  final TextEditingController text;

  ChatMentionController(this.text) : _lastText = text.text {
    text.addListener(_onTextChanged);
  }

  late final TextInputFormatter formatter = TextInputFormatter.withFunction(_format);

  List<ChatMention> _mentions = const [];
  String _lastText;
  bool _enabled = false;
  List<ChatMentionCandidate> _members = const [];
  ChatMentionQuery? _query;
  List<ChatMentionCandidate> _candidates = const [];
  String? _dismissedAt;

  List<ChatMention> get mentions => _mentions;

  List<ChatMentionCandidate> get candidates => _candidates;

  bool get showing => _candidates.isNotEmpty;

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) _mentions = const [];
    _refresh();
  }

  set members(List<ChatMentionCandidate> value) {
    if (listEquals(_members, value)) return;
    _members = value;
    _refresh();
  }

  TextEditingValue _format(TextEditingValue oldValue, TextEditingValue newValue) {
    if (!_enabled || _mentions.isEmpty) {
      _lastText = newValue.text;
      return newValue;
    }
    final edit = reconcileMentionEdit(oldValue, newValue, _mentions);
    _mentions = edit.mentions;
    _lastText = edit.value.text;
    return edit.value;
  }

  void _onTextChanged() {
    if (text.text != _lastText) {
      if (_mentions.isNotEmpty) {
        _mentions = reconcileMentionEdit(
          TextEditingValue(text: _lastText),
          text.value,
          _mentions,
          collapseTokens: false,
        ).mentions;
      }
      _lastText = text.text;
    }
    _refresh();
  }

  void _refresh() {
    final query = _enabled ? activeMentionQuery(text.value, _mentions) : null;
    final key = query == null ? null : '${query.start}:${query.query}';
    final next = query == null || key == _dismissedAt ? const <ChatMentionCandidate>[] : _filter(query.query);
    if (query == null) _dismissedAt = null;
    final changed = !listEquals(next, _candidates) || _query != query;
    _query = query;
    _candidates = next;
    if (changed) notifyListeners();
  }

  List<ChatMentionCandidate> _filter(String raw) {
    final q = raw.toLowerCase();
    bool matches(String? value) => value != null && value.toLowerCase().contains(q);
    final everyone = ChatMentionCandidate(userId: ChatMention.everyone, name: S.everyone);
    final members = [
      for (final m in _members)
        if (q.isEmpty || matches(m.name) || matches(m.nickname)) m,
    ];
    if (q.isNotEmpty) {
      int rank(ChatMentionCandidate m) =>
          m.name.toLowerCase().startsWith(q) || (m.nickname?.toLowerCase().startsWith(q) ?? false) ? 0 : 1;
      mergeSort(members, compare: (a, b) => rank(a) - rank(b));
    }
    final includeEveryone = _members.isNotEmpty &&
        (q.isEmpty || matches(everyone.name) || 'all'.startsWith(q) || 'everyone'.startsWith(q));
    return [if (includeEveryone) everyone, ...members];
  }

  void select(ChatMentionCandidate candidate) {
    final query = _query;
    if (query == null) return;
    final edit = insertMention(
      text.value,
      _mentions,
      start: query.start,
      userId: candidate.userId,
      name: candidate.name,
    );
    _mentions = edit.mentions.length > kChatMentionMax ? _mentions : edit.mentions;
    _lastText = edit.value.text;
    text.value = edit.value;
  }

  void dismiss() {
    final query = _query;
    if (query == null) return;
    _dismissedAt = '${query.start}:${query.query}';
    _refresh();
  }

  void setMentions(List<ChatMention> mentions) {
    _lastText = text.text;
    _mentions = _enabled ? ChatMention.validFor(text.text, mentions) : const [];
    _refresh();
  }

  void clear() {
    _mentions = const [];
    _refresh();
  }

  ({String text, List<ChatMention> mentions}) take(String raw) =>
      trimWithMentions(raw, _enabled ? _mentions : const []);

  @override
  void dispose() {
    text.removeListener(_onTextChanged);
    super.dispose();
  }
}
