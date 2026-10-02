import '../utils/api_helpers.dart';

List<Map<String, dynamic>> _maps(dynamic raw) =>
    raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

Map<String, dynamic> _map(dynamic raw) => raw is Map ? Map<String, dynamic>.from(raw) : const {};

int? _intOrNull(dynamic v) => v == null ? null : parseInt(v);

String _text(dynamic v) => v == null ? '' : v.toString().trim();

class TransitPoint {
  final double latitude;
  final double longitude;

  const TransitPoint(this.latitude, this.longitude);

  static TransitPoint? tryParse(Map<String, dynamic> json) {
    final lat = json['latitude'];
    final lng = json['longitude'];
    if (lat == null || lng == null) return null;
    return TransitPoint(parseDouble(lat), parseDouble(lng));
  }
}

enum AccessFacility { elevator, ramp }

class MrtExit {
  // 空字串表示只有一個出口的車站。
  final String exit;
  final bool accessible;
  final AccessFacility? facility;
  final int distanceM;
  final TransitPoint? point;

  const MrtExit({required this.exit, required this.accessible, required this.distanceM, this.facility, this.point});

  static MrtExit? tryParse(dynamic raw) {
    final json = _map(raw);
    if (json.isEmpty) return null;
    return MrtExit(
      exit: _text(json['exit']),
      accessible: json['accessible'] == true,
      facility: switch (json['facility']) {
        'elevator' => AccessFacility.elevator,
        'ramp' => AccessFacility.ramp,
        _ => null,
      },
      distanceM: parseInt(json['distance_m']),
      point: TransitPoint.tryParse(json),
    );
  }
}

enum BusStatus { arriving, minutes, notDeparted, unknown, notStopping, lastPassed, noService }

class BusArrival {
  final String route;
  final String direction;
  final BusStatus status;
  final int? minutes;

  const BusArrival({required this.route, required this.direction, required this.status, this.minutes});

  factory BusArrival.fromJson(Map<String, dynamic> json) => BusArrival(
        route: _text(json['name']),
        direction: _text(json['direction']),
        status: switch (json['status']) {
          'arriving' => BusStatus.arriving,
          'minutes' => BusStatus.minutes,
          'not_departed' => BusStatus.notDeparted,
          'not_stopping' => BusStatus.notStopping,
          'last_passed' => BusStatus.lastPassed,
          'no_service' => BusStatus.noService,
          _ => BusStatus.unknown,
        },
        minutes: _intOrNull(json['minutes']),
      );
}

class BusStop {
  final String name;
  final String address;
  final TransitPoint? point;
  final int distanceM;
  final List<BusArrival> routes;

  const BusStop({required this.name, required this.address, required this.distanceM, required this.routes, this.point});

  factory BusStop.fromJson(Map<String, dynamic> json) => BusStop(
        name: _text(json['name']),
        address: _text(json['address']),
        point: TransitPoint.tryParse(json),
        distanceM: parseInt(json['distance_m']),
        routes: [for (final r in _maps(json['routes'])) BusArrival.fromJson(r)],
      );
}

enum TrafficLevel { smooth, busy, congested }

class RoadSection {
  final String road;
  final String between;
  final int speedKph;
  final TrafficLevel level;
  final int distanceM;

  const RoadSection({required this.road, required this.between, required this.speedKph, required this.level, required this.distanceM});

  factory RoadSection.fromJson(Map<String, dynamic> json) => RoadSection(
        road: _text(json['road']),
        between: _text(json['between']),
        speedKph: parseInt(json['speed_kph']),
        level: switch (json['level']) {
          'congested' => TrafficLevel.congested,
          'busy' => TrafficLevel.busy,
          _ => TrafficLevel.smooth,
        },
        distanceM: parseInt(json['distance_m']),
      );
}

class TaxiStand {
  final String name;
  final String street;
  final int? spaces;
  final String hours;
  final TransitPoint? point;
  final int distanceM;

  const TaxiStand({required this.name, required this.street, required this.hours, required this.distanceM, this.spaces, this.point});

