import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'biometric_service.dart';
import 'location_service.dart';
import 'push_service.dart';

enum AppPermission { notification, camera, photos, photosAddOnly, microphone, location, biometrics }

enum AppPermissionStatus { granted, limited, denied, restricted, permanentlyDenied }

class AppPermissionState {
  final AppPermission permission;
  final AppPermissionStatus status;
  final bool faceId;

  const AppPermissionState(this.permission, this.status, {this.faceId = false});

  bool get isGranted => status == AppPermissionStatus.granted || status == AppPermissionStatus.limited;

  bool get canRequest => status == AppPermissionStatus.denied && permission != AppPermission.biometrics;
}

class AppPermissions {
  const AppPermissions._();

  static const _macChannel = MethodChannel('savemybook/permissions');

  static bool get isSupportedPlatform => switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.android || TargetPlatform.macOS => !kIsWeb,
        _ => false,
      };

  static Future<List<AppPermissionState>> load() async {
    if (!isSupportedPlatform) return const [];
    final permissions = await _applicable();
    final states = <AppPermissionState>[];
    for (final permission in permissions) {
      final state = await _status(permission);
      if (state != null) states.add(state);
    }
    return states;
  }

  static Future<AppPermissionState?> request(AppPermission permission) async {
    final started = DateTime.now();
    AppPermissionStatus? result;
    try {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        result = permission == AppPermission.location
            ? _fromLocation(await LocationService.permission(request: true))
            : _fromMac(await _macChannel.invokeMethod<String>('request', permission.name));
      } else {
        final handle = _handle(permission);
        if (handle != null) result = _fromHandler(await handle.request());
      }
    } catch (_) {}
    if (result == null) return _status(permission);

    if (permission == AppPermission.notification && result == AppPermissionStatus.granted) {
      unawaited(PushService.registerCurrentDevice());
    }
    // Android 對已永久拒絕的權限不會跳出對話框、而是立即回傳，只能引導到系統設定。
    if (defaultTargetPlatform == TargetPlatform.android &&
        result == AppPermissionStatus.permanentlyDenied &&
        DateTime.now().difference(started) < const Duration(milliseconds: 500)) {
      await openSettings(permission);
    }
    return AppPermissionState(permission, result);
  }

  static Future<void> openSettings(AppPermission permission) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        await _macChannel.invokeMethod<void>('openSettings', permission.name);
      } else {
        await openAppSettings();
      }
    } catch (_) {}
  }

  static Future<List<AppPermission>> _applicable() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return AppPermission.values;
      case TargetPlatform.android:
        return [
          AppPermission.notification,
          AppPermission.camera,
          if (await _androidSdk() < 33) AppPermission.photos,
          AppPermission.microphone,
          AppPermission.location,
        ];
      case TargetPlatform.macOS:
        return const [AppPermission.camera, AppPermission.microphone, AppPermission.location];
      default:
        return const [];
    }
  }

  static Future<AppPermissionState?> _status(AppPermission permission) async {
    try {
      if (permission == AppPermission.biometrics) {
        final probe = await BiometricService.probe();
        if (!probe.hardware) return null;
        return AppPermissionState(
          permission,
          probe.usable ? AppPermissionStatus.granted : AppPermissionStatus.denied,
          faceId: probe.faceId,
        );
      }
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final status = permission == AppPermission.location
            ? _fromLocation(await LocationService.permission())
            : _fromMac(await _macChannel.invokeMethod<String>('status', permission.name));
        return AppPermissionState(permission, status ?? AppPermissionStatus.denied);
      }
      final handle = _handle(permission);
      if (handle == null) return null;
      return AppPermissionState(permission, _fromHandler(await handle.status));
    } catch (_) {
      return AppPermissionState(permission, AppPermissionStatus.denied);
    }
  }

  static Permission? _handle(AppPermission permission) => switch (permission) {
        AppPermission.notification => Permission.notification,
        AppPermission.camera => Permission.camera,
        AppPermission.photos => defaultTargetPlatform == TargetPlatform.android ? Permission.storage : Permission.photos,
        AppPermission.photosAddOnly => Permission.photosAddOnly,
        AppPermission.microphone => Permission.microphone,
        AppPermission.location => Permission.locationWhenInUse,
        AppPermission.biometrics => null,
      };

  static Future<int> _androidSdk() async {
    try {
      return (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    } catch (_) {
      return 33;
    }
  }

  static AppPermissionStatus _fromHandler(PermissionStatus status) => switch (status) {
        PermissionStatus.granted => AppPermissionStatus.granted,
        PermissionStatus.limited || PermissionStatus.provisional => AppPermissionStatus.limited,
        PermissionStatus.restricted => AppPermissionStatus.restricted,
        PermissionStatus.permanentlyDenied => AppPermissionStatus.permanentlyDenied,
        PermissionStatus.denied => AppPermissionStatus.denied,
      };

  static AppPermissionStatus? _fromMac(String? status) => switch (status) {
        'granted' => AppPermissionStatus.granted,
        'restricted' => AppPermissionStatus.restricted,
        'denied' => AppPermissionStatus.permanentlyDenied,
        'notDetermined' => AppPermissionStatus.denied,
        _ => null,
      };

  static AppPermissionStatus? _fromLocation(LocationPermission? permission) => switch (permission) {
        LocationPermission.always || LocationPermission.whileInUse => AppPermissionStatus.granted,
        LocationPermission.deniedForever => AppPermissionStatus.permanentlyDenied,
        LocationPermission.denied => AppPermissionStatus.denied,
        LocationPermission.unableToDetermine || null => null,
      };
}
