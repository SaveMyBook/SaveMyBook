part of '../api_service.dart';

class TransitResult<T> {
  final T? data;
  final String? error;

  const TransitResult.success(T this.data) : error = null;

  const TransitResult.failure(String this.error) : data = null;
}

extension TransitApi on ApiService {
  TransitResult<T> _transitResult<T>(Map<String, dynamic>? res, T Function(Map<String, dynamic>) build) {
    if (res == null) return TransitResult.failure(S.pleaseSignFirst);
    final data = res['data'];
    if (res['success'] == true && data is Map) {
      try {
        return TransitResult.success(build(Map<String, dynamic>.from(data)));
      } catch (_) {}
    }
    return TransitResult.failure(res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain);
  }

  Future<TransitResult<TransitNearby>> fetchCabinetNearby(int cabinetId) async =>
      _transitResult(await _send('GET', '/cabinets/$cabinetId/nearby'), TransitNearby.fromJson);

  Future<TransitResult<TransitNearby>> previewNearby(double latitude, double longitude) async => _transitResult(
        await _send('GET', '/admin/cabinets/nearby-preview', query: {
          'lat': latitude.toStringAsFixed(7),
          'lng': longitude.toStringAsFixed(7),
        }),
        TransitNearby.fromJson,
      );

  Future<TransitResult<List<MrtStation>>> fetchMrtStations() async => _transitResult(
        await _send('GET', '/cabinets/mrt-stations'),
        (data) => _mapList({'success': true, 'data': data['stations']}, MrtStation.fromJson),
      );

  Future<TransitResult<List<MrtFare>>> fetchMrtFares(String from, List<String> to) async => _transitResult(
        await _send('GET', '/cabinets/mrt-fares', query: {'from': from, 'to': to.take(3).join(',')}),
        (data) => _mapList({'success': true, 'data': data['fares']}, MrtFare.fromJson),
      );
}
