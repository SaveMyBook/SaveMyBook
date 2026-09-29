import 'package:flutter/foundation.dart' show TargetPlatform;

import '../utils/api_helpers.dart';

class PasskeyItem {
  final String passkeyId;
  final String? credentialId;
  final String? deviceLabel;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;
  final bool backedUp;
  final String? authenticator;

  const PasskeyItem({
    required this.passkeyId,
    this.credentialId,
    this.deviceLabel,
    this.createdAt,
    this.lastUsedAt,
    this.backedUp = false,
    this.authenticator,
  });

  factory PasskeyItem.fromJson(Map<String, dynamic> json) => PasskeyItem(
        passkeyId: json['passkey_id'] as String? ?? '',
        credentialId: json['credential_id'] is String ? json['credential_id'] as String : null,
        deviceLabel: (json['device_label'] as String?)?.trim(),
        createdAt: parseDate(json['created_at'])?.toLocal(),
        lastUsedAt: parseDate(json['last_used_at'])?.toLocal(),
        backedUp: json['backed_up'] == true,
        authenticator: json['authenticator'] as String?,
      );
}

/// 舊版伺服器沒有 platforms，缺少的平台一律視為可用。
class PasskeyServerStatus {
  final bool enabled;
  final String? rpId;
  final bool? ios;
  final bool? android;

  const PasskeyServerStatus({required this.enabled, this.rpId, this.ios, this.android});

  factory PasskeyServerStatus.fromJson(Map<String, dynamic> json) {
    final platforms = json['platforms'];
    bool? flag(String key) => platforms is Map && platforms[key] is bool ? platforms[key] as bool : null;
    final rpId = json['rp_id'];
    return PasskeyServerStatus(
      enabled: json['enabled'] == true,
      rpId: rpId is String && rpId.isNotEmpty ? rpId : null,
      ios: flag('ios'),
      android: flag('android'),
    );
  }

  bool usableOn(TargetPlatform platform) {
    if (!enabled) return false;
    final flag = switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => ios,
      TargetPlatform.android => android,
      _ => null,
    };
    return flag != false;
  }
}

class PasskeyOutcome<T> {
  final T? data;
  final String code;
  final String message;

  const PasskeyOutcome.ok(T this.data)
      : code = 'OK',
        message = '';

  const PasskeyOutcome.fail(this.code, this.message) : data = null;

  static const cancelledCode = 'PASSKEY_CANCELLED';

  static const excludedCode = 'PASSKEY_EXCLUDED';

  static const noCredentialsCode = 'PASSKEY_NO_CREDENTIALS';

  static const replaceCode = 'PASSKEY_REPLACE_UNCONFIRMED';

  const PasskeyOutcome.cancelled()
      : data = null,
        code = cancelledCode,
        message = '';

  bool get isOk => code == 'OK';

  bool get isCancelled => code == cancelledCode || code == 'VERIFICATION_CANCELLED';

  bool get isAlreadyRegistered => code == excludedCode || code == 'PASSKEY_ALREADY_REGISTERED' || code == replaceCode;

  bool get needsReplaceConfirmation => code == replaceCode;
}
