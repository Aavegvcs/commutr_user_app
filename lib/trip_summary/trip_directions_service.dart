import 'dart:convert';

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

const _kMapsApiKey = 'AIzaSyCWbmCiquOta1iF6um7_5_NFh6YM5wPL30';

/// Fetches a detailed driving polyline from the Google Directions API.
///
/// [origin] and [destination] are required. [waypoints] are visited in the
/// given order between them (waypoint optimisation is **disabled** so the
/// stop sequence — e.g. P1 → P2 → P3 → D — is preserved).
///
/// Returns the full-detail polyline that traverses **every** waypoint by
/// concatenating each leg's step polylines. This is more accurate than the
/// route's simplified `overview_polyline`, which can visually shortcut around
/// short urban waypoints. Falls back to `overview_polyline` if step polylines
/// are missing, and to an empty list on any failure.
Future<List<LatLng>> fetchDirectionsPolyline({
  required LatLng origin,
  required LatLng destination,
  List<LatLng> waypoints = const [],
}) async {
  final wp = waypoints
      .map((ll) => '${ll.latitude},${ll.longitude}')
      .join('|');

  final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
    'origin': '${origin.latitude},${origin.longitude}',
    'destination': '${destination.latitude},${destination.longitude}',
    if (waypoints.isNotEmpty) 'waypoints': 'optimize:false|$wp',
    'mode': 'driving',
    'key': _kMapsApiKey,
  });

  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return const [];

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = json['routes'] as List?;
    if (routes == null || routes.isEmpty) return const [];

    final route = routes.first as Map;
    final legs = route['legs'] as List?;
    if (legs == null || legs.isEmpty) return const [];

    final decoder = PolylinePoints();
    final List<LatLng> points = [];

    void addPoint(LatLng ll) {
      // Drop duplicate consecutive coordinates at step/leg boundaries.
      if (points.isEmpty ||
          points.last.latitude != ll.latitude ||
          points.last.longitude != ll.longitude) {
        points.add(ll);
      }
    }

    // Decode every step inside every leg → guarantees the polyline visits
    // every waypoint (P1, P2, …) on the road network.
    for (final leg in legs) {
      if (leg is! Map) continue;
      final steps = leg['steps'] as List?;
      if (steps == null || steps.isEmpty) continue;
      for (final step in steps) {
        if (step is! Map) continue;
        final encoded = step['polyline']?['points'] as String?;
        if (encoded == null || encoded.isEmpty) continue;
        for (final p in decoder.decodePolyline(encoded)) {
          addPoint(LatLng(p.latitude, p.longitude));
        }
      }
    }

    if (points.isNotEmpty) return List<LatLng>.unmodifiable(points);

    // Fallback: simplified overview polyline.
    final encodedOverview = route['overview_polyline']?['points'] as String?;
    if (encodedOverview == null || encodedOverview.isEmpty) return const [];
    final decoded = decoder.decodePolyline(encodedOverview);
    return decoded
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

/// Fetches a road polyline that visits every point in [stopPoints] in order.
/// The first point is the origin, the last is the destination, and all
/// intermediate coordinates are sent as waypoints (`optimize:false`).
/// Returns [stopPoints] unchanged when fewer than 2 coordinates are supplied
/// or when the Directions API call fails.
Future<List<LatLng>> fetchRoutePolylineThroughPoints(
  List<LatLng> stopPoints,
) async {
  if (stopPoints.length < 2) return stopPoints;

  final roadPoints = await fetchDirectionsPolyline(
    origin: stopPoints.first,
    destination: stopPoints.last,
    waypoints: stopPoints.length > 2
        ? stopPoints.sublist(1, stopPoints.length - 1)
        : const [],
  );

  return roadPoints.isNotEmpty ? roadPoints : stopPoints;
}

/// Parses `"lat,lng"` into [LatLng]. Returns null on failure.
LatLng? parseLatLngString(String? raw) {
  if (raw == null) return null;
  final parts = raw.trim().split(',');
  if (parts.length < 2) return null;
  final lat = double.tryParse(parts[0].trim());
  final lng = double.tryParse(parts[1].trim());
  if (lat == null || lng == null) return null;
  return LatLng(lat, lng);
}

/// Standard Google Maps location pin — used for every route stop.
const BitmapDescriptor locationMarker = BitmapDescriptor.defaultMarker;

/// Custom map style for trip route / detail maps.
const String kTripMapStyle = '''
[
  {
    "featureType": "landscape",
    "elementType": "labels",
    "stylers": [{ "visibility": "off" }]
  },
  {
    "featureType": "transit",
    "elementType": "labels",
    "stylers": [{ "visibility": "off" }]
  },
  {
    "featureType": "poi",
    "elementType": "labels",
    "stylers": [{ "visibility": "off" }]
  },
  {
    "featureType": "water",
    "elementType": "labels",
    "stylers": [{ "visibility": "off" }]
  },
  {
    "featureType": "road",
    "elementType": "labels.icon",
    "stylers": [{ "visibility": "off" }]
  },
  {
    "stylers": [
      { "hue": "#00aaff" },
      { "saturation": -100 },
      { "gamma": 2.15 },
      { "lightness": 12 }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      { "visibility": "on" },
      { "lightness": 24 }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{ "lightness": 57 }]
  }
]
''';

