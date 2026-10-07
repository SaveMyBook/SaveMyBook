// 第 12 章使用手冊第 1 節（註冊與登入）與第 2 節（瀏覽與搜尋書籍）的截圖。

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/auth/link_sign_in_sheet.dart';
import 'package:savemybook_app/features/auth/login_screen.dart';
import 'package:savemybook_app/features/auth/phone_sign_in_screen.dart';
import 'package:savemybook_app/features/books/book_detail_screen.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/features/orders/widgets/payment_success_dialog.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/auth_social.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/models/security.dart';
import 'package:savemybook_app/services/recently_viewed.dart';
import 'package:savemybook_app/services/social_auth_service.dart';
import 'package:savemybook_app/services/verification_service.dart';
import 'package:savemybook_app/widgets/favorite_button.dart';

import 'manual_api.dart';
import 'manual_host.dart';

const _s1 = '1. 註冊與登入';
const _s2 = '2. 瀏覽與搜尋書籍';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

/// 原圖中的書：Gary 賣的《洗腦，被設計的真相》。
const _bookId = 148;

/// 原圖拍攝時尚未上架的書（10/06 上架），首頁排序才與原圖一致。
const _laterBooks = {150};

/// 原圖以「心理」搜尋的結果（伺服器以語意比對，書名不一定含關鍵字）。
const _psychologyResults = [77, 121, 89, 141, 144, 140, 88];