  factory TaxiStand.fromJson(Map<String, dynamic> json) => TaxiStand(
        name: _text(json['name']),
        street: _text(json['street']),
        spaces: _intOrNull(json['spaces']),
        hours: _text(json['hours']),
        point: TransitPoint.tryParse(json),
        distanceM: parseInt(json['distance_m']),
      );
}

class MrtNearbyStation {
  final String name;
  final int distanceM;
  final MrtExit? nearestExit;
  final MrtExit? accessibleExit;

  const MrtNearbyStation({required this.name, required this.distanceM, this.nearestExit, this.accessibleExit});

  factory MrtNearbyStation.fromJson(Map<String, dynamic> json) => MrtNearbyStation(
        name: _text(json['name']),
        distanceM: parseInt(json['distance_m']),
        nearestExit: MrtExit.tryParse(json['nearest_exit']),
        accessibleExit: MrtExit.tryParse(json['accessible_exit']),
      );
}

class YoubikeStation {
  final String name;
  final String address;
  final TransitPoint? point;
  final int distanceM;
  final int availableRent;
  final int availableReturn;
  final int total;
  final bool active;

  const YoubikeStation({
    required this.name,
    required this.address,
    required this.distanceM,
    required this.availableRent,
    required this.availableReturn,
    required this.total,
    required this.active,
    this.point,
  });

  factory YoubikeStation.fromJson(Map<String, dynamic> json) => YoubikeStation(
        name: _text(json['name']),
        address: _text(json['address']),
        point: TransitPoint.tryParse(json),
        distanceM: parseInt(json['distance_m']),
        availableRent: parseInt(json['available_rent']),
        availableReturn: parseInt(json['available_return']),
        total: parseInt(json['total']),
        active: json['is_active'] != false,
      );
}

class ParkingCapacity {
  final int total;
  final int? available;

  const ParkingCapacity({required this.total, this.available});

  bool get exists => total > 0 || available != null;

  factory ParkingCapacity.fromJson(dynamic raw) {
    final json = _map(raw);
    return ParkingCapacity(total: parseInt(json['total']), available: _intOrNull(json['available']));
  }
}

class ParkingLot {
  final String name;
  final String address;
  final String fee;
  final String hours;
  final TransitPoint? point;
  final int distanceM;
  final ParkingCapacity car;
  final ParkingCapacity motorcycle;

  const ParkingLot({
    required this.name,
    required this.address,
    required this.fee,
    required this.hours,
    required this.distanceM,
    required this.car,
    required this.motorcycle,
    this.point,
  });

  factory ParkingLot.fromJson(Map<String, dynamic> json) => ParkingLot(
        name: _text(json['name']),
        address: _text(json['address']),
        fee: _text(json['fee']),
        hours: _text(json['hours']),
        point: TransitPoint.tryParse(json),
        distanceM: parseInt(json['distance_m']),
        car: ParkingCapacity.fromJson(json['car']),
        motorcycle: ParkingCapacity.fromJson(json['motorcycle']),
      );
}

class RoadsideLive {
  final int? total;
  final int? available;
  final String fee;
  final String start;
  final String end;

  const RoadsideLive({this.total, this.available, this.fee = '', this.start = '', this.end = ''});

  static RoadsideLive? tryParse(dynamic raw) {
    final json = _map(raw);
    if (json.isEmpty) return null;
    return RoadsideLive(
      total: _intOrNull(json['total']),
      available: _intOrNull(json['available']),
      fee: _text(json['fee']),
      start: _text(json['start']),
      end: _text(json['end']),
    );
  }
}

class RoadsideSegment {
  final String name;
  final TransitPoint? point;
  final int distanceM;
  final int spacesNearby;
  final int accessibleNearby;
  final bool hasParkingArea;
  final RoadsideLive? live;

  const RoadsideSegment({
    required this.name,
    required this.distanceM,
    required this.spacesNearby,
    required this.accessibleNearby,
    this.hasParkingArea = false,
    this.point,
    this.live,
  });

