import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'api_service.dart';
import 'locale_provider.dart';

class HomeWidgetService {
  static const appGroupId = 'group.today.savemybook.app';
  static const iOSKind = 'SaveMyBookSummaryWidget';
  // namespace（com.example.savemybook_app）與 applicationId 不同，只給類別名稱會被外掛解析到錯誤的套件。
  static const androidProvider = 'com.example.savemybook_app.SaveMyBookWidgetProvider';

  static const _minInterval = Duration(seconds: 60);
  static const _readyStatuses = {'deposited', 'pending_pickup'};

  static DateTime? _lastSync;
  static Future<void>? _running;
  static int _generation = 0;

  static bool get _supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  static Future<void> init() async {
    if (!_supported) return;
    await _ensureGroup();
  }

  static Future<void> sync({bool force = false}) {
    if (!_supported) return Future.value();
    final running = _running;
    if (running != null) return running;
    final last = _lastSync;
    if (!force && last != null && DateTime.now().difference(last) < _minInterval) {
      return Future.value();
    }
    final future = _sync().whenComplete(() => _running = null);
    _running = future;
    return future;
  }

  static Future<void> clear() async {
    if (!_supported) return;
    _generation++;
    _lastSync = null;
    try {
      await _write(signedIn: false);
    } catch (_) {}
  }

  static Future<void> _sync() async {
    final generation = _generation;
    try {
      if (ApiService.authToken == null) {
        await _write(signedIn: false);
        _lastSync = DateTime.now();
        return;
      }
      if (!await _online()) return;

      final api = ApiService();
      final (buying, selling, unread, wallet) = await (
        api.fetchOrders(role: 'buyer', tab: 'pending_pickup'),
        api.fetchOrders(role: 'seller', tab: 'pending_deposit'),
        api.fetchUnreadChatCount(),
        api.fetchWallet(),
      ).wait;

      if (generation != _generation || ApiService.authToken == null) return;

      final ready = buying.where((o) => _readyStatuses.contains(o.status)).toList();
      final first = ready.isEmpty
          ? null
          : ready.firstWhere((o) => (o.pickupCode ?? '').isNotEmpty, orElse: () => ready.first);

      await _write(
        signedIn: true,
        pickupCount: ready.length,
        pickupCabinet: first?.cabinetName ?? '',
        pickupCode: first?.pickupCode ?? '',
        depositCount: selling.where((o) => o.status == 'pending_deposit').length,
        unreadChat: unread,
        coins: wallet.balance.toStringAsFixed(0),
      );
      _lastSync = DateTime.now();
    } catch (_) {}
  }

  static Future<bool> _online() async {
    try {
      final host = Uri.parse(ApiService.baseUrl).host;
      final result = await InternetAddress.lookup(host).timeout(const Duration(seconds: 5));
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _ensureGroup() async {
    if (!Platform.isIOS || HomeWidget.groupId == appGroupId) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (_) {}
  }

  static Future<void> _write({
    required bool signedIn,
    int pickupCount = 0,
    String pickupCabinet = '',
    String pickupCode = '',
    int depositCount = 0,
    int unreadChat = 0,
    String coins = '',
  }) async {
    await _ensureGroup();
    final now = DateTime.now();
    final values = <String, String>{
      'smb_signed_in': signedIn ? '1' : '0',
      'smb_pickup_count': '$pickupCount',
      'smb_pickup_cabinet': pickupCabinet,
      'smb_pickup_code': pickupCode,
      'smb_deposit_count': '$depositCount',
      'smb_unread_chat': '$unreadChat',
      'smb_coins': coins,
      'smb_updated_at': signedIn ? '${_two(now.hour)}:${_two(now.minute)}' : '',
      'smb_lang': _languageTag(),
    };
    await Future.wait([
      for (final entry in values.entries) HomeWidget.saveWidgetData<String>(entry.key, entry.value),
    ]);
    await HomeWidget.updateWidget(iOSName: iOSKind, qualifiedAndroidName: androidProvider);
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _languageTag() {
    try {
      final locale = localeProvider.value ??
          LocaleProvider.resolve(PlatformDispatcher.instance.locales, LocaleProvider.supported);
      return LocaleProvider.tagOf(locale);
    } catch (_) {
      return '';
    }
  }
}
