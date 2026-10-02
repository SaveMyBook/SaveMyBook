import 'package:url_launcher/url_launcher.dart';

enum TravelMode { walking, driving, transit }

// 以 Google 地圖的通用網址開啟：裝了 App 會直接開 App，否則開瀏覽器，iOS 與 Android 都適用。
Future<bool> openDirections(double latitude, double longitude, {TravelMode? mode}) => _launch(Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
      if (mode != null) 'travelmode': mode.name,
    }));

Future<bool> openMapAt(double latitude, double longitude) =>
    _launch(Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$latitude,$longitude'}));

Future<bool> openMapSearch(String query) => _launch(Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query}));

Future<bool> _launch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
