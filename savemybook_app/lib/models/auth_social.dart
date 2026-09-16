import '../utils/api_helpers.dart';
import '../i18n/strings.dart';

class AuthProviders {
  const AuthProviders._();

  static const google = 'google';
  static const apple = 'apple';
  static const phone = 'phone';
  static const line = 'line';
  static const discord = 'discord';

  static const ids = [google, apple, phone, line, discord];

  /// 走 Firebase ID Token 的渠道，其餘走伺服器端的 OAuth 授權碼流程。
  static const firebaseIds = [google, apple, phone];

  static const oauthIds = [line, discord];

  static bool isOauth(String id) => oauthIds.contains(id);

  static String labelOf(String id) => switch (id) {
        google => 'Google',
        apple => 'Apple',
        phone => S.mobileNumber,
        line => 'LINE',
        discord => 'Discord',
        _ => id,
      };
}

class AuthProviderOption {
  final String id;
  final bool enabled;
  final bool signup;
  final bool configured;

  const AuthProviderOption({
    required this.id,
    required this.enabled,
    required this.signup,
    required this.configured,
  });

  factory AuthProviderOption.fromJson(Map<String, dynamic> json) => AuthProviderOption(
        id: json['id'] as String? ?? '',
        enabled: json['enabled'] == true,
        signup: json['signup'] == true,
        configured: json['configured'] == true,
      );

  String get label => AuthProviders.labelOf(id);
}

class AuthProvidersInfo {
  final bool socialEnabled;
  final List<AuthProviderOption> providers;

  const AuthProvidersInfo({required this.socialEnabled, this.providers = const []});

  static const none = AuthProvidersInfo(socialEnabled: false);