void main() {
  setUpAll(() async {
    await setUpManual();
    await _loadPingFangSc();
  });

  group('第 1 節', () {
    testWidgets('登入頁', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s1,
        loggedIn: false,
        prefs: const {'last_login_email': meEmail},
        routes: _authProviders,
        home: LoginScreen.new,
        act: (tester, snap) => snap('表12-1-1 登入頁'),
      );
    });

    testWidgets('輸入手機號碼', variant: _ios, (tester) async {
      final controller = PhoneSignInController(gateway: _FakeGateway());
      await shoot(
        tester,
        folder: _s1,
        loggedIn: false,
        routes: _authProviders,
        home: () => PhoneSignInScreen(controller: controller),
        act: (tester, snap) async {
          await tester.enterText(find.byType(TextField), '0912345678');
          FocusManager.instance.primaryFocus?.unfocus();
          await settle(tester, const Duration(milliseconds: 500));
          await snap('表12-1-2 輸入手機號碼');
        },
      );
      controller.dispose();
    });

    testWidgets('輸入簡訊驗證碼', variant: _ios, (tester) async {
      final sentAt = DateTime(2026, 10, 7, 10, 28);
      var elapsed = Duration.zero;
      final controller = PhoneSignInController(gateway: _FakeGateway(), clock: () => sentAt.add(elapsed));
      await shoot(
        tester,
        folder: _s1,
        loggedIn: false,
        routes: _authProviders,
        home: () => SmsCodeScreen(controller: controller),
        act: (tester, snap) async {
          await controller.send(toE164('+886', '0912345678'));
          elapsed = const Duration(seconds: 2);
          await settle(tester, const Duration(milliseconds: 1000));
          await snap('表12-1-2 輸入簡訊驗證碼');
        },
      );
      controller.dispose();
    });

    testWidgets('登入既有帳號並綁定', variant: _ios, (tester) async {
      EditableText.debugDeterministicCursor = true;
      addTearDown(() => EditableText.debugDeterministicCursor = false);
      await shoot(
        tester,
        folder: _s1,
        loggedIn: false,
        prefs: const {'last_login_email': meEmail},
        routes: _authProviders,
        home: LoginScreen.new,
        act: (tester, snap) async {
          unawaited(
            showLinkSignInSheet(
              navigatorKey.currentContext!,
              provider: AuthProviders.phone,
              initialEmail: meEmail,
              passkeyAvailable: true,
              submit: ({email, password, assertion}) async => const AuthResult.ok(),
            ),
          );
          await settleReal(tester, const Duration(seconds: 1));
          final password = find.byType(EditableText).last;
          await tester.enterText(password, 'samplepass12');
          await tester.enterText(password, 'samplepass12m');
          // iOS 的密碼鍵盤不會出現在螢幕截圖中，但面板仍會被鍵盤頂高（與原圖相同）
          tester.view.viewInsets = const FakeViewPadding(bottom: keyboardHeight * pixelRatio);
          tester.view.padding = const FakeViewPadding(top: topInset * pixelRatio);
          await settle(tester, const Duration(milliseconds: 500));
          await snap('表12-1-2 登入既有帳號並綁定');
        },
      );
    });
  });

  group('第 2 節', () {
    testWidgets('首頁書籍列表', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s2,
        routes: _homeRoutes,
        home: HomeScreen.new,
        act: (tester, snap) async {
          await snap('表12-2-1 首頁書籍列表');
          await snap('IMG_7113');
          await tester.tap(find.byIcon(Icons.view_agenda_rounded).first);
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-2-1 切換列表檢視');
          await tester.tap(find.byIcon(Icons.grid_view_rounded).first);
          await settleReal(tester, const Duration(seconds: 1));
          await tester.tap(find.byIcon(Icons.swap_vert_rounded).first);
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-2-1 選擇排序方式');
        },
      );
    });

    testWidgets('搜尋結果', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s2,
        routes: _homeRoutes,
        home: () => const HomeScreen(initialKeyword: '心理'),
        act: (tester, snap) async {
          await snap('表12-2-2 搜尋結果');
          await tester.tap(find.byIcon(Icons.view_agenda_rounded).first);
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-2-2 搜尋結果列表檢視');
        },
      );
    });

    for (final (name, scrollChips) in [('生活休閒', false), ('考試用書', false), ('語言學習', true)]) {
      testWidgets('篩選$name', variant: _ios, (tester) async {
        await shoot(
          tester,
          folder: _s2,
          routes: _homeRoutes,
          home: HomeScreen.new,
          act: (tester, snap) async {
            final chips = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right).first;
            if (scrollChips) await _scrollChipsTo(tester, chips, name);
            await tester.tap(find.descendant(of: chips, matching: find.text(name)));
            await settleReal(tester, const Duration(seconds: 2));
            if (scrollChips) await _scrollChipsTo(tester, chips, name);
            await snap('表12-2-3 篩選$name');
          },
        );
      });
    }

    testWidgets('為您推薦與最近瀏覽', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s2,
        routes: () {
          _homeRoutes();
          ManualApi.on('GET', '/books/recommended', (_) => [for (final id in [140, 122, 142, 139, 144, 146]) bookJson(id)]);
          ManualApi.on('GET', '/books/briefs', (r) => [for (final id in r.query['ids']!.split(',')) bookJson(int.parse(id))]);
          RecentlyViewed.restore([for (final id in [_bookId, 121, 145]) Book.fromJson(bookJson(id))]);
        },
        home: HomeScreen.new,
        act: (tester, snap) => snap('表12-2-4 為您推薦與最近瀏覽'),
      );
    });

    testWidgets('商品詳情', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s2,
        routes: _detailRoutes,
        home: _detail,
        act: (tester, snap) async {
          await snap('表12-2-4 商品詳情');
          await _scrollTo(tester, find.text(bookJson(_bookId)['title'] as String).first);
          await snap('表12-2-4 書籍資訊與內容簡介');
          await _scrollTo(tester, find.text(S.aboutBook).first);
          await snap('表12-2-5 書櫃據點與相似書籍');
        },
      );
    });

    testWidgets('收藏書籍', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s2,
        routes: _detailRoutes,
        home: _detail,
        act: (tester, snap) async {
          await tester.tap(find.byType(FavoriteButton).first);
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-2-5 收藏書籍');
        },
      );
    });

    testWidgets('分享書籍', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s2,
        routes: () {
          _detailRoutes(favorite: true);
          ManualApi.on('GET', '/books/$_bookId/share-link', (_) => {'url': 'https://savemybook.today/s/manual-share'});
        },
        home: _detail,
        act: (tester, snap) async {
          await tester.tap(find.byIcon(Icons.ios_share_rounded).first);
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-2-5 分享書籍');
        },
      );
    });

    testWidgets('聯絡賣家', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s2,
        routes: () {
          _detailRoutes(favorite: true);
          _chatRoutes();
        },
        home: _detail,
        act: (tester, snap) async {
          await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
          await settleReal(tester, const Duration(seconds: 2));
          await snap('表12-2-6 聯絡賣家');
        },
      );
    });

    testWidgets('加入購物車', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s2,
        routes: () {
          _detailRoutes(favorite: true);
          ManualApi.on('POST', '/cart', (_) => {'cart_id': 1, 'book_id': _bookId});
        },
        home: _detail,
        act: (tester, snap) async {
          await tester.tap(find.text(S.addCart).first);
          await settleReal(tester, const Duration(milliseconds: 1500));
          await snap('表12-2-6 加入購物車');
        },
      );
    });

    testWidgets('輸入交易密碼', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s2,
        routes: () {
          _detailRoutes(favorite: true);
          _securityRoute();
        },
        home: _detail,
        act: (tester, snap) async {
          VerificationService.navigatorKey = navigatorKey;
          VerificationService.paymentSummary = PaymentSummary(
            amount: 400,
            detail: S.booksTotal(1, '400') + S.balanceAfterPaymentCoins('9600'),
          );
          unawaited(VerificationService.handle(const VerificationRequest(scope: 'payment', methods: ['pin'], message: '')));
          await settleReal(tester, const Duration(seconds: 2));
          await snap('表12-2-7 輸入交易密碼');
          VerificationService.paymentSummary = null;
        },
      );
    });

    testWidgets('付款成功', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s2,
        routes: () => _detailRoutes(favorite: true, status: 'sold'),
        home: _detail,
        act: (tester, snap) async {
          unawaited(showPaymentSuccess(tester.element(find.byType(BookDetailScreen)), total: 400));
          await settleReal(tester, const Duration(seconds: 2));
          await snap('表12-2-7 付款成功');
        },
      );
    });
  });
}