// ─── Trip type & route stop helpers ───────────────────────────────────────────

/// Returns `true` for PICK/Login, `false` for DROP/Logout, or `null` if unknown.
bool? parsePickDropTripType(String? tripType) {
  final t = (tripType ?? '').trim().toLowerCase();
  if (t.isEmpty) return null;
  if (t == 'pick' || t == 'login' || t == '1') return true;
  if (t == 'drop' || t == 'logout' || t == '2') return false;
  return null;
}

/// Whether [tripType] is a PICK (login) trip. Defaults to [defaultPick] when unknown.
bool isPickTripType(String? tripType, {bool defaultPick = true}) =>
    parsePickDropTripType(tripType) ?? defaultPick;

/// One stop on a trip route map.
class MapRouteStop {
  const MapRouteStop({
    required this.id,
    this.latLng,
    this.title,
    this.snippet,
    this.paxOrder,
    this.isOffice = false,
    this.isOrigin = false,
    this.isDestination = false,
  });

  final String id;
  final String? latLng;
  final String? title;
  final String? snippet;
  final int? paxOrder;
  final bool isOffice;
  final bool isOrigin;
  final bool isDestination;
}

/// Input row for [buildOrderedMapRouteStops].
class MapRoutePassenger {
  const MapRoutePassenger({
    this.empId,
    this.empName,
    this.empLatLng,
    this.paxOrder,
  });

  final int? empId;
  final String? empName;
  final String? empLatLng;
  final int? paxOrder;

  int get sortKey => paxOrder ?? 999;
}

/// Builds ordered route stops for the map polyline.
///
/// - **PICK:** passenger [EmpLatLng] in ascending [paxOrder] → office
/// - **DROP:** office [OfficeLatLng] → passenger [EmpLatLng] in ascending [paxOrder]
List<MapRouteStop> buildOrderedMapRouteStops({
  required bool isPick,
  required String? officeLatLng,
  required String? officeAddress,
  required List<MapRoutePassenger> passengers,
}) {
  final paxList = List<MapRoutePassenger>.from(passengers)
    ..sort((a, b) {
      final orderCmp = a.sortKey.compareTo(b.sortKey);
      if (orderCmp != 0) return orderCmp;
      return (a.empId ?? 0).compareTo(b.empId ?? 0);
    });

  final stops = <MapRouteStop>[];

  void addPassenger(MapRoutePassenger pax, int index, {required bool isDest}) {
    final latLng = pax.empLatLng?.trim();
    if (latLng == null || latLng.isEmpty) return;
    final order = pax.paxOrder ?? (index + 1);
    final isFirstPax = stops.where((s) => !s.isOffice).isEmpty;
    stops.add(
      MapRouteStop(
        id: 'pax_${pax.empId ?? index}',
        latLng: latLng,
        title: pax.empName ?? (isDest ? 'Destination' : 'Stop $order'),
        snippet: isDest
            ? 'Destination · P$order'
            : (isPick && isFirstPax ? 'Origin · P$order' : 'P$order'),
        paxOrder: order,
        isOrigin: isPick && isFirstPax,
        isDestination: isDest,
      ),
    );
  }

  if (isPick) {
    for (var i = 0; i < paxList.length; i++) {
      addPassenger(paxList[i], i, isDest: false);
    }
    final office = officeLatLng?.trim();
    if (office != null && office.isNotEmpty) {
      stops.add(
        MapRouteStop(
          id: 'office',
          latLng: office,
          title: officeAddress ?? 'Office',
          snippet: 'Destination',
          isOffice: true,
          isDestination: true,
        ),
      );
    }
  } else {
    // DROP: office first, then every passenger in ascending paxOrder.
    final office = officeLatLng?.trim();
    if (office != null && office.isNotEmpty) {
      stops.add(
        MapRouteStop(
          id: 'office',
          latLng: office,
          title: officeAddress ?? 'Office',
          snippet: 'Origin',
          isOffice: true,
          isOrigin: true,
        ),
      );
    }
    for (var i = 0; i < paxList.length; i++) {
      addPassenger(paxList[i], i, isDest: i == paxList.length - 1);
    }
  }

  return stops;
}

// ─── Bounds helper ────────────────────────────────────────────────────────────

/// Fits a [LatLngBounds] around a list of points. Returns null if fewer than
/// 2 points.
LatLngBounds? boundsFromPoints(List<LatLng> points) {
  if (points.length < 2) return null;
  double minLat = points.first.latitude;
  double maxLat = points.first.latitude;
  double minLng = points.first.longitude;
  double maxLng = points.first.longitude;
  for (final pt in points) {
    if (pt.latitude < minLat) minLat = pt.latitude;
    if (pt.latitude > maxLat) maxLat = pt.latitude;
    if (pt.longitude < minLng) minLng = pt.longitude;
    if (pt.longitude > maxLng) maxLng = pt.longitude;
  }
  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}
