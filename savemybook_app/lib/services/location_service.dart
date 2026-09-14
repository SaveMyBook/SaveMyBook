import 'package:geolocator/geolocator.dart';
import '../i18n/strings.dart';


class LocationService {
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
