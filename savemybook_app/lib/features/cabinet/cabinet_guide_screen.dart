import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../i18n/strings.dart';
import '../../models/transit.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/map_links.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_select.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';

String mrtStationLabel(String name) => name.endsWith('站') ? name : S.mrtStationP0(name);

// 不沿用 LocationService.formatDistance：50 公尺內顯示「附近」，與路邊停車的「附近 N 格」並列時語意重複。
String transitDistance(int meters) {
  if (meters < 1000) return S.p0M(math.max(10, (meters / 10).round() * 10));
  final km = meters / 1000;
  return S.p0Km(km < 10 ? km.toStringAsFixed(1) : km.round().toString());
}

String mrtExitLabel(String exit) => exit.isEmpty ? S.singleExit : S.mrtExitP0(exit);

String? mrtAccessLabel(MrtExit? e) {
  if (e == null) return null;
  return switch (e.facility) {
    AccessFacility.elevator => e.exit.isEmpty ? S.accessibleElevator : S.accessibleElevatorP0(e.exit),
    AccessFacility.ramp => e.exit.isEmpty ? S.accessibleRamp : S.accessibleRampP0(e.exit),
    null => e.exit.isEmpty ? null : S.accessibleExitP0(e.exit),
  };
}

String transitTime(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final now = DateTime.now();
  if (local.year == now.year && local.month == now.month && local.day == now.day) {
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  return formatDateTime(local);
}

class CabinetGuideScreen extends StatefulWidget {
  final int cabinetId;
  final String name;
  final String address;
  final String openHours;

  const CabinetGuideScreen({
    super.key,
    required this.cabinetId,
    required this.name,
    this.address = '',
    this.openHours = '',
  });

  static Future<void> open(BuildContext context, {required int cabinetId, required String name, String address = '', String openHours = ''}) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CabinetGuideScreen(cabinetId: cabinetId, name: name, address: address, openHours: openHours),
    ));
  }

  @override
  State<CabinetGuideScreen> createState() => _CabinetGuideScreenState();
}

class _CabinetGuideScreenState extends State<CabinetGuideScreen> {
  static const _departureKey = 'transit.departure_station';
  static const double _splitWidth = 700;

  final _api = ApiService();

  TransitNearby? _nearby;
  String? _error;
  bool _loading = true;

  List<MrtStation>? _stations;
  String? _departure;
  List<MrtFare> _fares = const [];
  bool _faresLoading = false;
  String? _faresError;

