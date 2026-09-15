class LegalSectionData {
  final String title;
  final String body;

  const LegalSectionData(this.title, this.body);
}

class LegalStructure {
  final String intro;
  final List<LegalSectionData> sections;

  const LegalStructure(this.intro, this.sections);
}

class LegalDiff {
  final int added;
  final int removed;
  final int changed;
  final bool reordered;
  final bool introChanged;
  final bool titleChanged;
  final bool hasSections;
  final int charDelta;

  const LegalDiff({
    required this.added,
    required this.removed,
    required this.changed,
    required this.reordered,
    required this.introChanged,
    required this.titleChanged,
    required this.hasSections,
    required this.charDelta,
  });

  bool get isEmpty => added == 0 && removed == 0 && changed == 0 && !reordered && !introChanged && !titleChanged;
}

abstract final class LegalText {
  static const maxTitleLength = 80;

  static final _arabic = RegExp(r'^\s*(\d{1,3})\s*(?:[.\uff0e](?!\d)|[\u3001)\uff09])\s*(\S.*)$');
  static final _article = RegExp(
    r'^\s*\u7b2c\s*([0-9\u96f6\u3007\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u767e\u5169]+)\s*[\u689d\u6761\u7ae0\u7bc0\u8282]\s*[\u3001.\uff0e:\uff1a]?\s*(\S.*)$',
  );
  static final _cjk = RegExp(r'^\s*([\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341]+)\s*\u3001\s*(\S.*)$');
  static const _cjkDigits = '\u96f6\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d';

  static String normalize(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'[ \t\u3000]+$', multiLine: true), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'^\n+|\n+$'), '');
  }

  static int charCount(String text) => text.replaceAll(RegExp(r'\s'), '').length;

  static int? _cjkNumber(String raw) {
    final digits = int.tryParse(raw);
    if (digits != null) return digits;
    var total = 0;
    var current = 0;
    for (final ch in raw.split('')) {
      final digit = _cjkDigits.indexOf(ch);
      if (digit >= 0) {
        current = digit;
      } else if (ch == '\u3007') {
        current = 0;
      } else if (ch == '\u5169') {
        current = 2;
      } else if (ch == '\u5341') {
        total += (current == 0 ? 1 : current) * 10;
        current = 0;
      } else if (ch == '\u767e') {
        total += (current == 0 ? 1 : current) * 100;
        current = 0;
      } else {
        return null;
      }
    }
    return total + current;
  }

  static ({int number, String title})? _heading(String line) {
    final arabic = _arabic.firstMatch(line);
    if (arabic != null) return (number: int.parse(arabic.group(1)!), title: arabic.group(2)!.trim());
    final other = _article.firstMatch(line) ?? _cjk.firstMatch(line);
    if (other == null) return null;
    final number = _cjkNumber(other.group(1)!);
    return number == null ? null : (number: number, title: other.group(2)!.trim());
  }

  static LegalStructure parse(String text) {
    final intro = <String>[];
    final titles = <String>[];
    final bodies = <List<String>>[];

    for (final block in normalize(text).split('\n\n')) {
      if (block.trim().isEmpty) continue;
      final cut = block.indexOf('\n');
      final heading = _heading(cut < 0 ? block : block.substring(0, cut));

      if (heading != null && heading.number == titles.length + 1 && heading.title.length <= maxTitleLength) {
        titles.add(heading.title);
        bodies.add([if (cut >= 0) block.substring(cut + 1)]);
      } else if (titles.isEmpty) {
        intro.add(block);
      } else {
        bodies.last.add(block);
      }
    }

    return LegalStructure(
      intro.join('\n\n'),
      [for (var i = 0; i < titles.length; i++) LegalSectionData(titles[i], bodies[i].join('\n\n'))],
    );
  }

  static String compose(String intro, List<LegalSectionData> sections) {
    final parts = <String>[];
    final head = normalize(intro);
    if (head.trim().isNotEmpty) parts.add(head);

    var number = 0;
    for (final section in sections) {
      final title = section.title.trim();
      final body = normalize(section.body);
      if (title.isEmpty && body.trim().isEmpty) continue;
      number++;
      parts.add(body.trim().isEmpty ? '$number. $title' : '$number. $title\n$body');
    }
    return parts.join('\n\n');
  }

  static bool isLossless(String text) {
    final structure = parse(text);
    return compose(structure.intro, structure.sections) == normalize(text);
  }

  static LegalDiff diff({
    required String oldTitle,
    required String oldContent,
    required String newTitle,
    required String newContent,
  }) {
    final before = parse(oldContent);
    final after = parse(newContent);

    final pool = <String, List<int>>{};
    for (var i = 0; i < before.sections.length; i++) {
      pool.putIfAbsent(before.sections[i].title.trim(), () => []).add(i);
    }

    var added = 0;
    var changed = 0;
    final matchedOrder = <int>[];
    for (final section in after.sections) {
      final candidates = pool[section.title.trim()];
      if (candidates == null || candidates.isEmpty) {
        added++;
        continue;
      }
      final index = candidates.removeAt(0);
      matchedOrder.add(index);
      if (normalize(before.sections[index].body) != normalize(section.body)) changed++;
    }

    var reordered = false;
    for (var i = 1; i < matchedOrder.length; i++) {
      if (matchedOrder[i] < matchedOrder[i - 1]) {
        reordered = true;
        break;
      }
    }

    return LegalDiff(
      added: added,
      removed: before.sections.length - matchedOrder.length,
      changed: changed,
      reordered: reordered,
      introChanged: normalize(before.intro) != normalize(after.intro),
      titleChanged: oldTitle.trim() != newTitle.trim(),
      hasSections: before.sections.isNotEmpty || after.sections.isNotEmpty,
      charDelta: charCount(newContent) - charCount(oldContent),
    );
  }
}
