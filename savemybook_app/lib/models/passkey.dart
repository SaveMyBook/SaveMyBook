import '../utils/api_helpers.dart';

class PasskeyItem {
  /// 伺服器回傳的加密編號，不是流水號。
  final String passkeyId;
  final String? deviceLabel;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;
  final bool backedUp;
  final String? authenticator;

  const PasskeyItem({
    required this.passkeyId,
    this.deviceLabel,
    this.createdAt,
    this.lastUsedAt,
    this.backedUp = false,
    this.authenticator,
  });

  factory PasskeyItem.fromJson(Map<String, dynamic> json) => PasskeyItem(
        passkeyId: json['passkey_id'] as String? ?? '',
        deviceLabel: (json['device_label'] as String?)?.trim(),
        createdAt: parseDate(json['created_at'])?.toLocal(),
        lastUsedAt: parseDate(json['last_used_at'])?.toLocal(),
        backedUp: json['backed_up'] == true,
        authenticator: json['authenticator'] as String?,
      );
}

/// 通行密鑰流程的結果：[cancelled] 為使用者自行取消，不應顯示錯誤。
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

  const PasskeyOutcome.cancelled()
      : data = null,
        code = cancelledCode,
        message = '';

  bool get isOk => code == 'OK';

  bool get isCancelled => code == cancelledCode || code == 'VERIFICATION_CANCELLED';

  bool get isAlreadyRegistered => code == excludedCode || code == 'PASSKEY_ALREADY_REGISTERED';
}