  int _parkingTab = 0;
  final Set<int> _expandedStops = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _api.fetchCabinetNearby(widget.cabinetId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.error;
      if (result.data != null) _nearby = result.data;
    });
    if (result.data != null) await _initDeparture();
  }

  List<String> get _destinations => [for (final s in _nearby?.mrt.items ?? const <MrtNearbyStation>[]) s.name];

  // 起站：上次選過的站優先，否則用手機定位算出最近的車站；只用已授權的定位，不在此頁跳出權限詢問。
  Future<void> _initDeparture() async {
    if (_destinations.isEmpty) return;
    var departure = _departure;
    if (departure == null) {
      try {
        departure = (await SharedPreferences.getInstance()).getString(_departureKey);
      } catch (_) {}
    }
    if (departure == null) {
      final here = LocationService.lastKnown ?? await LocationService.current(request: false);
      if (here != null) {
        final stations = await _loadStations();
        departure = _nearestStation(stations, here.latitude, here.longitude)?.name;
      }
    }
    if (!mounted || departure == null) return;
    setState(() => _departure = departure);
    await _loadFares();
  }

  Future<List<MrtStation>> _loadStations() async {
    final cached = _stations;
    if (cached != null) return cached;
    final result = await _api.fetchMrtStations();
    final list = result.data ?? const <MrtStation>[];
    if (result.data != null) _stations = list;
    return list;
  }

  MrtStation? _nearestStation(List<MrtStation> stations, double lat, double lng) {
    MrtStation? best;
    var bestDistance = double.infinity;
    for (final s in stations) {
      final d = Geolocator.distanceBetween(lat, lng, s.latitude, s.longitude);
      if (d < bestDistance) {
        best = s;
        bestDistance = d;
      }
    }
    return best;
  }

  Future<void> _loadFares() async {
    final from = _departure;
    if (from == null || _destinations.isEmpty) return;
    setState(() {
      _faresLoading = true;
      _faresError = null;
    });
    final result = await _api.fetchMrtFares(from, _destinations);
    if (!mounted) return;
    setState(() {
      _faresLoading = false;
      _fares = result.data ?? const [];
      _faresError = result.error;
    });
  }

  Future<void> _pickDeparture() async {
    HapticFeedback.selectionClick();
    final stations = await runBusy(context, _loadStations);
    if (!mounted) return;
    if (stations == null || stations.isEmpty) {
      showAppSnackBar(context, S.transitDataUnavailable, isError: true);
      return;
    }
    final here = LocationService.lastKnown;
    final sorted = [...stations];
    if (here != null) {
      double d(MrtStation s) => Geolocator.distanceBetween(here.latitude, here.longitude, s.latitude, s.longitude);
      sorted.sort((a, b) => d(a).compareTo(d(b)));
    }
    final picked = await showAppPicker<String>(
      context,
      title: S.departureStation,
      subtitle: S.departureStationHint,
      searchable: true,
      selected: _departure,
      options: [
        for (final s in sorted)
          AppSelectOption<String>(
            value: s.name,
            label: mrtStationLabel(s.name),
            icon: Icons.directions_subway_rounded,
            trailing: here == null
                ? null
                : transitDistance(Geolocator.distanceBetween(here.latitude, here.longitude, s.latitude, s.longitude).round()),
          ),
      ],
    );
    if (picked == null || !mounted || picked == _departure) return;
    setState(() => _departure = picked);
    try {
      await (await SharedPreferences.getInstance()).setString(_departureKey, picked);
    } catch (_) {}
    await _loadFares();
  }

  Future<void> _refresh() async {
    await _load();
  }

  Future<void> _navigateToCabinet() async {
    HapticFeedback.selectionClick();
    final point = _nearby?.cabinet;
    final ok = point != null
        ? await openDirections(point.latitude, point.longitude)
        : await openMapSearch([widget.name, widget.address].where((s) => s.isNotEmpty).join(' '));
    if (!ok && mounted) showAppSnackBar(context, S.somethingWentWrongPleaseTryAgain, isError: true);
  }

  Future<void> _copyAddress() async {
    final text = [widget.name, widget.address].where((s) => s.isNotEmpty).join(' ');
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    if (mounted) showAppSnackBar(context, S.copied(S.address));
  }

  void _go(TransitPoint? point, TravelMode mode, {String? fallbackQuery}) {
    HapticFeedback.selectionClick();
    if (point != null) {
      openDirections(point.latitude, point.longitude, mode: mode);
    } else if (fallbackQuery != null) {
      openMapSearch(fallbackQuery);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.getToLocker, icon: Icons.directions_rounded),
          Expanded(
            child: RefreshIndicator(
              color: c.accent,
              onRefresh: _refresh,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final data = _nearby;
                  final split = !_loading && data != null && constraints.maxWidth >= _splitWidth;
                  final padding = responsiveListPadding(
                    constraints,
                    maxWidth: split ? 1160 : Breakpoints.readingMaxWidth,
                    horizontal: context.isWide ? 24 : 20,
                    top: 20,
                    bottom: MediaQuery.of(context).padding.bottom + 40,
                  );
                  if (split) {
                    Widget column(List<Widget> items, int start) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, item) in items.indexed) ...[
                          if (i > 0) const SizedBox(height: 14),
                          FadeSlideIn(index: start + i, child: item),
                        ],
                      ],
                    );
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: padding,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: column([_buildCabinetCard(c), _buildMrtCard(c, data), _buildYoubikeCard(c, data)], 0),
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: column([_buildBusCard(c, data), _buildParkingCard(c, data)], 3)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        FadeSlideIn(index: 5, child: _buildFooter(c)),
                      ],
                    );
                  }
                  final sections = <Widget>[
                    _buildCabinetCard(c),
                    if (_loading)
                      const Padding(padding: EdgeInsets.only(top: 40), child: LoadingView())
                    else if (_nearby == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: ErrorView(message: _error, onRetry: () {
                          setState(() => _loading = true);
                          _load();
                        }),
                      )
                    else ...[
                      _buildMrtCard(c, _nearby!),
                      _buildBusCard(c, _nearby!),
                      _buildYoubikeCard(c, _nearby!),
                      _buildParkingCard(c, _nearby!),
                      _buildFooter(c),
                    ],
                  ];
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: padding,
                    itemCount: sections.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => FadeSlideIn(index: i, child: sections[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCabinetCard(AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.storage_rounded, size: 18, color: c.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.name.isEmpty ? S.faqCatCabinet : widget.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
              ),
            ],
          ),
          if (widget.address.isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoLine(icon: Icons.location_on_outlined, value: widget.address, fontSize: 13, maxLines: 3),
          ],
          if (widget.openHours.isNotEmpty) ...[
            const SizedBox(height: 6),
            InfoLine(icon: Icons.schedule_rounded, value: '${S.openingHours} ${widget.openHours}', fontSize: 13),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(label: S.navigate, icon: Icons.directions_rounded, onPressed: _navigateToCabinet),
              ),
              if (widget.address.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: SecondaryButton(label: S.copyAddress, icon: Icons.copy_rounded, onPressed: _copyAddress),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMrtCard(AppColors c, TransitNearby data) {
    final section = data.mrt;
    return _SectionCard(
      title: S.transitMrt,
      icon: Icons.directions_subway_rounded,
      children: [
        if (!section.available)
          _Notice(text: S.transitDataUnavailable)
        else
          for (final station in section.items)
            _TransitRow(
              icon: Icons.directions_subway_rounded,
              title: mrtStationLabel(station.name),
              lines: [
                [
                  if (station.nearestExit != null) mrtExitLabel(station.nearestExit!.exit),
                  if (mrtAccessLabel(station.accessibleExit) case final access?
                      when station.accessibleExit!.facility != null || station.accessibleExit!.exit != station.nearestExit?.exit)
                    access,
                ].join('・'),
              ],
              trailing: transitDistance(station.distanceM),
              onTap: () => _go(station.nearestExit?.point, TravelMode.walking),
            ),
        if (section.available && section.items.isNotEmpty) ...[
          const SizedBox(height: 4),
          Divider(height: 1, color: c.divider),
          const SizedBox(height: 10),
          _buildFares(c),
        ],
      ],
    );
  }

  Widget _buildFares(AppColors c) {
    final departure = _departure;
    final chip = PressableScale(
      scale: 0.96,
      onTap: _pickDeparture,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                departure == null ? S.chooseDepartureStation : S.departFromP0(mrtStationLabel(departure)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.accent),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 18, color: c.accent),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(S.mrtFare, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary)),
            const SizedBox(width: 10),
            Flexible(child: chip),
          ],
        ),
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.standard,
          alignment: Alignment.topLeft,
          child: departure == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _faresLoading
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
                        )
                      : _faresError != null
                      ? Text(_faresError!, style: TextStyle(fontSize: 13, color: c.danger))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final fare in _fares)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _FareLine(fare: fare),
                              ),
                          ],
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildBusCard(AppColors c, TransitNearby data) {
    final section = data.bus;
    return _SectionCard(
      title: S.transitBus,
      icon: Icons.directions_bus_rounded,
      caption: section.available && section.updatedAt != null ? S.dataTimeP0(transitTime(section.updatedAt)) : null,
      children: [
        if (!section.available)
          _Notice(text: S.transitDataUnavailable)
        else if (section.items.isEmpty)
          _Notice(text: S.noBusWithinP0(S.p0M(300)))
        else
          for (final (i, stop) in section.items.indexed)
            _BusStopTile(
              stop: stop,
              expanded: _expandedStops.contains(i),
              onToggle: () => setState(() => _expandedStops.contains(i) ? _expandedStops.remove(i) : _expandedStops.add(i)),
              onNavigate: () => _go(stop.point, TravelMode.walking),
            ),
      ],
    );
  }

  Widget _buildYoubikeCard(AppColors c, TransitNearby data) {
    final section = data.youbike;
    return _SectionCard(
      title: S.transitYoubike,
      icon: Icons.pedal_bike_rounded,
      caption: section.available && section.updatedAt != null ? S.dataTimeP0(transitTime(section.updatedAt)) : null,
      children: [
        if (!section.available)
          _Notice(text: S.transitDataUnavailable)
        else if (section.items.isEmpty)
          _Notice(text: S.noYoubikeWithinP0(S.p0M(500)))
        else
          for (final s in section.items)
            _TransitRow(
              icon: Icons.pedal_bike_rounded,
              title: s.name,
              lines: [s.active ? S.rentReturnP0P1(s.availableRent, s.availableReturn) : S.stationSuspended],
              warning: !s.active,
              trailing: transitDistance(s.distanceM),
              onTap: () => _go(s.point, TravelMode.walking),
            ),
      ],
    );
  }

  Widget _buildParkingCard(AppColors c, TransitNearby data) {
    final tabs = [S.parkingLots, S.roadsideParking, S.taxiStands];
    final roads = data.roadSpeed.available ? data.roadSpeed.items : const <RoadSection>[];
    return _SectionCard(
      title: S.drivingAndTaxi,
      icon: Icons.directions_car_rounded,
      caption: switch (_parkingTab) {
        0 => data.parkingLots.available && data.parkingLots.updatedAt != null ? S.dataTimeP0(transitTime(data.parkingLots.updatedAt)) : null,
        1 => data.roadsideUpdatedAt != null ? S.dataTimeP0(transitTime(data.roadsideUpdatedAt)) : null,
        _ => null,
      },
      children: [
        if (roads.isNotEmpty) ...[
          _SubHeading(text: S.roadConditions),
          for (final r in roads) _RoadLine(section: r),
          const SizedBox(height: 8),
        ],
        _Segmented(labels: tabs, index: _parkingTab, onChanged: (i) => setState(() => _parkingTab = i)),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: Motion.base,
          child: KeyedSubtree(
            key: ValueKey(_parkingTab),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: switch (_parkingTab) {
                0 => _lotRows(data),
                1 => _roadsideRows(c, data),
                _ => _taxiRows(data),
              },
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _lotRows(TransitNearby data) {
    final section = data.parkingLots;
    if (!section.available) return [_Notice(text: S.transitDataUnavailable)];
    if (section.items.isEmpty) return [_Notice(text: S.noParkingLotsWithinP0(S.p0M(800)))];
    String capacity(ParkingCapacity cap) =>
        cap.available != null ? S.vacantOfTotalP0P1(cap.available!, cap.total) : S.totalSpacesP0(cap.total);
    return [
      for (final lot in section.items)
        _TransitRow(
          icon: Icons.local_parking_rounded,
          title: lot.name,
          lines: [
            [
              if (lot.car.exists) S.carP0(capacity(lot.car)),
              if (lot.motorcycle.exists) S.motorcycleP0(capacity(lot.motorcycle)),
            ].join('・'),
            if (lot.fee.isNotEmpty) lot.fee,
          ],
          trailing: transitDistance(lot.distanceM),
          onTap: () => _go(lot.point, TravelMode.driving, fallbackQuery: lot.address.isEmpty ? lot.name : lot.address),
        ),
    ];
  }

  List<Widget> _roadsideRows(AppColors c, TransitNearby data) {
    if (!data.roadsideAvailable) return [_Notice(text: S.transitDataUnavailable)];
    final radius = S.p0M(data.roadsideRadiusM);
    if (data.roadsideCar.isEmpty && data.roadsideMotorcycle.isEmpty) return [_Notice(text: S.noRoadsideWithinP0(radius))];

    String carLine(RoadsideSegment s) {
      final live = s.live;
      return [
        S.spacesNearbyP0(s.spacesNearby),
        if (s.accessibleNearby > 0) S.accessibleSpacesP0(s.accessibleNearby),
        if (live?.available != null && live?.total != null) S.liveVacancyP0P1(live!.available!, live.total!) else S.noLiveVacancy,
      ].join('・');
    }

    String? chargeLine(RoadsideSegment s) {
      final live = s.live;
      if (live == null) return null;
      final parts = [
        if (live.start.isNotEmpty && live.end.isNotEmpty) S.chargeHoursP0P1(live.start, live.end),
        if (live.fee.isNotEmpty) live.fee,
      ];
      return parts.isEmpty ? null : parts.join('・');
    }

    return [
      Text(S.roadsideNoteP0(radius), style: TextStyle(fontSize: 12, height: 1.4, color: c.textHint)),
      if (data.roadsideCar.isNotEmpty) ...[
        _SubHeading(text: S.carSpaces),
        for (final s in data.roadsideCar)
          _TransitRow(
            icon: Icons.directions_car_filled_outlined,
            title: s.name,
            lines: [carLine(s), ?chargeLine(s)],
            trailing: transitDistance(s.distanceM),
            onTap: () => _go(s.point, TravelMode.driving),
          ),
      ],
      if (data.roadsideMotorcycle.isNotEmpty) ...[
        _SubHeading(text: S.motorcycleSpaces),
        for (final s in data.roadsideMotorcycle)
          _TransitRow(
            icon: Icons.two_wheeler_rounded,
            title: s.name,
            lines: [
              [
                if (s.spacesNearby > 0) S.spacesNearbyP0(s.spacesNearby),
                if (s.accessibleNearby > 0) S.accessibleSpacesP0(s.accessibleNearby),
                if (s.hasParkingArea) S.motorcycleAreaNearby,
              ].join('・'),
            ],
            trailing: transitDistance(s.distanceM),
            onTap: () => _go(s.point, TravelMode.driving),
          ),
      ],
    ];
  }

  List<Widget> _taxiRows(TransitNearby data) {
    final section = data.taxiStands;
    if (!section.available) return [_Notice(text: S.transitDataUnavailable)];
    if (section.items.isEmpty) return [_Notice(text: S.noTaxiWithinP0(S.p0M(800)))];
    return [
      for (final s in section.items)
        _TransitRow(
          icon: Icons.local_taxi_rounded,
          title: s.name,
          lines: [
            s.street,
            [if (s.spaces != null) S.taxiSpacesP0(s.spaces!), if (s.hours.isNotEmpty) S.taxiHoursP0(s.hours)].join('・'),
          ],
          trailing: transitDistance(s.distanceM),
          onTap: () => _go(s.point, TravelMode.walking),
        ),
    ];
  }

  Widget _buildFooter(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(S.transitAttribution, style: TextStyle(fontSize: 12, height: 1.5, color: c.textHint)),
    );
  }
}

class CabinetGuideButton extends StatelessWidget {
  final int cabinetId;
  final String name;
  final String address;
  final String openHours;

  const CabinetGuideButton({super.key, required this.cabinetId, required this.name, this.address = '', this.openHours = ''});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TextButton.icon(
      onPressed: () {
        HapticFeedback.selectionClick();
        CabinetGuideScreen.open(context, cabinetId: cabinetId, name: name, address: address, openHours: openHours);
      },
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(Icons.directions_rounded, size: 16),
      label: Text(S.transitInfo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _BusStopTile extends StatelessWidget {
  static const _collapsedCount = 5;

  final BusStop stop;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onNavigate;

  const _BusStopTile({required this.stop, required this.expanded, required this.onToggle, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final routes = expanded ? stop.routes : stop.routes.take(_collapsedCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TransitRow(
          icon: Icons.directions_bus_rounded,
          title: stop.name,
          lines: [stop.address],
          trailing: transitDistance(stop.distanceM),
          onTap: onNavigate,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 28, bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final r in routes) _BusRouteLine(arrival: r),
              if (stop.routes.length > _collapsedCount)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: onToggle,
                    style: TextButton.styleFrom(
                      foregroundColor: c.accent,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      expanded ? S.collapse : S.showAllRoutesP0(stop.routes.length),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BusRouteLine extends StatelessWidget {
  final BusArrival arrival;

  const _BusRouteLine({required this.arrival});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (label, color, bold) = switch (arrival.status) {
      BusStatus.arriving => (S.busArriving, c.success, true),
      BusStatus.minutes => (S.busMinutesP0(arrival.minutes ?? 0), c.textPrimary, true),
      BusStatus.notDeparted => (S.busNotDeparted, c.textHint, false),
      BusStatus.notStopping => (S.busNotStopping, c.warning, false),
      BusStatus.lastPassed => (S.busLastPassed, c.textHint, false),
      BusStatus.noService => (S.busNoService, c.textHint, false),
      BusStatus.unknown => (S.busNoEstimate, c.textHint, false),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64),
            child: Text(arrival.route, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              arrival.direction.isEmpty ? '' : S.towardsP0(arrival.direction),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, height: 1.5, fontWeight: bold ? FontWeight.w600 : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}

class _RoadLine extends StatelessWidget {
  final RoadSection section;

  const _RoadLine({required this.section});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (label, color) = switch (section.level) {
      TrafficLevel.smooth => (S.trafficSmooth, c.success),
      TrafficLevel.busy => (S.trafficBusy, c.warning),
      TrafficLevel.congested => (S.trafficCongested, c.danger),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              section.between.isEmpty ? section.road : '${section.road}（${section.between}）',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: c.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Text('${S.speedP0(section.speedKph)}・$label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _FareLine extends StatelessWidget {
  final MrtFare fare;

  const _FareLine({required this.fare});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final f = fare.fare;
    final km = fare.distanceKm;
    final detail = f == null
        ? S.fareNotFound
        : [S.fullFareP0(f), if (fare.concessionFare != null) S.concessionFareP0(fare.concessionFare!)].join('・');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [S.fareToP0(mrtStationLabel(fare.to)), if (f != null && km != null && km > 0) S.aboutP0Km(km.toStringAsFixed(1))].join('・'),
          style: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: c.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(detail, style: TextStyle(fontSize: 13, height: 1.4, color: c.textSecondary)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? caption;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.icon, required this.children, this.caption});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
              ),
              if (caption != null) Text(caption!, style: TextStyle(fontSize: 11, color: c.textHint)),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: c.divider),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _SubHeading extends StatelessWidget {
  final String text;

  const _SubHeading({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary)),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;

  const _Notice({required this.text});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline_rounded, size: 15, color: c.textHint),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, height: 1.4, color: c.textSecondary))),
        ],
      ),
    );
  }
}

class _TransitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  final String trailing;
  final bool warning;
  final VoidCallback? onTap;

  const _TransitRow({
    required this.icon,
    required this.title,
    required this.lines,
    required this.trailing,
    this.warning = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final visible = lines.where((l) => l.isNotEmpty).toList();
    return Semantics(
      button: onTap != null,
      label: [title, ...visible, trailing].join('，'),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 18, color: c.iconInactive),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                    ),
                    for (var i = 0; i < visible.length; i++) ...[
                      const SizedBox(height: 3),
                      Text(
                        visible[i],
                        maxLines: i == 0 ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: i == 0 ? 13 : 12,
                          height: 1.4,
                          color: i == 0 && warning ? c.warning : (i == 0 ? c.textSecondary : c.textHint),
                          fontWeight: i == 0 && warning ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(trailing, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent)),
                  if (onTap != null) ...[
                    const SizedBox(height: 4),
                    Icon(Icons.north_east_rounded, size: 14, color: c.iconInactive),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const _Segmented({required this.labels, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.inputFill, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (i == index) return;
                    HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  child: AnimatedContainer(
                    duration: Motion.base,
                    curve: Motion.standard,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: i == index ? c.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: i == index
                          ? [BoxShadow(color: c.shadow.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: i == index ? FontWeight.bold : FontWeight.w500,
                        color: i == index ? c.textPrimary : c.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
