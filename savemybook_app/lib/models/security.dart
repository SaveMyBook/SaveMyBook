import '../utils/api_helpers.dart';

class SecurityStatus {
  final bool available;
  final bool hasPaymentPin;
  final DateTime? pinLockedUntil;
  final bool biometricPayEnabled;

  const SecurityStatus({
    required this.available,
    required this.hasPaymentPin,
    this.pinLockedUntil,
    required this.biometricPayEnabled,
  });

  static const unknown = SecurityStatus(available: false, hasPaymentPin: false, biometricPayEnabled: false);

  factory SecurityStatus.fromJson(Map<String, dynamic> json) => SecurityStatus(
        available: json['available'] != false,
        hasPaymentPin: json['has_payment_pin'] == true,
        pinLockedUntil: parseDate(json['pin_locked_until'])?.toLocal(),
        biometricPayEnabled: json['biometric_pay_enabled'] == true,
      );
}

class LoginSession {
  final int sessionId;
  final String deviceName;
  final String platform;
  final String? appVersion;
  final String? ipAddress;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final bool biometricPay;
  final bool isCurrent;

  const LoginSession({
    required this.sessionId,
    required this.deviceName,
    required this.platform,
    this.appVersion,
    this.ipAddress,
    this.createdAt,
    this.lastSeenAt,
    required this.biometricPay,
    required this.isCurrent,
  });

  factory LoginSession.fromJson(Map<String, dynamic> json) => LoginSession(
        sessionId: parseInt(json['session_id']),
        deviceName: (json['device_name'] as String?)?.trim() ?? '',
        platform: json['platform'] as String? ?? '',
        appVersion: json['app_version'] as String?,
        ipAddress: json['ip_address'] as String?,
        createdAt: parseDate(json['created_at'])?.toLocal(),
        lastSeenAt: parseDate(json['last_seen_at'])?.toLocal(),
        biometricPay: json['biometric_pay'] == true,
        isCurrent: json['is_current'] == true,
      );
}

class VerificationRequest {
  final String scope;
  final List<String> methods;
  final String message;

  const VerificationRequest({required this.scope, required this.methods, required this.message});

  bool get isPayment => scope == 'payment';
}

class PushDeviceInfo {
  final int deviceId;
  final String platform;
  final String tokenTail;
  final DateTime? lastSeenAt;

  const PushDeviceInfo({required this.deviceId, required this.platform, required this.tokenTail, this.lastSeenAt});

  factory PushDeviceInfo.fromJson(Map<String, dynamic> json) => PushDeviceInfo(
        deviceId: parseInt(json['device_id']),
        platform: json['platform'] as String? ?? '',
        tokenTail: json['token_tail'] as String? ?? '',
        lastSeenAt: parseDate(json['last_seen_at'])?.toLocal(),
      );
}

class ServerStatus {
  static const requiredApiRevision = 11;

  final bool reachable;
  final int apiRevision;
  final String? commit;
  final List<String> pendingMigrations;

  const ServerStatus({required this.reachable, required this.apiRevision, this.commit, this.pendingMigrations = const []});

  bool get isOutdated => apiRevision < requiredApiRevision;
  bool get needsMigration => pendingMigrations.isNotEmpty;
}