void _authProviders() {
  ManualApi.on('GET', '/auth/providers', (_) => {
    'social_enabled': true,
    'providers': [
      for (final id in AuthProviders.ids) {'id': id, 'enabled': true, 'signup': true, 'configured': true},
    ],
  });
}

void _homeRoutes() {
  ManualApi.on('GET', '/notifications/unread-count', (_) => {
    'unread_count': 1,
    'by_category': {'trade': 1, 'chat': 0, 'account': 0, 'service': 0, 'promotion': 0},
  });
  ManualApi.on('GET', '/books', (r) => _searchBooks(r.query));
}

List<Map<String, dynamic>> _searchBooks(Map<String, String> q) {
  final keyword = q['keyword']?.trim() ?? '';
  if (keyword == '心理') return [for (final id in _psychologyResults) bookJson(id)];
  var list = [
    for (final b in realBooks)
      if (!_laterBooks.contains(b['book_id'])) b,
  ];
  final categories = q['category_ids']?.split(',').where((s) => s.isNotEmpty).map(int.parse).toSet();
  if (categories != null && categories.isNotEmpty) list = list.where((b) => categories.contains(b['category_id'])).toList();
  if (keyword.isNotEmpty) {
    list = list.where((b) => '${b['title']} ${b['author']} ${b['isbn']}'.toLowerCase().contains(keyword.toLowerCase())).toList();
  }
  double price(Map b) => double.tryParse('${b['price']}') ?? 0;
  switch (q['sort']) {
    case 'price_asc':
      list.sort((a, b) => price(a).compareTo(price(b)));
    case 'price_desc':
      list.sort((a, b) => price(b).compareTo(price(a)));
    case 'popular':
      list.sort((a, b) => (b['view_count'] as int).compareTo(a['view_count'] as int));
    default:
      list.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
  }
  return list;
}

Map<String, dynamic> _detailJson({String status = 'on_sale'}) => bookJson(
  _bookId,
  extra: {
    'status': status,
    'enrichment': {
      'fields': ['description'],
      'ai_written': true,
    },
  },
);

Widget _detail() => BookDetailScreen(book: Book.fromJson(_detailJson()));

void _detailRoutes({bool favorite = false, String status = 'on_sale'}) {
  ManualApi.on('GET', '/books/$_bookId', (_) => _detailJson(status: status));
  ManualApi.on('GET', '/books/$_bookId/similar', (_) => [for (final id in [88, 111, 119, 121, 122, 142]) bookJson(id)]);
  ManualApi.on('GET', '/favorites/ids', (_) => [if (favorite) _bookId]);
  ManualApi.on('GET', '/cart/book-ids', (_) => <int>[]);
  ManualApi.on('POST', '/favorites', (_) => {'book_id': _bookId});
  ManualApi.on('GET', '/wallet', (_) => {
    'balance': 10000,
    'frozen_amount': 0,
    'total_income': 0,
    'total_expense': 0,
    'pending_income': 0,
  });
}

void _securityRoute() {
  ManualApi.on('GET', '/security', (_) => {
    'available': true,
    'has_payment_pin': true,
    'pin_locked_until': null,
    'biometric_pay_enabled': false,
    'passkey_available': true,
    'has_passkey': false,
    'has_password': true,
  });
}

