import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/features/auth/phone_sign_in_screen.dart';
import 'package:savemybook_app/features/auth/link_sign_in_sheet.dart';
import 'package:savemybook_app/features/auth/social_sign_in.dart';
import 'package:savemybook_app/models/auth_social.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/deep_link_service.dart';
import 'package:savemybook_app/services/passkey_service.dart';
import 'package:savemybook_app/services/social_auth_service.dart';

import 'fake_auth_gateway.dart';

Map<String, dynamic> _providersPayload({
  bool socialEnabled = true,
  Map<String, bool> enabled = const {},
  Map<String, bool> configured = const {},
}) =>
    {
      'social_enabled': socialEnabled,
      'providers': [
        for (final id in AuthProviders.ids)
          {
            'id': id,
            'enabled': enabled[id] ?? true,
            'signup': true,
            'configured': configured[id] ?? true,
          },
      ],
    };

MockClient _client(Map<String, http.Response Function()> routes) {
  return MockClient((request) async {
    final key = '${request.method} ${request.url.path.replaceFirst('/api', '')}';
    final build = routes[key];
    if (build == null) {
      return http.Response(jsonEncode({'success': true, 'data': <String, Object>{}}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    return build();
  });
}

http.Response _ok(Object? data) => http.Response(
      jsonEncode({'success': true, 'message': 'OK', 'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response _fail(int status, String code, String message) => http.Response(
      jsonEncode({'success': false, 'code': code, 'message': message}),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

BuildContext? _ctx;
bool? _flowResult;

/// pumpAndSettle 只等到沒有待排的畫面更新，流程尾端的非同步工作要多轉幾圈才會結束。
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// 把流程掛在一個真的有 Navigator 的畫面上，才能按到對話框的按鈕。
Future<void> _pumpFlow(
  WidgetTester tester,
  Future<bool> Function() run, {
  required MockClient client,
}) async {
  _ctx = null;
  _flowResult = null;

  await tester.pumpWidget(MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: const [Locale('zh')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) {
      S = AppLocalizations.of(context);
      return child ?? const SizedBox.shrink();
    },
    home: Builder(
      builder: (context) {
        _ctx = context;
        return const Scaffold(body: SizedBox.shrink());
      },
    ),
  ));
  await tester.pumpAndSettle();

  unawaited(http.runWithClient(() async {
    _flowResult = await run();
  }, () => client));
  await _settle(tester);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // 未接上原生端時 FlutterSecureStorage 的呼叫不會回來，登入流程會卡在清除付款金鑰。
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    ApiService.authToken = null;
    ApiService.currentUser = null;
    DeepLinkService.onOAuthResult = null;
    DeepLinkService.reset();
    SocialAuth.gateway = FakeAuthGateway();
    SocialSignInFlow.passkeyAvailableOverride = false;
  });

  group('登入方式清單', () {
    test('解析伺服器回應', () {
      final info = AuthProvidersInfo.fromJson(_providersPayload(
        enabled: {AuthProviders.line: false},
        configured: {AuthProviders.discord: false},
      ));

      expect(info.socialEnabled, isTrue);
      expect(info.isEnabled(AuthProviders.google), isTrue);
      expect(info.isEnabled(AuthProviders.line), isFalse);
      expect(info.optionOf(AuthProviders.discord)?.configured, isFalse);
    });

    test('總開關關閉時不顯示任何按鈕', () {
      final info = AuthProvidersInfo.fromJson(_providersPayload(socialEnabled: false));
      expect(info.enabled, isEmpty);
      expect(SocialSignInSection.visibleIds(info), isEmpty);
    });

    test('停用的渠道不顯示', () {
      final info = AuthProvidersInfo.fromJson(_providersPayload(enabled: {AuthProviders.discord: false}));
      expect(SocialSignInSection.visibleIds(info), isNot(contains(AuthProviders.discord)));
      expect(SocialSignInSection.visibleIds(info), contains(AuthProviders.google));
    });

    test('平台不支援 Apple 時隱藏該按鈕', () {
      SocialAuth.gateway = FakeAuthGateway(supportsApple: false);
      final info = AuthProvidersInfo.fromJson(_providersPayload());
      expect(SocialSignInSection.visibleIds(info), isNot(contains(AuthProviders.apple)));
      expect(SocialSignInSection.visibleIds(info), contains(AuthProviders.line));
    });

    test('總開關關閉時回 social_enabled=false', () async {
      final client = _client({
        'GET /auth/providers': () => _ok({'social_enabled': false, 'providers': <Object>[]}),
      });
      final info = await http.runWithClient(() => ApiService().fetchAuthProviders(), () => client);
      expect(info.socialEnabled, isFalse);
      expect(SocialSignInSection.visibleIds(info), isEmpty);
    });
  });

  group('錯誤代碼', () {
    Future<AuthResult<void>> signInWith(int status, String code, String message) {
      final client = _client({'POST /auth/social': () => _fail(status, code, message)});
      return http.runWithClient(
        () => ApiService().socialSignIn(provider: AuthProviders.google, idToken: 't'),
        () => client,
      );
    }

    final cases = <String, (int, String)>{
      AuthCodes.accountExists: (409, '此電子郵件已註冊'),
      AuthCodes.emailRequired: (400, '請提供電子郵件'),
      AuthCodes.signupNotAllowed: (403, '此登入方式僅供既有帳號使用'),
      AuthCodes.methodDisabled: (403, '目前未開放'),
      AuthCodes.providerMismatch: (400, '不符'),
      AuthCodes.unavailable: (503, '社群登入暫時無法使用，請稍後再試'),
      AuthCodes.invalidIdToken: (401, '憑證無效'),
      AuthCodes.providerError: (502, '服務無法使用'),
    };

    cases.forEach((code, expected) {
      test('/auth/social 回 $code', () async {
        final result = await signInWith(expected.$1, code, expected.$2);
        expect(result.isOk, isFalse);
        expect(result.code, code);
        expect(result.message, expected.$2);
      });
    });

    test('綁定收到 INVALID_ID_TOKEN 不會把使用者登出', () async {
      ApiService.authToken = 'session-token';
      ApiService.currentUser = User.fromJson({'user_id': 1, 'nickname': 'A', 'email': 'a@x.com', 'role': 'buyer_seller'});

      final client = _client({
        'POST /auth/link': () => _fail(401, AuthCodes.invalidIdToken, '登入逾時，請重新操作'),
      });
      final result = await http.runWithClient(
        () => ApiService().linkIdentity(provider: AuthProviders.google, idToken: 'bad'),
        () => client,
      );

      expect(result.code, AuthCodes.invalidIdToken);
      expect(ApiService.authToken, 'session-token', reason: '第三方憑證無效不代表本站登入階段失效');
    });

    test('已綁定其他帳號回 IDENTITY_TAKEN', () async {
      ApiService.authToken = 'session-token';
      final client = _client({
        'POST /auth/link': () => _fail(409, AuthCodes.identityTaken, '此登入方式已綁定其他帳號'),
      });
      final result = await http.runWithClient(
        () => ApiService().linkIdentity(provider: AuthProviders.google, idToken: 't'),
        () => client,
      );
      expect(result.code, AuthCodes.identityTaken);
    });

    test('解除唯一登入方式回 LAST_SIGN_IN_METHOD', () async {
      ApiService.authToken = 'session-token';
      final client = _client({
        'DELETE /auth/link/google': () => _fail(400, AuthCodes.lastMethod, '這是此帳號唯一的登入方式'),
      });
      final result = await http.runWithClient(
        () => ApiService().unlinkIdentity(AuthProviders.google),
        () => client,
      );
      expect(result.code, AuthCodes.lastMethod);
    });

    test('解除未綁定的方式回 404 時補上代碼', () async {
      ApiService.authToken = 'session-token';
      final client = _client({
        'DELETE /auth/link/line': () => http.Response(
              jsonEncode({'success': false, 'message': '此帳號未綁定此登入方式'}),
              404,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
      });
      final result = await http.runWithClient(
        () => ApiService().unlinkIdentity(AuthProviders.line),
        () => client,
      );
      expect(result.code, AuthCodes.notLinked);
    });

    test('設定密碼回 PASSWORD_ALREADY_SET', () async {
      ApiService.authToken = 'session-token';
      final client = _client({
        'POST /auth/password/set': () => _fail(400, AuthCodes.passwordAlreadySet, '此帳號已設定密碼，請改用變更密碼'),
      });
      final result = await http.runWithClient(() => ApiService().setLoginPassword('abcd1234'), () => client);
      expect(result.code, AuthCodes.passwordAlreadySet);
    });

    test('變更密碼回 PASSWORD_NOT_SET', () async {
      ApiService.authToken = 'session-token';
      final client = _client({
        'PUT /users/me/password': () => _fail(400, AuthCodes.passwordNotSet, '此帳號尚未設定密碼，請改用設定密碼'),
      });
      final result = await http.runWithClient(() => ApiService().changePassword('a', 'b'), () => client);
      expect(result.code, AuthCodes.passwordNotSet);
    });

    test('申請刪除帳號回 PASSWORD_NOT_SET', () async {
      ApiService.authToken = 'session-token';
      final client = _client({
        'POST /users/me/deletion': () =>
            _fail(400, AuthCodes.passwordNotSet, '此帳號尚未設定密碼，請先設定密碼再申請刪除帳號'),
      });
      final result = await http.runWithClient(() => ApiService().requestAccountDeletion('x'), () => client);
      expect(result.code, AuthCodes.passwordNotSet);
      expect(AuthCodes.messageOf(AuthCodes.passwordNotSet), '請先設定密碼');
    });

    test('OAuth 交換失敗回 OAUTH_CODE_INVALID', () async {
      final client = _client({
        'POST /auth/oauth/exchange': () => _fail(400, AuthCodes.codeInvalid, '登入逾時，請重新操作'),
      });
      final result = await http.runWithClient(() => ApiService().exchangeOAuthCode('a' * 32), () => client);
      expect(result.code, AuthCodes.codeInvalid);
    });

    test('每個代碼都有可顯示的中文訊息', () {
      for (final code in [
        AuthCodes.accountExists,
        AuthCodes.emailRequired,
        AuthCodes.signupNotAllowed,
        AuthCodes.methodDisabled,
        AuthCodes.providerMismatch,
        AuthCodes.identityTaken,
        AuthCodes.alreadyLinked,
        AuthCodes.lastMethod,
        AuthCodes.unavailable,
        AuthCodes.invalidIdToken,
        AuthCodes.passwordAlreadySet,
        AuthCodes.passwordNotSet,
        AuthCodes.stateInvalid,
        AuthCodes.codeInvalid,
        AuthCodes.providerError,
        AuthCodes.oauthFailed,
        AuthCodes.notLinked,
        AuthCodes.network,
      ]) {
        expect(AuthCodes.messageOf(code), isNotEmpty, reason: code);
        expect(AuthCodes.messageOf(code), isNot(AuthCodes.messageOf('SOMETHING_ELSE')), reason: code);
      }
    });
  });

  group('簡訊登入流程', () {
    test('號碼轉換為 E.164', () {
      expect(toE164('+886', '0912345678'), '+886912345678');
      expect(toE164('+886', '0912-345-678'), '+886912345678');
      expect(toE164('+81', '09012345678'), '+819012345678');
    });

    test('送出號碼後進入輸入驗證碼並開始倒數', () async {
      final gateway = FakeAuthGateway();
      final controller = PhoneSignInController(gateway: gateway, resendCooldown: const Duration(seconds: 3));
      addTearDown(controller.dispose);

      await controller.send('+886912345678');

      expect(controller.stage, PhoneSignInStage.codeSent);
      expect(gateway.lastPhoneNumber, '+886912345678');
      expect(controller.resendSeconds, 3);
      expect(controller.canResend, isFalse);
    });

    testWidgets('倒數未結束前不重送，倒數結束後帶上 resend token', (tester) async {
      final gateway = FakeAuthGateway();
      final controller = PhoneSignInController(
        gateway: gateway,
        resendCooldown: const Duration(seconds: 3),
        codeValidity: const Duration(seconds: 5),
      );
      addTearDown(controller.dispose);

      await controller.send('+886912345678');
      await controller.resend();
      expect(gateway.sendCount, 1, reason: '倒數尚未結束不應重送');

      await tester.pump(const Duration(seconds: 4));
      expect(controller.canResend, isTrue);

      await controller.resend();
      expect(gateway.sendCount, 2);
      expect(gateway.lastResendToken, 1, reason: '重送要帶上前一次的 resend token');

      // 計時器會跑到驗證碼失效為止，必須在測試結束前跑完，否則框架會判定有未完成的 Timer。
      await tester.pump(const Duration(seconds: 6));
    });

    test('驗證碼錯誤時留在輸入畫面並顯示訊息', () async {
      final gateway = FakeAuthGateway()
        ..codeFailure = const SocialAuthFailure('invalid-verification-code', '驗證碼不正確，請重新輸入');
      final controller = PhoneSignInController(gateway: gateway, resendCooldown: const Duration(seconds: 3));
      addTearDown(controller.dispose);

      await controller.send('+886912345678');
      final ok = await controller.submitCode('000000');

      expect(ok, isFalse);
      expect(controller.stage, PhoneSignInStage.codeSent);
      expect(controller.error, '驗證碼不正確，請重新輸入');
      expect(controller.idToken, isNull);
    });

    test('驗證碼正確時取得 ID Token', () async {
      final gateway = FakeAuthGateway(idToken: 'phone-token');
      final controller = PhoneSignInController(gateway: gateway, resendCooldown: const Duration(seconds: 3));
      addTearDown(controller.dispose);

      await controller.send('+886912345678');
      final ok = await controller.submitCode('123456');

      expect(ok, isTrue);
      expect(controller.stage, PhoneSignInStage.verified);
      expect(controller.idToken, 'phone-token');
      expect(gateway.lastSmsCode, '123456');
    });

    test('簡訊額度用盡時停在輸入號碼並顯示訊息', () async {
      final gateway = FakeAuthGateway()
        ..sendFailure = const SocialAuthFailure('quota-exceeded', '簡訊發送次數已達上限，請稍後再試');
      final controller = PhoneSignInController(gateway: gateway, resendCooldown: const Duration(seconds: 3));
      addTearDown(controller.dispose);

      await controller.send('+886912345678');

      expect(controller.stage, PhoneSignInStage.idle);
      expect(controller.error, '簡訊發送次數已達上限，請稍後再試');
    });

    test('自動完成驗證時直接取得 ID Token', () async {
      final gateway = FakeAuthGateway(idToken: 'auto-token')..autoVerify = true;
      final controller = PhoneSignInController(gateway: gateway, resendCooldown: const Duration(seconds: 3));
      addTearDown(controller.dispose);

      await controller.send('+886912345678');

      expect(controller.stage, PhoneSignInStage.verified);
      expect(controller.idToken, 'auto-token');
    });
  });

  group('OAuth 深層連結', () {
    test('解析一次性碼與錯誤代碼', () {
      expect(DeepLinkService.parseOAuthLink('savemybook://auth/oauth?code=abc')?.code, 'abc');
      expect(DeepLinkService.parseOAuthLink('savemybook://auth/oauth?error=OAUTH_FAILED')?.error, 'OAUTH_FAILED');
      expect(DeepLinkService.parseOAuthLink('savemybook://b/0123456789abcdef0123456789abcdef'), isNull);
    });

    test('取得一次性碼後結束等待並關掉 App 內瀏覽器', () async {
      var closed = 0;
      SocialAuth.closeAuthBrowser = () async => closed++;
      SocialAuth.openAuthBrowser = (url) async {
        DeepLinkService.onOAuthResult?.call(const OAuthDeepLink(code: 'one-time-code'));
        return true;
      };
      final result = await SocialAuth.awaitOAuthCode('https://example.com/authorize');
      expect(result.isOk, isTrue);
      expect(result.data, 'one-time-code');
      expect(DeepLinkService.onOAuthResult, isNull, reason: '流程結束後要拆掉處理器');
      expect(closed, 1, reason: '回跳後授權視窗不會自己關');
    });

    test('回呼帶錯誤代碼時轉成可顯示的訊息', () async {
      SocialAuth.openAuthBrowser = (url) async {
        DeepLinkService.onOAuthResult?.call(const OAuthDeepLink(error: AuthCodes.stateInvalid));
        return true;
      };
      final result = await SocialAuth.awaitOAuthCode('https://example.com/authorize');
      expect(result.code, AuthCodes.stateInvalid);
      expect(result.message, AuthCodes.messageOf(AuthCodes.stateInvalid));
    });

    test('無法開啟瀏覽器時回失敗且不留下處理器', () async {
      SocialAuth.openAuthBrowser = (url) async => false;
      final result = await SocialAuth.awaitOAuthCode('https://example.com/authorize');
      expect(result.code, AuthCodes.oauthFailed);
      expect(DeepLinkService.onOAuthResult, isNull);
    });

    test('沒有等待中的流程時深層連結直接丟棄，不會留到下一次登入', () async {
      DeepLinkService.deliver('savemybook://auth/oauth?code=stale-code');

      var opened = 0;
      SocialAuth.openAuthBrowser = (url) async {
        opened++;
        DeepLinkService.onOAuthResult?.call(const OAuthDeepLink(code: 'fresh-code'));
        return true;
      };
      final result = await SocialAuth.awaitOAuthCode('https://example.com/authorize');

      expect(opened, 1, reason: '新的一次登入一定要真的開啟授權頁');
      expect(result.data, 'fresh-code', reason: '不得以上一次留下的碼結束流程');
    });

    test('重複開始授權時前一個等待會被取消，不留下背景計時器', () async {
      SocialAuth.openAuthBrowser = (url) async => true;
      final first = SocialAuth.awaitOAuthCode('https://example.com/authorize');

      SocialAuth.openAuthBrowser = (url) async {
        DeepLinkService.onOAuthResult?.call(const OAuthDeepLink(code: 'second-code'));
        return true;
      };
      final second = await SocialAuth.awaitOAuthCode('https://example.com/authorize');

      expect((await first).isCancelled, isTrue, reason: '舊流程要立刻收掉');
      expect(second.data, 'second-code');
      expect(DeepLinkService.onOAuthResult, isNull);
    });

    testWidgets('關閉授權頁回到 App 後逾寬限時間仍無回呼即視為取消', (tester) async {
      SocialAuth.openAuthBrowser = (url) async => true;
      AuthResult<String>? result;
      unawaited(SocialAuth.awaitOAuthCode('https://example.com/authorize').then((r) => result = r));
      await tester.pump();

      SocialAuth.handleBrowserClosed();
      await tester.pump(SocialAuth.browserCloseGrace ~/ 2);
      expect(result, isNull, reason: '寬限時間內仍要等回呼');

      await tester.pump(SocialAuth.browserCloseGrace);
      expect(result?.isCancelled, isTrue);
      expect(DeepLinkService.onOAuthResult, isNull);
    });

    test('取消等待後不再持有深層連結處理器', () async {
      SocialAuth.openAuthBrowser = (url) async => true;
      final pending = SocialAuth.awaitOAuthCode('https://example.com/authorize');
      SocialAuth.cancelOAuthWait();

      expect((await pending).isCancelled, isTrue);
      expect(DeepLinkService.onOAuthResult, isNull);
    });
  });

  group('尚未綁定帳號時不自動建立', () {
    Map<String, dynamic>? lastSocialBody;
    Map<String, dynamic>? lastExchangeBody;

    MockClient noAccountClient({required bool createSucceeds}) => MockClient((request) async {
          final path = request.url.path.replaceFirst('/api', '');
          final body = request.body.isEmpty
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(jsonDecode(request.body) as Map);

          if (path == '/auth/social') lastSocialBody = body;
          if (path == '/auth/oauth/exchange') lastExchangeBody = body;

          if (path == '/auth/social' || path == '/auth/oauth/exchange') {
            if (body['create'] != true) {
              return _fail(404, AuthCodes.noAccountForProvider, '此 LINE 帳號尚未綁定任何帳號');
            }
            return createSucceeds
                ? _ok({'token': 'new-token'})
                : _fail(403, AuthCodes.signupNotAllowed, '此登入方式僅供既有帳號使用');
          }
          if (path == '/auth/oauth/line/start') return _ok({'url': 'https://example.com/authorize'});
          if (path == '/users/me' || path == '/auth/me') {
            return _ok({'user_id': 1, 'nickname': 'A', 'email': 'a@x.com', 'role': 'buyer_seller'});
          }
          return _ok(<String, Object>{});
        });

    setUp(() {
      lastSocialBody = null;
      lastExchangeBody = null;
    });

    testWidgets('選擇建立新帳號時才帶 create 重送', (tester) async {
      await _pumpFlow(tester, () => SocialSignInFlow.signIn(_ctx!, AuthProviders.google),
          client: noAccountClient(createSucceeds: true));

      expect(find.text(S.createNewAccountWithIdentity), findsOneWidget, reason: '應先詢問使用者');
      expect(lastSocialBody?['create'], isNull, reason: '第一次呼叫不得要求建立帳號');

      await tester.tap(find.text(S.createNewAccountWithIdentity));
      await _settle(tester);

      expect(lastSocialBody?['create'], isTrue);
      expect(_flowResult, isTrue);
    });

    testWidgets('選擇登入既有帳號並綁定時在流程中登入，取消則不建立帳號', (tester) async {
      await _pumpFlow(tester, () => SocialSignInFlow.signIn(_ctx!, AuthProviders.google),
          client: noAccountClient(createSucceeds: true));

      await tester.tap(find.text(S.iAlreadyAccountSignFirst));
      await _settle(tester);

      expect(find.byType(LinkSignInSheet), findsOneWidget, reason: '不再要求使用者先登入再到設定綁定');
      await tester.tap(find.text(S.actionCancel));
      await _settle(tester);

      expect(lastSocialBody?['create'], isNull, reason: '不得建立帳號');
      expect(_flowResult, isFalse);
    });

    testWidgets('取消時不再呼叫伺服器', (tester) async {
      await _pumpFlow(tester, () => SocialSignInFlow.signIn(_ctx!, AuthProviders.google),
          client: noAccountClient(createSucceeds: true));

      await tester.tap(find.text(S.actionCancel));
      await _settle(tester);

      expect(lastSocialBody?['create'], isNull);
      expect(_flowResult, isFalse);
    });

    testWidgets('OAuth 版本以同一組一次性碼重送', (tester) async {
      SocialAuth.openAuthBrowser = (url) async {
        DeepLinkService.onOAuthResult?.call(const OAuthDeepLink(code: 'one-time-code'));
        return true;
      };

      await _pumpFlow(tester, () => SocialSignInFlow.signIn(_ctx!, AuthProviders.line),
          client: noAccountClient(createSucceeds: true));

      expect(lastExchangeBody?['code'], 'one-time-code');
      expect(lastExchangeBody?['create'], isNull);

      await tester.tap(find.text(S.createNewAccountWithIdentity));
      await _settle(tester);

      expect(lastExchangeBody?['code'], 'one-time-code', reason: '不需要重開授權頁');
      expect(lastExchangeBody?['create'], isTrue);
      expect(_flowResult, isTrue);
    });
  });

  group('登入既有帳號並綁定', () {
    final linkBodies = <Map<String, dynamic>>[];
    late String linkFailure;

    MockClient linkClient({String providerEmail = 'member@gmail.com', String firstCode = 'NO_ACCOUNT_FOR_PROVIDER'}) =>
        MockClient((request) async {
          final path = request.url.path.replaceFirst('/api', '');
          final body = request.body.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          switch (path) {
            case '/auth/social':
            case '/auth/oauth/exchange':
              return http.Response(
                jsonEncode({
                  'success': false,
                  'code': firstCode,
                  'message': firstCode == AuthCodes.accountExists ? '此電子郵件已註冊' : '此帳號尚未綁定任何帳號',
                  'provider_email': providerEmail,
                }),
                firstCode == AuthCodes.accountExists ? 409 : 404,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            case '/auth/oauth/line/start':
              return _ok({'url': 'https://example.com/authorize'});
            case '/auth/social/link-login':
              linkBodies.add(body);
              if (linkFailure.isNotEmpty && linkBodies.length == 1) {
                return _fail(401, linkFailure, '密碼錯誤');
              }
              return _ok({'token': 'linked-token'});
            case '/auth/passkeys/login/options':
              return _ok({'options': {'challenge': 'c' * 64, 'rpId': 'savemybook.today'}});
            case '/auth/me':
            case '/users/me':
              return _ok({'user_id': 1, 'nickname': 'A', 'email': 'member@gmail.com', 'role': 'buyer_seller'});
          }
          return _ok(<String, Object>{});
        });

    late MockClient api;

    setUp(() {
      linkBodies.clear();
      linkFailure = '';
    });

    Future<void> tap(WidgetTester tester, Finder finder) async {
      await http.runWithClient(() async {
        await tester.tap(finder);
        await _settle(tester);
      }, () => api);
    }

    Future<void> chooseLink(WidgetTester tester) async {
      await tap(tester, find.text(S.iAlreadyAccountSignFirst));
      expect(find.byType(LinkSignInSheet), findsOneWidget);
    }

    testWidgets('以密碼登入並綁定：預填第三方電子郵件，成功後直接完成登入', (tester) async {
      await _pumpFlow(tester, () => SocialSignInFlow.signIn(_ctx!, AuthProviders.google), client: api = linkClient());
      await chooseLink(tester);

      expect(find.widgetWithText(TextField, 'member@gmail.com'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), 'Passw0rd123');
      await tap(tester, find.text(S.signLink));

      expect(linkBodies.single['provider'], 'google');
      expect(linkBodies.single['id_token'], 'fake-id-token');
      expect(linkBodies.single['email'], 'member@gmail.com');
      expect(linkBodies.single['password'], 'Passw0rd123');
      expect(linkBodies.single.containsKey('code'), isFalse);
      expect(_flowResult, isTrue);
      expect(ApiService.authToken, 'linked-token');
      expect(find.byType(LinkSignInSheet), findsNothing);
    });

    testWidgets('密碼錯誤時留在面板並於密碼欄位提示，修正後可再送出', (tester) async {
      linkFailure = 'INVALID_PASSWORD';
      await _pumpFlow(tester, () => SocialSignInFlow.signIn(_ctx!, AuthProviders.google), client: api = linkClient());
      await chooseLink(tester);

      await tester.enterText(find.byType(TextField).at(1), 'wrong-pass');
      await tap(tester, find.text(S.signLink));

      expect(find.byType(LinkSignInSheet), findsOneWidget);
      expect(find.text('密碼錯誤'), findsOneWidget);
      expect(_flowResult, isNull);

      await tester.enterText(find.byType(TextField).at(1), 'Passw0rd123');
      await tap(tester, find.text(S.signLink));
      expect(linkBodies.length, 2);
      expect(_flowResult, isTrue);
    });

    testWidgets('以通行密鑰登入並綁定', (tester) async {
      SocialSignInFlow.passkeyAvailableOverride = true;
      final client = _LinkPasskeyClient();
      PasskeyService.client = client;
      await _pumpFlow(tester, () => SocialSignInFlow.signIn(_ctx!, AuthProviders.google), client: api = linkClient());
      await chooseLink(tester);

      await tap(tester, find.text(S.signWithPasskey));

      expect(client.immediates, [false], reason: '使用者主動選擇通行密鑰，允許使用其他裝置');
      expect(linkBodies.single['assertion']?['id'], 'cred-1');
      expect(linkBodies.single.containsKey('password'), isFalse);
      expect(_flowResult, isTrue);
    });

    testWidgets('LINE：沿用同一組一次性碼登入並綁定，不重新授權', (tester) async {
      var starts = 0;
      SocialAuth.openAuthBrowser = (url) async {
        starts++;
        DeepLinkService.onOAuthResult?.call(const OAuthDeepLink(code: 'one-time-code'));
        return true;
      };
      await _pumpFlow(tester, () => SocialSignInFlow.signIn(_ctx!, AuthProviders.line), client: api = linkClient());
      await chooseLink(tester);

      await tester.enterText(find.byType(TextField).at(1), 'Passw0rd123');
      await tap(tester, find.text(S.signLink));

      expect(starts, 1);
      expect(linkBodies.single['code'], 'one-time-code');
      expect(linkBodies.single.containsKey('id_token'), isFalse);
      expect(_flowResult, isTrue);
    });

    testWidgets('建立帳號時電子郵件已註冊（409），直接進入登入並綁定', (tester) async {
      await _pumpFlow(
        tester,
        () => SocialSignInFlow.signIn(_ctx!, AuthProviders.google),
        client: api = linkClient(firstCode: AuthCodes.accountExists, providerEmail: 'exists@example.com'),
      );

      expect(find.byType(LinkSignInSheet), findsOneWidget);
      expect(find.widgetWithText(TextField, 'exists@example.com'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), 'Passw0rd123');
      await tap(tester, find.text(S.signLink));
      expect(linkBodies.single['email'], 'exists@example.com');
      expect(_flowResult, isTrue);
    });
  });

  group('綁定與設定回應', () {
    test('綁定成功回傳新的登入方式清單', () async {
      ApiService.authToken = 'session-token';
      final client = _client({
        'POST /auth/link': () => _ok({
              'password_set': false,
              'identities': [
                {
                  'provider': 'google',
                  'display_name': 'A',
                  'masked_email': 'ab***@gmail.com',
                  'masked_phone': null,
                  'created_at': '2026-09-01T00:00:00.000Z',
                  'last_login_at': '2026-09-10T00:00:00.000Z',
                },
              ],
            }),
      });
      final result = await http.runWithClient(
        () => ApiService().linkIdentity(provider: AuthProviders.google, idToken: 't'),
        () => client,
      );

      expect(result.isOk, isTrue);
      expect(result.data!.passwordSet, isFalse);
      expect(result.data!.isLinked(AuthProviders.google), isTrue);
      expect(result.data!.identityOf(AuthProviders.google)!.account, 'ab***@gmail.com');
    });

    test('管理端設定序列化含全部渠道', () {
      final bundle = AuthSettingsBundle.fromJson({
        'settings': {
          'social_enabled': true,
          'providers': {
            'google': {'enabled': true, 'signup': true},
            'line': {'enabled': false, 'signup': false},
          },
        },
        'providers': [
          {'id': 'google', 'name': 'Google', 'configured': true},
          {'id': 'line', 'name': 'LINE', 'configured': false},
        ],
      });

      expect(bundle.isConfigured('line'), isFalse);
      expect(bundle.settings.channelOf('line').enabled, isFalse);

      final json = bundle.settings.toJson();
      expect((json['providers'] as Map).keys, containsAll(AuthProviders.ids));

      final changed = bundle.settings.copyWith(
        id: 'line',
        channel: const AuthChannelSetting(enabled: true, signup: false),
      );
      expect(changed.sameAs(bundle.settings), isFalse);
      expect(bundle.settings.sameAs(bundle.settings), isTrue);
    });
  });
}

class _LinkPasskeyClient implements PasskeyClient {
  final immediates = <bool>[];

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> options) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> get(Map<String, dynamic> options, {bool immediate = true}) async {
    immediates.add(immediate);
    return {
      'id': 'cred-1',
      'rawId': 'cred-1',
      'type': 'public-key',
      'response': {'clientDataJSON': 'e30', 'authenticatorData': 'AAAA', 'signature': 'MEUC'},
    };
  }

  @override
  Future<void> forget({required String rpId, required String credentialId}) async {}
}
