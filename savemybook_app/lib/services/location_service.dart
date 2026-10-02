import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../i18n/strings.dart';

class FreshLocation {
  static const granted = 'granted';
  static const denied = 'denied';
  static const imprecise = 'imprecise';
  static const unavailable = 'unavailable';

  final String status;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final int? ageMs;

  const FreshLocation({required this.status, this.lat, this.lng, this.accuracyM, this.ageMs});

  bool get isGranted => status == granted && lat != null && lng != null;

  bool get isDenied => status == denied;

  bool get isImprecise => status == imprecise;

  Map<String, dynamic> toJson() => {
    'location_status': isGranted ? granted : (isDenied ? denied : unavailable),
    if (isGranted) 'location': {'lat': lat, 'lng': lng, 'accuracy_m': accuracyM ?? 0, 'age_ms': ageMs ?? 0},
  };
}

enum LocationAccess { granted, denied, imprecise, unavailable }

class LocationService {
  static const precisePurposeKey = 'CabinetUse';
  static const setupPurposeKey = 'CabinetSetup';

  static Position? _last;
  static DateTime? _lastAt;
  static Future<Position?>? _pending;

  static Position? get lastKnown => _last;

  static Future<Position?> current({bool request = true}) {
    final last = _last;
    if (last != null && _lastAt != null && DateTime.now().difference(_lastAt!).inMinutes < 5) {
      return Future.value(last);
    }
    return _pending ??= _locate(request).whenComplete(() => _pending = null);
  }

  static Future<Position?> _locate(bool request) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && request) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)),
      ).catchError((_) async => await Geolocator.getLastKnownPosition() ?? (throw StateError('no position')));
      _last = position;
      _lastAt = DateTime.now();
      return position;
    } catch (_) {
      return null;
    }
  }

  // 書櫃距離檢查只能用當次取得的座標：current() 會回傳 5 分鐘內的快取並退回 getLastKnownPosition()，
  // 剛走到書櫃的人會因舊座標被判定距離過遠。
  static Future<FreshLocation> fresh({
    DateTime Function()? clock,
    String purposeKey = precisePurposeKey,
    Duration timeLimit = const Duration(seconds: 5),
  }) async {
    try {
      final allowed = await access(purposeKey: purposeKey);
      if (allowed != LocationAccess.granted) {
        return FreshLocation(
          status: switch (allowed) {
            LocationAccess.denied => FreshLocation.denied,
            LocationAccess.imprecise => FreshLocation.imprecise,
            _ => FreshLocation.unavailable,
          },
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeLimit),
      );
      final now = (clock ?? DateTime.now)();
      final age = now.difference(position.timestamp).inMilliseconds;
      _last = position;
      _lastAt = now;
      return FreshLocation(
        status: FreshLocation.granted,
        lat: position.latitude,
        lng: position.longitude,
        accuracyM: position.accuracy,
        ageMs: age < 0 ? 0 : age,
      );
    } catch (_) {
      return const FreshLocation(status: FreshLocation.unavailable);
    }
  }

  static Future<LocationAccess?> access({String purposeKey = precisePurposeKey}) async {
    // geolocator 對從未詢問過的權限也回傳 denied，只有 request 才會跳出系統詢問。
    final allowed = await permission(request: true);
    if (allowed == null) return null;
    if (allowed == LocationPermission.denied || allowed == LocationPermission.deniedForever) return LocationAccess.denied;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.unavailable;
    } catch (_) {
      return null;
    }
    return await _precise(purposeKey) ? LocationAccess.granted : LocationAccess.imprecise;
  }

  // 只允許「大約位置」時座標誤差約 1–3 公里，伺服器一律以精度不足拒絕，重試不會改善。
  static Future<bool> _precise(String purposeKey) async {
    try {
      if (await Geolocator.getLocationAccuracy() != LocationAccuracyStatus.reduced) return true;
      final upgraded = defaultTargetPlatform == TargetPlatform.iOS
          ? await Geolocator.requestTemporaryFullAccuracy(purposeKey: purposeKey)
          : await Geolocator.requestPermission().then((_) => Geolocator.getLocationAccuracy());
      return upgraded != LocationAccuracyStatus.reduced;
    } catch (_) {
      return true;
    }
  }

  static Future<LocationPermission?> permission({bool request = false}) async {
    try {
      final current = await Geolocator.checkPermission();
      if (!request || current != LocationPermission.denied) return current;
      return await Geolocator.requestPermission();
    } catch (_) {
      return null;
    }
  }

  static Future<void> openSettings() async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openAppSettings();
      } else {
        await Geolocator.openLocationSettings();
      }
    } catch (_) {}
  }

  static double? distanceTo(double latitude, double longitude) {
    final here = _last;
    if (here == null || (latitude == 0 && longitude == 0)) return null;
    return Geolocator.distanceBetween(here.latitude, here.longitude, latitude, longitude);
  }

  static String formatDistance(num meters) {
    if (meters < 50) return S.nearby;
    if (meters < 1000) {
      final rounded = (meters / 10).round() * 10;
      return S.p0M(rounded);
    }
    final km = meters / 1000;
    final label = km < 10 ? km.toStringAsFixed(1) : km.round().toString();
    return S.p0Km(label);
  }
}
