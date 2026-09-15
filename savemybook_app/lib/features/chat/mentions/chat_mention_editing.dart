import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../../models/chat.dart';

const int kChatMentionMax = 20;
const int kChatMentionTokenMax = 60;
const int _queryMax = 30;

class ChatMentionEdit {
  final TextEditingValue value;
  final List<ChatMention> mentions;

  const ChatMentionEdit(this.value, this.mentions);
}

typedef ChatMentionQuery = ({int start, String query});

bool _isSpace(int unit) => unit == 0x20 || unit == 0x0A || unit == 0x0D || unit == 0x09 || unit == 0x3000;

bool _isAsciiWord(int unit) =>
    (unit >= 0x30 && unit <= 0x39) || (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A) || unit == 0x5F;

(int, int) _changedRange(String a, String b, TextSelection selection) {
  final delta = b.length - a.length;
  if (selection.isValid && selection.isCollapsed && delta != 0) {
    final cursor = selection.baseOffset;
    if (delta > 0) {
      final start = cursor - delta;
      if (start >= 0 &&
          cursor <= b.length &&
          b.startsWith(a.substring(0, start)) &&
          b.substring(cursor) == a.substring(start)) {
        return (start, start);
      }
    } else if (cursor >= 0 && cursor <= b.length && cursor - delta <= a.length) {
      if (a.startsWith(b.substring(0, cursor)) && a.substring(cursor - delta) == b.substring(cursor)) {
        return (cursor, cursor - delta);
      }
    }
  }
  final shortest = math.min(a.length, b.length);
  var prefix = 0;
  while (prefix < shortest && a.codeUnitAt(prefix) == b.codeUnitAt(prefix)) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < shortest - prefix && a.codeUnitAt(a.length - 1 - suffix) == b.codeUnitAt(b.length - 1 - suffix)) {
    suffix++;
  }
  return (prefix, a.length - suffix);
}

ChatMentionEdit reconcileMentionEdit(
  TextEditingValue oldValue,
  TextEditingValue newValue,
  List<ChatMention> mentions, {
  bool collapseTokens = true,
}) {
  final a = oldValue.text;
  final b = newValue.text;
  if (mentions.isEmpty || a == b) return ChatMentionEdit(newValue, mentions);

  final (oldStart, oldEnd) = _changedRange(a, b, newValue.selection);
  final delta = b.length - a.length;
  final inserted = oldEnd - oldStart + delta;

  final hits = <ChatMention>[];
  for (final m in mentions) {
    final before = m.end <= oldStart;
    final after = m.start >= oldEnd;
    if (!before && !after) hits.add(m);
  }

  if (hits.isNotEmpty && collapseTokens && inserted == 0 && oldEnd > oldStart && !newValue.composing.isValid) {
    final from = math.min(oldStart, hits.map((m) => m.start).reduce(math.min));
    final to = math.max(oldEnd, hits.map((m) => m.end).reduce(math.max));
    final removed = to - from;
    return ChatMentionEdit(
      TextEditingValue(
        text: a.substring(0, from) + a.substring(to),
        selection: TextSelection.collapsed(offset: from),
      ),
      [
        for (final m in mentions)
          if (m.end <= from)
            m
          else if (m.start >= to)
            m.shift(-removed),
      ],
    );
  }

  return ChatMentionEdit(newValue, [
    for (final m in mentions)
      if (m.end <= oldStart)
        m
      else if (m.start >= oldEnd)
        m.shift(delta),
  ]);
}

ChatMentionQuery? activeMentionQuery(TextEditingValue value, List<ChatMention> mentions) {
  final selection = value.selection;
  if (!selection.isValid || !selection.isCollapsed) return null;
  final text = value.text;
  final cursor = selection.baseOffset;
  if (cursor <= 0 || cursor > text.length) return null;
  final floor = math.max(0, cursor - _queryMax - 1);
  for (var i = cursor - 1; i >= floor; i--) {
    final unit = text.codeUnitAt(i);
    if (_isSpace(unit)) return null;
    if (unit != 0x40) continue;
    if (i > 0 && _isAsciiWord(text.codeUnitAt(i - 1))) return null;
    if (mentions.any((m) => i >= m.start && i < m.end)) return null;
    return (start: i, query: text.substring(i + 1, cursor));
  }
  return null;
}

ChatMentionEdit insertMention(
  TextEditingValue value,
  List<ChatMention> mentions, {
  required int start,
  required int userId,
  required String name,
}) {
  final text = value.text;
  final cursor = value.selection.isValid ? value.selection.baseOffset.clamp(start, text.length) : text.length;
  final label = name.replaceAll(RegExp(r'\s+'), ' ').trim();
  var token = '@$label';
  if (token.length > kChatMentionTokenMax) token = token.substring(0, kChatMentionTokenMax).trimRight();
  final needsSpace = cursor >= text.length || !_isSpace(text.codeUnitAt(cursor));
  final insertion = needsSpace ? '$token ' : token;
  final delta = insertion.length - (cursor - start);
  final next = text.substring(0, start) + insertion + text.substring(cursor);
  final caret = start + token.length + 1;

  final updated = <ChatMention>[
    for (final m in mentions)
      if (m.end <= start)
        m
      else if (m.start >= cursor)
        m.shift(delta),
    ChatMention(userId: userId, start: start, length: token.length),
  ]..sort((x, y) => x.start.compareTo(y.start));

  return ChatMentionEdit(
    TextEditingValue(text: next, selection: TextSelection.collapsed(offset: math.min(caret, next.length))),
    updated,
  );
}

({String text, List<ChatMention> mentions}) trimWithMentions(String raw, List<ChatMention> mentions) {
  final text = raw.trim();
  final leading = raw.length - raw.trimLeft().length;
  final valid = ChatMention.validFor(raw, mentions);
  return (
    text: text,
    mentions: [
      for (final m in valid)
        if (m.start >= leading && m.end <= leading + text.length) m.shift(-leading),
    ].take(kChatMentionMax).toList(),
  );
}
