import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/chat/mentions/chat_mention_controller.dart';
import 'package:savemybook_app/features/chat/mentions/chat_mention_editing.dart';
import 'package:savemybook_app/features/chat/widgets/chat_entry.dart';
import 'package:savemybook_app/features/chat/widgets/swipe_to_reply.dart';
import 'package:savemybook_app/models/chat.dart';

TextEditingValue _v(String text, [int? cursor]) =>
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: cursor ?? text.length));

void main() {
  group('mention editing', () {
    const amy = ChatMention(userId: 7, start: 3, length: 4);

    test('typing before a mention shifts it', () {
      final edit = reconcileMentionEdit(_v('hi @Amy ', 0), _v('Yo hi @Amy ', 3), [amy]);
      expect(edit.value.text, 'Yo hi @Amy ');
      expect(edit.mentions, [amy.shift(3)]);
    });

    test('typing right after a mention keeps it', () {
      final edit = reconcileMentionEdit(_v('hi @Amy', 7), _v('hi @Amyy', 8), [amy]);
      expect(edit.mentions, [amy]);
    });

    test('typing the same character as the mention start is disambiguated by the cursor', () {
      const m = ChatMention(userId: 1, start: 0, length: 4);
      final edit = reconcileMentionEdit(_v('@Ann', 0), _v('@@Ann', 1), [m]);
      expect(edit.mentions, [m.shift(1)]);
    });

    test('backspace into a mention removes the whole token', () {
      final edit = reconcileMentionEdit(_v('hi @Amy ok', 7), _v('hi @Am ok', 6), [amy]);
      expect(edit.value.text, 'hi  ok');
      expect(edit.value.selection, const TextSelection.collapsed(offset: 3));
      expect(edit.mentions, isEmpty);
    });

    test('removing a token shifts later mentions', () {
      const bob = ChatMention(userId: 8, start: 8, length: 4);
      final edit = reconcileMentionEdit(_v('hi @Amy @Bob', 7), _v('hi @Am @Bob', 6), [amy, bob]);
      expect(edit.value.text, 'hi  @Bob');
      expect(edit.mentions, [bob.shift(-4)]);
    });

    test('inserting inside a mention invalidates it without deleting text', () {
      final edit = reconcileMentionEdit(_v('hi @Amy', 5), _v('hi @Axmy', 6), [amy]);
      expect(edit.value.text, 'hi @Axmy');
      expect(edit.mentions, isEmpty);
    });

    test('programmatic edits never delete text', () {
      final edit = reconcileMentionEdit(_v('hi @Amy'), const TextEditingValue(text: 'hi @Am'), [amy], collapseTokens: false);
      expect(edit.value.text, 'hi @Am');
      expect(edit.mentions, isEmpty);
    });

    test('active query detection', () {
      expect(activeMentionQuery(_v('hello @Am'), const []), (start: 6, query: 'Am'));
      expect(activeMentionQuery(_v('@'), const []), (start: 0, query: ''));
      expect(activeMentionQuery(_v('謝謝@小'), const []), (start: 2, query: '小'));
      expect(activeMentionQuery(_v('mail a@b'), const []), isNull);
      expect(activeMentionQuery(_v('@Am y'), const []), isNull);
      expect(activeMentionQuery(_v('hi @Amy', 7), [amy]), isNull);
    });

    test('insert mention replaces the query and records UTF-16 range', () {
      final edit = insertMention(_v('嗨 @小'), const [], start: 2, userId: 5, name: '小明 😀');
      expect(edit.value.text, '嗨 @小明 😀 ');
      expect(edit.mentions, [ChatMention(userId: 5, start: 2, length: '@小明 😀'.length)]);
      expect(edit.value.selection.baseOffset, edit.value.text.length);
    });

    test('trim for send shifts ranges by leading whitespace', () {
      final result = trimWithMentions('  @Amy hi  ', const [ChatMention(userId: 7, start: 2, length: 4)]);
      expect(result.text, '@Amy hi');
      expect(result.mentions, const [ChatMention(userId: 7, start: 0, length: 4)]);
    });

    test('validFor drops misaligned or overlapping ranges', () {
      final valid = ChatMention.validFor('@a @b', const [
        ChatMention(userId: 1, start: 0, length: 2),
        ChatMention(userId: 2, start: 1, length: 2),
        ChatMention(userId: 3, start: 3, length: 9),
        ChatMention(userId: 4, start: 3, length: 2),
      ]);
      expect(valid.map((m) => m.userId), [1, 4]);
    });
  });

  group('mention controller', () {
    testWidgets('typing @ shows candidates, selecting inserts a token and backspace removes it', (tester) async {
      final text = TextEditingController();
      final mentions = ChatMentionController(text)
        ..enabled = true
        ..members = const [
          ChatMentionCandidate(userId: 2, name: 'Alice'),
          ChatMentionCandidate(userId: 3, name: 'Bob', nickname: 'Robert'),
        ];
      addTearDown(mentions.dispose);
      addTearDown(text.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TextField(controller: text, inputFormatters: [mentions.formatter])),
      ));
      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.updateEditingValue(_v('hi @rob'));
      await tester.pump();
      expect(mentions.candidates.map((c) => c.userId), [3]);

      mentions.select(mentions.candidates.first);
      await tester.pump();
      expect(text.text, 'hi @Bob ');
      expect(mentions.mentions, const [ChatMention(userId: 3, start: 3, length: 4)]);
      expect(mentions.showing, isFalse);

      tester.testTextInput.updateEditingValue(_v('hi @Bob', 7));
      await tester.pump();
      expect(mentions.mentions, const [ChatMention(userId: 3, start: 3, length: 4)]);

      tester.testTextInput.updateEditingValue(_v('hi @Bo', 6));
      await tester.pump();
      expect(text.text, 'hi ');
      expect(mentions.mentions, isEmpty);
    });

    testWidgets('empty query lists everyone first', (tester) async {
      final text = TextEditingController();
      final mentions = ChatMentionController(text)
        ..enabled = true
        ..members = const [ChatMentionCandidate(userId: 2, name: 'Alice')];
      addTearDown(mentions.dispose);
      addTearDown(text.dispose);
      text.value = _v('@');
      expect(mentions.candidates.first.isEveryone, isTrue);
      expect(mentions.candidates.length, 2);
      mentions.dismiss();
      expect(mentions.showing, isFalse);
    });
  });

  group('album grouping', () {
    test('single image stays an image, several become one album', () {
      final one = groupImagesForSend([(path: 'a', bytes: 10)]);
      expect(one.groups, [
        ['a'],
      ]);
      final many = groupImagesForSend([(path: 'a', bytes: 10), (path: 'b', bytes: 10), (path: 'c', bytes: 10)]);
      expect(many.groups, [
        ['a', 'b', 'c'],
      ]);
      expect(ChatPendingMessage.images(key: 'p1', paths: many.groups.first).kind, 'album');
      expect(ChatPendingMessage.images(key: 'p2', paths: one.groups.first).kind, 'image');
    });

    test('oversized files are skipped and long batches are split', () {
      final result = groupImagesForSend(
        [for (var i = 0; i < 23; i++) (path: '$i', bytes: i == 5 ? kChatImageMaxBytes + 1 : 100)],
      );
      expect(result.skipped, 1);
      expect(result.groups.map((g) => g.length), [20, 2]);
    });

    test('album messages expose urls and preview', () {
      final m = ChatMessage.fromJson({
        'message_id': 3,
        'sender_id': 1,
        'content': '[album]{"urls":["/uploads/chat/a.jpg","/uploads/chat/b.jpg"]}',
        'message_type': 'system',
        'kind': 'album',
        'payload': {
          'urls': ['/uploads/chat/a.jpg', '/uploads/chat/b.jpg'],
        },
        'mentions': [],
      });
      expect(m.imageUrls.length, 2);
      expect(m.hasImages, isTrue);
      expect(m.preview, contains('2'));
      expect(ChatReply.of(m, senderName: 'x').imageUrl, m.imageUrls.first);
    });
  });

  group('swipe to reply', () {
    late int replies;
    late int haptics;

    setUp(() {
      replies = 0;
      haptics = 0;
    });

    Future<void> pumpList(WidgetTester tester, {int count = 30}) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics++;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: count,
            itemBuilder: (_, i) => SwipeToReply(
              key: ValueKey('row$i'),
              onReply: () => replies++,
              child: Container(height: 60, margin: const EdgeInsets.all(4), alignment: Alignment.center, color: Colors.blue, child: Text('m$i')),
            ),
          ),
        ),
      ));
    }

    Offset translation(WidgetTester tester, String text) {
      final transform = tester.widget<Transform>(
        find.ancestor(of: find.text(text), matching: find.byType(Transform)).first,
      );
      return Offset(transform.transform.getTranslation().x, transform.transform.getTranslation().y);
    }

    testWidgets('drag past the trigger replies once with one haptic, in both directions', (tester) async {
      await pumpList(tester);
      final start = tester.getCenter(find.text('m1'));

      final gesture = await tester.startGesture(start);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(translation(tester, 'm1').dx, greaterThan(SwipeToReply.trigger));
      expect(translation(tester, 'm1').dx, lessThan(SwipeToReply.trigger + SwipeToReply.maxOverdrag));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(replies, 1);
      expect(haptics, 1);
      expect(translation(tester, 'm1').dx, 0);

      final left = await tester.startGesture(tester.getCenter(find.text('m2')));
      for (var i = 0; i < 10; i++) {
        await left.moveBy(const Offset(-10, 0));
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(translation(tester, 'm2').dx, lessThan(-SwipeToReply.trigger));
      await left.up();
      await tester.pumpAndSettle();
      expect(replies, 2);
    });

    testWidgets('follows the finger 1:1 below the trigger and springs back without replying', (tester) async {
      await pumpList(tester);
      final gesture = await tester.startGesture(tester.getCenter(find.text('m1')));
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 80));
      }
      expect(translation(tester, 'm1').dx, closeTo(40, 0.01));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(replies, 0);
      expect(translation(tester, 'm1').dx, 0);
    });

    testWidgets('a quick short fling replies', (tester) async {
      await pumpList(tester);
      final gesture = await tester.startGesture(tester.getCenter(find.text('m1')));
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(5, 0), timeStamp: Duration(milliseconds: 4 * (i + 1)));
      }
      await gesture.up(timeStamp: const Duration(milliseconds: 36));
      await tester.pumpAndSettle();
      expect(translation(tester, 'm1').dx, 0);
      expect(replies, 1);
    });

    testWidgets('mostly vertical drags scroll the list and never move bubbles', (tester) async {
      await pumpList(tester);
      final before = tester.getTopLeft(find.text('m3')).dy;
      final gesture = await tester.startGesture(tester.getCenter(find.text('m3')));
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(4, -14));
        await tester.pump(const Duration(milliseconds: 16));
        expect(translation(tester, 'm3').dx, 0);
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(replies, 0);
      expect(tester.getTopLeft(find.text('m3')).dy, lessThan(before - 100));
    });

    testWidgets('drags starting at the screen edge are left to the back gesture', (tester) async {
      await pumpList(tester);
      final y = tester.getCenter(find.text('m1')).dy;
      final gesture = await tester.startGesture(Offset(10, y), kind: PointerDeviceKind.touch);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(replies, 0);
    });
  });
}
