import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ai.dart';
import 'api_service.dart';

class AiStatus {
  const AiStatus._();

  static const _freshFor = Duration(seconds: 30);

  static ValueListenable<AiStatusInfo> get listenable => ApiService.aiStatus;

  static AiStatusInfo get value => ApiService.aiStatus.value;

  static DateTime? _fetchedAt;
  static String? _fetchedFor;
  static Future<AiStatusInfo>? _pending;

  static Future<AiStatusInfo> refresh({bool force = false}) {
    final token = ApiService.authToken;
    if (token == null) {
      ApiService.aiStatus.value = AiStatusInfo.none;
      return Future.value(AiStatusInfo.none);
    }
    final fetchedAt = _fetchedAt;
    if (!force && _fetchedFor == token && fetchedAt != null && DateTime.now().difference(fetchedAt) < _freshFor) {
      return Future.value(value);
    }
    return _pending ??= _load(token).whenComplete(() => _pending = null);
  }

  static Future<AiStatusInfo> _load(String token) async {
    final status = await ApiService().fetchAiStatus().timeout(const Duration(seconds: 8), onTimeout: () => null);
    if (ApiService.authToken != token) return AiStatusInfo.none;
    if (status != null) {
      ApiService.aiStatus.value = status;
      _fetchedAt = DateTime.now();
      _fetchedFor = token;
    }
    return value;
  }

  @visibleForTesting
  static void debugSet(AiStatusInfo info) {
    ApiService.aiStatus.value = info;
    _fetchedAt = DateTime.now();
    _fetchedFor = ApiService.authToken;
  }

  static Future<AiResult<AiStatusInfo>> setConsent(bool granted) async {
    final token = ApiService.authToken;
    final result = await ApiService().setAiConsent(granted);
    if (result.isOk && result.data != null && ApiService.authToken == token) {
      ApiService.aiStatus.value = result.data!;
      _fetchedAt = DateTime.now();
      _fetchedFor = token;
    }
    return result;
  }

  static void markConsentRevoked() {
    ApiService.aiStatus.value = value.copyWith(consented: false);
  }

  static void invalidate() {
    _fetchedAt = null;
  }
}