  factory RoadsideSegment.fromJson(Map<String, dynamic> json) => RoadsideSegment(
        name: _text(json['name']),
        point: TransitPoint.tryParse(json),
        distanceM: parseInt(json['distance_m']),
        spacesNearby: parseInt(json['spaces_nearby']),
        accessibleNearby: parseInt(json['accessible_nearby']),
        hasParkingArea: json['has_parking_area'] == true,
        live: RoadsideLive.tryParse(json['live']),
      );
}

class TransitSection<T> {
  final bool available;
  final DateTime? updatedAt;
  final List<T> items;

  const TransitSection({required this.available, required this.items, this.updatedAt});

  static TransitSection<T> parse<T>(dynamic raw, String listKey, T Function(Map<String, dynamic>) build) {
    final json = _map(raw);
    return TransitSection<T>(
      available: json['status'] == 'ok',
      updatedAt: parseDate(json['updated_at']),
      items: [for (final item in _maps(json[listKey])) build(item)],
    );
  }
}

class TransitNearby {
  final TransitPoint? cabinet;
  final TransitSection<MrtNearbyStation> mrt;
  final TransitSection<BusStop> bus;
  final TransitSection<RoadSection> roadSpeed;
  final TransitSection<TaxiStand> taxiStands;
  final TransitSection<YoubikeStation> youbike;
  final TransitSection<ParkingLot> parkingLots;
  final bool roadsideAvailable;
  final int roadsideRadiusM;
  final DateTime? roadsideUpdatedAt;
  final List<RoadsideSegment> roadsideCar;
  final List<RoadsideSegment> roadsideMotorcycle;

  const TransitNearby({
    required this.mrt,
    required this.bus,
    required this.roadSpeed,
    required this.taxiStands,
    required this.youbike,
    required this.parkingLots,
    required this.roadsideAvailable,
    required this.roadsideRadiusM,
    required this.roadsideCar,
    required this.roadsideMotorcycle,
    this.cabinet,
    this.roadsideUpdatedAt,
  });

  factory TransitNearby.fromJson(Map<String, dynamic> json) {
    final roadside = _map(json['roadside']);
    return TransitNearby(
      cabinet: TransitPoint.tryParse(_map(json['cabinet'])),
      mrt: TransitSection.parse(json['mrt'], 'stations', MrtNearbyStation.fromJson),
      bus: TransitSection.parse(json['bus'], 'stops', BusStop.fromJson),
      roadSpeed: TransitSection.parse(json['road_speed'], 'sections', RoadSection.fromJson),
      taxiStands: TransitSection.parse(json['taxi_stands'], 'stands', TaxiStand.fromJson),
      youbike: TransitSection.parse(json['youbike'], 'stations', YoubikeStation.fromJson),
      parkingLots: TransitSection.parse(json['parking_lots'], 'lots', ParkingLot.fromJson),
      roadsideAvailable: roadside['status'] == 'ok',
      roadsideRadiusM: roadside['radius_m'] == null ? 300 : parseInt(roadside['radius_m']),
      roadsideUpdatedAt: parseDate(roadside['updated_at']),
      roadsideCar: [for (final item in _maps(roadside['car'])) RoadsideSegment.fromJson(item)],
      roadsideMotorcycle: [for (final item in _maps(roadside['motorcycle'])) RoadsideSegment.fromJson(item)],
    );
  }
}

class MrtStation {
  final String name;
  final double latitude;
  final double longitude;

  const MrtStation({required this.name, required this.latitude, required this.longitude});

  factory MrtStation.fromJson(Map<String, dynamic> json) => MrtStation(
        name: _text(json['name']),
        latitude: parseDouble(json['latitude']),
        longitude: parseDouble(json['longitude']),
      );
}

class MrtFare {
  final String from;
  final String to;
  final int? fare;
  final int? concessionFare;
  final double? distanceKm;

  const MrtFare({required this.from, required this.to, this.fare, this.concessionFare, this.distanceKm});

  factory MrtFare.fromJson(Map<String, dynamic> json) => MrtFare(
        from: _text(json['from']),
        to: _text(json['to']),
        fare: _intOrNull(json['fare']),
        concessionFare: _intOrNull(json['concession_fare']),
        distanceKm: json['distance_km'] == null ? null : parseDouble(json['distance_km']),
      );
}