  factory AuthProvidersInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['providers'];
    return AuthProvidersInfo(
      socialEnabled: json['social_enabled'] == true,
      providers: [
        if (raw is List)
          for (final item in raw)
            if (item is Map) AuthProviderOption.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  AuthProviderOption? optionOf(String id) {
    for (final option in providers) {
      if (option.id == id) return option;
    }
    return null;
  }

  bool isEnabled(String id) => socialEnabled && (optionOf(id)?.enabled ?? false);

  List<AuthProviderOption> get enabled =>
      socialEnabled ? providers.where((p) => p.enabled).toList() : const [];
}

class AuthIdentity {
  final String provider;
  final String? displayName;
  final String? maskedEmail;
  final String? maskedPhone;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  const AuthIdentity({
    required this.provider,
    this.displayName,
    this.maskedEmail,
    this.maskedPhone,
    this.createdAt,
    this.lastLoginAt,
  });

  factory AuthIdentity.fromJson(Map<String, dynamic> json) => AuthIdentity(
        provider: json['provider'] as String? ?? '',
        displayName: json['display_name'] as String?,
        maskedEmail: json['masked_email'] as String?,
        maskedPhone: json['masked_phone'] as String?,
        createdAt: parseDate(json['created_at'])?.toLocal(),
        lastLoginAt: parseDate(json['last_login_at'])?.toLocal(),
      );

  String get label => AuthProviders.labelOf(provider);

  String? get account {
    final value = maskedPhone ?? maskedEmail ?? displayName;
    return value == null || value.isEmpty ? null : value;
  }
}

class AuthIdentityList {
  final bool passwordSet;
  final List<AuthIdentity> identities;

  const AuthIdentityList({required this.passwordSet, this.identities = const []});

  static const unknown = AuthIdentityList(passwordSet: true);

  factory AuthIdentityList.fromJson(Map<String, dynamic> json) {
    final raw = json['identities'];
    return AuthIdentityList(
      passwordSet: json['password_set'] != false,
      identities: [
        if (raw is List)
          for (final item in raw)
            if (item is Map) AuthIdentity.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  bool isLinked(String provider) => identities.any((i) => i.provider == provider);

  AuthIdentity? identityOf(String provider) {
    for (final identity in identities) {
      if (identity.provider == provider) return identity;
    }
    return null;
  }
}

class AuthChannelSetting {
  final bool enabled;
  final bool signup;

  const AuthChannelSetting({required this.enabled, required this.signup});

  AuthChannelSetting copyWith({bool? enabled, bool? signup}) =>
      AuthChannelSetting(enabled: enabled ?? this.enabled, signup: signup ?? this.signup);

  Map<String, dynamic> toJson() => {'enabled': enabled, 'signup': signup};
}

class AuthSettings {
  final bool socialEnabled;
  final Map<String, AuthChannelSetting> providers;

  const AuthSettings({required this.socialEnabled, required this.providers});

  factory AuthSettings.fromJson(Map<String, dynamic> json) {
    final raw = json['providers'];
    final map = <String, AuthChannelSetting>{};
    for (final id in AuthProviders.ids) {
      final item = raw is Map ? raw[id] : null;
      map[id] = AuthChannelSetting(
        enabled: item is Map && item['enabled'] == true,
        signup: item is Map && item['signup'] == true,
      );
    }
    return AuthSettings(socialEnabled: json['social_enabled'] == true, providers: map);
  }

  AuthChannelSetting channelOf(String id) =>
      providers[id] ?? const AuthChannelSetting(enabled: false, signup: false);

  AuthSettings copyWith({bool? socialEnabled, String? id, AuthChannelSetting? channel}) => AuthSettings(
        socialEnabled: socialEnabled ?? this.socialEnabled,
        providers: {
          ...providers,
          if (id != null && channel != null) id: channel,
        },
      );

  Map<String, dynamic> toJson() => {
        'social_enabled': socialEnabled,
        'providers': {for (final id in AuthProviders.ids) id: channelOf(id).toJson()},
      };

  bool sameAs(AuthSettings other) {
    if (socialEnabled != other.socialEnabled) return false;
    for (final id in AuthProviders.ids) {
      final a = channelOf(id);
      final b = other.channelOf(id);
      if (a.enabled != b.enabled || a.signup != b.signup) return false;
    }
    return true;
  }
}

class AuthProviderMeta {
  final String id;
  final String name;
  final bool configured;

  const AuthProviderMeta({required this.id, required this.name, required this.configured});

  factory AuthProviderMeta.fromJson(Map<String, dynamic> json) => AuthProviderMeta(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        configured: json['configured'] == true,
      );
}

class AuthSettingsBundle {
  final AuthSettings settings;
  final List<AuthProviderMeta> providers;
  final bool migrationReady;

  const AuthSettingsBundle({
    required this.settings,
    required this.providers,
    required this.migrationReady,
  });

  factory AuthSettingsBundle.fromJson(Map<String, dynamic> json) {
    final raw = json['providers'];
    return AuthSettingsBundle(
      settings: AuthSettings.fromJson(
          json['settings'] is Map ? Map<String, dynamic>.from(json['settings'] as Map) : {}),
      providers: [
        if (raw is List)
          for (final item in raw)
            if (item is Map) AuthProviderMeta.fromJson(Map<String, dynamic>.from(item)),
      ],
      migrationReady: json['migration_ready'] == true,
    );
  }

  bool isConfigured(String id) {
    for (final meta in providers) {
      if (meta.id == id) return meta.configured;
    }
    return false;
  }
}

/// 伺服器與 App 共用的登入相關錯誤代碼。
class AuthCodes {
  const AuthCodes._();

  static const noAccountForProvider = 'NO_ACCOUNT_FOR_PROVIDER';
  static const accountExists = 'ACCOUNT_EXISTS_LINK_REQUIRED';
  static const emailRequired = 'EMAIL_REQUIRED';
  static const signupNotAllowed = 'SIGNUP_NOT_ALLOWED';
  static const methodDisabled = 'SIGN_IN_METHOD_DISABLED';
  static const providerMismatch = 'PROVIDER_MISMATCH';
  static const identityTaken = 'IDENTITY_TAKEN';
  static const alreadyLinked = 'ALREADY_LINKED';
  static const lastMethod = 'LAST_SIGN_IN_METHOD';
  static const unavailable = 'AUTH_SOCIAL_UNAVAILABLE';
  static const invalidIdToken = 'INVALID_ID_TOKEN';
  static const passwordAlreadySet = 'PASSWORD_ALREADY_SET';
  static const passwordNotSet = 'PASSWORD_NOT_SET';
  static const stateInvalid = 'OAUTH_STATE_INVALID';
  static const codeInvalid = 'OAUTH_CODE_INVALID';
  static const providerError = 'AUTH_PROVIDER_ERROR';
  static const oauthFailed = 'OAUTH_FAILED';
  static const cancelled = 'CANCELLED';
  static const network = 'NETWORK';
  static const verificationCancelled = 'VERIFICATION_CANCELLED';
  static const notLinked = 'NOT_LINKED';

  /// 沒有伺服器訊息可用時的備援文案。
  static String messageOf(String code) => switch (code) {
        noAccountForProvider => S.signMethodNotLinkedAnyAccount,
        accountExists => S.emailAlreadyRegisteredSignWithPassword,
        emailRequired => S.provideEmailAddressCreateAccount,
        signupNotAllowed => S.signMethodOnlyExistingAccounts,
        methodDisabled => S.signMethodNotAvailableRightNow,
        providerMismatch => S.credentialDoesNotMatchSelectedSign,
        identityTaken => S.signMethodLinkedAnotherAccount,
        alreadyLinked => S.accountAlreadyLinkedSignMethod,
        lastMethod => S.onlySignMethodAccountSetPassword,
        unavailable => S.socialSignUnavailableServerNotFinished,
        invalidIdToken => S.credentialInvalidExpiredPleaseTryAgain,
        passwordAlreadySet => S.accountAlreadyPasswordUseChangePassword,
        passwordNotSet => S.setPasswordFirst,
        stateInvalid => S.signLinkExpiredPleaseTryAgain,
        codeInvalid => S.signResultExpiredPleaseTryAgain,
        providerError => S.thirdPartySignServiceUnavailablePlease,
        oauthFailed => S.couldNotCompleteSignPleaseTry,
        notLinked => S.accountNotLinkedSignMethod,
        network => S.networkError,
        _ => S.signFailedPleaseTryAgain,
      };
}

class AuthResult<T> {
  final T? data;
  final String? code;
  final String? error;

  const AuthResult.ok([this.data])
      : code = null,
        error = null;

  const AuthResult.fail(this.code, this.error) : data = null;

  AuthResult.of(String code) : this.fail(code, AuthCodes.messageOf(code));

  bool get isOk => code == null;

  bool get isCancelled => code == AuthCodes.cancelled || code == AuthCodes.verificationCancelled;

  String get message => error ?? AuthCodes.messageOf(code ?? '');
}
