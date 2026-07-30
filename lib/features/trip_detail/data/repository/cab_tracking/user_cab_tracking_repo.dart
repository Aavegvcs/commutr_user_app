import 'package:flutter/foundation.dart';

import '../../../../../core/network/api_client.dart';
import '../../model/cab_tracking/user_cab_tracking_response.dart';

/// Wraps `GET /UserApp/GetUserCabTracking` and `POST /Tracking/status`.
class UserCabTrackingRepo {
  final ApiClient _apiClient;

  // ── GPS route cache ────────────────────────────────────────────────────────
  // The planned GPS route is immutable for the lifetime of a trip: it is the
  // pre-computed schedule geometry (office → every stop), authored at planning
  // time and unchanged while the cab drives. Only the cab's *position* moves,
  // and that arrives over SignalR — never from this endpoint. So the response
  // is safe to fetch once per trip and serve from memory thereafter.
  //
  // Lifecycle: EMPTY → IN-FLIGHT → CACHED, with failures returning to EMPTY so
  // the next caller retries. Entries are held for the process lifetime (this
  // repo is a lazySingleton, so the cache survives widget dispose, bloc
  // disposal and screen re-entry) and released via [clearRouteCache] /
  // [clearAllRouteCache], or implicitly on process death.
  //
  // Keyed by the `tripId` passed in — which is literally the `DsId` query
  // parameter sent below, so key and request can never disagree. A map (rather
  // than a single slot) keeps concurrently tracked trips isolated.
  final Map<int, GpsRouteResponse> _routeCache = {};

  // Requests currently awaiting a response, keyed by trip. Callers arriving
  // while a fetch is in flight await this same Future instead of issuing a
  // second HTTP request. Registered synchronously before the first `await`
  // (see [getGpsRoute]) so the check-then-act is atomic on Dart's event loop.
  final Map<int, Future<GpsRouteResponse>> _inFlightRequests = {};

  UserCabTrackingRepo(this._apiClient);

  Future<TrackingStatusResponse> getTrackingStatus({
    required int tripId,
  }) async {
    debugPrint('[CAB_TRACKING_REPO] getTrackingStatus → TripID=$tripId');

    final response = await _apiClient.dio.post<dynamic>(
      '/Tracking/status',
      queryParameters: {'DsId': tripId},
    );

    Map<String, dynamic>? body;
    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      body = raw;
    } else if (raw is Map) {
      body = Map<String, dynamic>.from(raw);
    }

    if (body == null) {
      throw Exception('Invalid tracking status response.');
    }

    return TrackingStatusResponse.fromJson(body);
  }

  /// Returns the planned GPS route for [tripId], fetching it from the network
  /// at most once per trip.
  ///
  /// Transparent to callers: the returned [GpsRouteResponse] is identical
  /// whether it came from the network or the cache, so existing consumers need
  /// no changes. Resolution order is cache hit → join in-flight request → fetch.
  ///
  /// Only successful responses are cached; a failure leaves the cache untouched
  /// and rethrows, so the next call retries exactly as it does today.
  Future<GpsRouteResponse> getGpsRoute({required int tripId}) async {
    // 1. Cache hit — no network, no parse.
    final cached = _routeCache[tripId];
    if (cached != null) {
      debugPrint('[GPS ROUTE CACHE] Cache Hit : Trip $tripId');
      return cached;
    }

    // 2. A fetch for this trip is already running — await the same Future so N
    //    concurrent callers result in exactly one HTTP request.
    final inFlight = _inFlightRequests[tripId];
    if (inFlight != null) {
      debugPrint('[GPS ROUTE CACHE] Joining Existing Request : Trip $tripId');
      return inFlight;
    }

    // 3. Cache miss — start the fetch and publish the Future *synchronously*,
    //    before any `await`, so a caller in the same event-loop turn sees it and
    //    joins rather than starting a duplicate request.
    debugPrint('[GPS ROUTE CACHE] Cache Miss : Trip $tripId');
    final request = _fetchGpsRoute(tripId);
    _inFlightRequests[tripId] = request;

    try {
      final response = await request;
      // Cache successes only.
      _routeCache[tripId] = response;
      debugPrint('[GPS ROUTE CACHE] Response Cached : Trip $tripId');
      return response;
    } finally {
      // Always release the in-flight slot — on success the value now lives in
      // _routeCache; on failure nothing is cached and the next call retries.
      _inFlightRequests.remove(tripId);
    }
  }

  /// Performs the actual `POST /Tracking/gps-route` call. Extracted so the
  /// caching/dedup logic in [getGpsRoute] stays separate from transport, and so
  /// the request Future can be created before being awaited.
  Future<GpsRouteResponse> _fetchGpsRoute(int tripId) async {
    debugPrint('[CAB_TRACKING_REPO] getGpsRoute → TripID=$tripId');

    final response = await _apiClient.dio.post<dynamic>(
      '/Tracking/gps-route',
      queryParameters: {'DsId': tripId},
    );

    Map<String, dynamic>? body;
    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      body = raw;
    } else if (raw is Map) {
      body = Map<String, dynamic>.from(raw);
    }

    if (body == null) {
      throw Exception('Invalid GPS route response.');
    }

    return GpsRouteResponse.fromJson(body);
  }

  /// Evicts the cached route for [tripId] so the next call re-fetches.
  /// Exposed for future invalidation wiring (trip completion, explicit
  /// refresh); intentionally not called anywhere yet.
  void clearRouteCache(int tripId) {
    _routeCache.remove(tripId);
    debugPrint('[GPS ROUTE CACHE] Cache Cleared : Trip $tripId');
  }

  /// Evicts every cached route. Intended for session teardown (logout / account
  /// switch); intentionally not called anywhere yet.
  ///
  /// In-flight requests are deliberately left alone: their `finally` still
  /// clears their own slot, and because the cache write happens after this
  /// point they would re-populate. Callers needing a hard reset should clear
  /// again once those requests settle.
  void clearAllRouteCache() {
    _routeCache.clear();
    debugPrint('[GPS ROUTE CACHE] Cache Cleared : All Trips');
  }

  Future<CabTrackingData> getUserCabTracking({
    required int empId,
    required int tripId,
  }) async {
    debugPrint(
      '[CAB_TRACKING_REPO] getUserCabTracking → '
      'EmpID=$empId TripID=$tripId',
    );

    final response = await _apiClient.dio.get<dynamic>(
      '/UserApp/GetUserCabTracking',
      queryParameters: {
        'EmpID': empId,
        'TripID': tripId,
      },
    );

    Map<String, dynamic>? envelope;
    final raw = response.data;
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) {
        envelope = first;
      } else if (first is Map) {
        envelope = Map<String, dynamic>.from(first);
      }
    } else if (raw is Map<String, dynamic>) {
      envelope = raw;
    } else if (raw is Map) {
      envelope = Map<String, dynamic>.from(raw);
    }

    if (envelope == null) {
      throw Exception('Invalid tracking response.');
    }

    final parsed = UserCabTrackingResponse.fromJson(envelope);
    if (!parsed.isSuccess || parsed.data == null) {
      final msg = (parsed.dbResponse ?? '').trim();
      throw Exception(
        msg.isNotEmpty ? msg : 'Unable to load cab tracking.',
      );
    }

    return parsed.data!;
  }
}