void _chatRoutes() {
  const roomId = 1;
  final seller = bookJson(_bookId)['seller_id'] as int;
  final book = bookJson(_bookId);
  ManualApi.on('POST', '/chat/rooms', (_) => {'room_id': roomId});
  ManualApi.on('GET', '/chat/rooms/$roomId', (_) => {
    'room_id': roomId,
    'type': 'direct',
    'name': '',
    'avatar_url': null,
    'created_by': meId,
    'my_role': 'member',
    'members': [
      {...userJson(meId), 'role': 'member', 'joined_at': ago(minutes: 1)},
      {...userJson(seller), 'role': 'member', 'joined_at': ago(minutes: 1)},
    ],
    'partner': {...userJson(seller), 'alias': null},
    'muted': false,
    'pinned': false,
  });
  ManualApi.on('GET', '/chat/rooms/$roomId/messages', (_) => {
    'success': true,
    'message': 'OK',
    'data': [
      {
        'message_id': 1,
        'room_id': roomId,
        'sender_id': meId,
        'content': '',
        'message_type': 'system',
        'kind': 'book',
        'body': null,
        'mentions': <Object>[],
        'payload': {'book_id': _bookId, 'title': book['title'], 'price': 400, 'image_url': coverOf(_bookId)},
        'is_read': false,
        'created_at': ago(minutes: 0),
        'edited_at': null,
        'reply_to': null,
        'users': {'user_id': meId, 'nickname': meName, 'avatar_url': null},
        'risk': null,
      },
    ],
    'partner': userJson(seller),
    'meta': {
      'read_upto': 0,
      'partner_typing': false,
      'recalled_ids': <int>[],
      'has_more': false,
      'reservations': <Object>[],
      'transfers': <Object>[],
      'members_read': <Object>[],
      'aliases': <String, String>{},
      'edited': <Object>[],
      'room': {'type': 'direct', 'title': realUsers[seller]!.nickname, 'avatar_url': null, 'member_count': 2},
    },
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await Scrollable.ensureVisible(tester.element(target));
  await settleReal(tester, const Duration(milliseconds: 800));
}

/// 分類標籤列捲到與原圖相同的位置：目標標籤露出一部分在右側邊緣。標籤列是延遲建立的清單，先捲到底讓目標標籤建立。
Future<void> _scrollChipsTo(WidgetTester tester, Finder chips, String name) async {
  final state = tester.state<ScrollableState>(chips);
  state.position.jumpTo(state.position.maxScrollExtent);
  await settleReal(tester, const Duration(milliseconds: 300));
  final viewport = tester.getRect(chips);
  final chip = tester.getRect(find.descendant(of: chips, matching: find.text(name)));
  final target = state.position.pixels + chip.left + 40 - viewport.right;
  state.position.jumpTo(target.clamp(0, state.position.maxScrollExtent));
  await settleReal(tester, const Duration(milliseconds: 600));
}

/// App 字型 Noto Sans TC 沒有部分簡體字（如「乐」「书」），App 以 PingFang SC 補字；測試環境沒有系統字型，
/// 從本機 macOS 的 PingFang.ttc 取出 PingFang SC 的字面載入，與 iPhone 上的顯示相同。
Future<void> _loadPingFangSc() async {
  const path = '/System/Library/AssetsV2/com_apple_MobileAsset_Font8/86ba2c91f017a3749571a82f2c6d890ac7ffb2fb.asset/AssetData/PingFang.ttc';
  final file = File(path);
  if (!file.existsSync()) return;
  final ttc = file.readAsBytesSync();
  final loader = FontLoader('PingFang SC');
  // 第 3、7、11 個字面為 PingFang SC 的 Regular、Medium、Semibold
  for (final index in [3, 7, 11]) {
    loader.addFont(Future.value(ByteData.sublistView(_ttcFace(ttc, index))));
  }
  await loader.load();
}

Uint8List _ttcFace(Uint8List ttc, int index) {
  final src = ByteData.sublistView(ttc);
  final offset = src.getUint32(12 + 4 * index);
  final count = src.getUint16(offset + 4);
  final header = 12 + 16 * count;
  final tables = [
    for (var i = 0; i < count; i++)
      (record: offset + 12 + 16 * i, start: src.getUint32(offset + 20 + 16 * i), length: src.getUint32(offset + 24 + 16 * i)),
  ];
  final size = tables.fold(header, (sum, t) => sum + ((t.length + 3) & ~3));
  final out = Uint8List(size);
  final dst = ByteData.sublistView(out);
  out.setRange(0, 12, ttc, offset);
  var pos = header;
  for (final (i, t) in tables.indexed) {
    out.setRange(12 + 16 * i, 20 + 16 * i, ttc, t.record);
    dst.setUint32(20 + 16 * i, pos);
    dst.setUint32(24 + 16 * i, t.length);
    out.setRange(pos, pos + t.length, ttc, t.start);
    pos += (t.length + 3) & ~3;
  }
  return out;
}

class _FakeGateway implements FirebaseAuthGateway {
  @override
  bool get supportsGoogle => true;

  @override
  bool get supportsApple => true;

  @override
  Future<String> googleIdToken() async => throw SocialAuthFailure(AuthCodes.cancelled, '');

  @override
  Future<String> appleIdToken() async => throw SocialAuthFailure(AuthCodes.cancelled, '');

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    int? resendToken,
    required void Function(String idToken) onVerified,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(SocialAuthFailure failure) onFailed,
  }) async => onCodeSent('manual-verification', null);

  @override
  Future<String> smsCodeIdToken({required String verificationId, required String smsCode}) async => 'manual-id-token';

  @override
  Future<void> signOut() async {}
}
