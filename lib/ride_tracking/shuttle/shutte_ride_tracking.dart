import 'dart:async';
import 'dart:math' as math;

import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/core/utils/error_message.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';
import 'package:commutr_main/features/trip_detail/data/model/cab_tracking/user_cab_tracking_response.dart';
import 'package:commutr_main/features/trip_detail/data/repository/cab_tracking/user_cab_tracking_repo.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_bloc.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_event.dart';
import 'package:commutr_main/ride_tracking/bloc/cab_tracking_state.dart';
import 'package:commutr_main/ride_tracking/config/tracking_config.dart';
import 'package:commutr_main/ride_tracking/model/ride_timeline.dart';
import 'package:commutr_main/ride_tracking/service/dummy_tracking_service.dart';
import 'package:commutr_main/ride_tracking/service/ivr_call_repo.dart';
import 'package:commutr_main/ride_tracking/service/route_tracking_signalr_service.dart';
import 'package:commutr_main/features/trip_chat/presentation/trip_group_chat_screen.dart';
import 'package:commutr_main/trip_summary/trip_directions_service.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Per-passenger lifecycle status for a LOGIN (pickup) trip, following the
/// Uber/Ola-shuttle spec. Resolution order is strict:
///   1. noShow == true          → [LoginPaxStatus.noShow]
///   2. empSignOutTime != null  → [LoginPaxStatus.completed]   (reached office)
///   3. empSigninTime  != null  → [LoginPaxStatus.boarded]     (onboard)
///   4. otherwise               → [LoginPaxStatus.notPickedUp] (still waiting)
///
/// Only meaningful for `tripType == 1`. Drives marker colour and status label
/// for login trips; logout/other trips keep the existing [StopState] scheme.
enum LoginPaxStatus { notPickedUp, boarded, completed, noShow }

/// Resolves a [TripPassenger]'s LOGIN status per the spec's `getPassengerStatus`.
LoginPaxStatus loginPaxStatusOf(TripPassenger p) {
  if (p.noShow) return LoginPaxStatus.noShow;
  if (p.empSignOutTime != null && p.empSignOutTime!.trim().isNotEmpty) {
    return LoginPaxStatus.completed;
  }
  if (p.empSigninTime != null && p.empSigninTime!.trim().isNotEmpty) {
    return LoginPaxStatus.boarded;
  }
  return LoginPaxStatus.notPickedUp;
}

/// Marker hue for a LOGIN pickup stop, keyed on the passenger's live status:
///   Not Picked Up → Blue · Boarded → Orange · Completed → Green · No Show → Red
double loginMarkerHue(LoginPaxStatus status) {
  switch (status) {
    case LoginPaxStatus.notPickedUp:
      return BitmapDescriptor.hueAzure; // blue
    case LoginPaxStatus.boarded:
      return BitmapDescriptor.hueOrange; // orange
    case LoginPaxStatus.completed:
      return BitmapDescriptor.hueGreen; // green
    case LoginPaxStatus.noShow:
      return BitmapDescriptor.hueRed; // red
  }
}

/// Short status label for a LOGIN pickup stop, per the spec.
String loginStatusLabel(LoginPaxStatus status) {
  switch (status) {
    case LoginPaxStatus.notPickedUp:
      return 'Upcoming Pickup';
    case LoginPaxStatus.boarded:
      return 'Onboard';
    case LoginPaxStatus.completed:
      return 'Completed';
    case LoginPaxStatus.noShow:
      return 'No Show';
  }
}

/// Per-passenger lifecycle status for a LOGOUT (drop) trip, following the
/// Uber/Ola employee-transport spec. For logout trips every passenger is
/// considered already boarded at the office, so there is no "not boarded"
/// phase. Resolution order is strict:
///   1. noShow == true            → [LogoutPaxStatus.noShow]
///   2. reachedHomeTime != null   → [LogoutPaxStatus.completed]  (dropped home)
///   3. otherwise                 → [LogoutPaxStatus.boarded]    (awaiting drop)
///
/// Only meaningful for `tripType == 2`. Drives marker colour and status label
/// for logout trips; login/other trips keep the existing scheme.
enum LogoutPaxStatus { boarded, completed, noShow }

/// Resolves a [TripPassenger]'s LOGOUT status per the spec's `getPassengerStatus`.
LogoutPaxStatus logoutPaxStatusOf(TripPassenger p) {
  if (p.noShow) return LogoutPaxStatus.noShow;
  if (p.reachedHomeTime != null && p.reachedHomeTime!.trim().isNotEmpty) {
    return LogoutPaxStatus.completed;
  }
  return LogoutPaxStatus.boarded;
}

/// Whether a LOGOUT passenger should stay on the remaining-drop route, decided
/// purely from their live [TripPassenger.paxTrackingStatus] per the drop spec.
///
/// ACTIVE → keep on route:
///   * `Not-Boarded`  (shuttle has not reached this home yet)
///   * `En-Route`     (shuttle is currently driving to / past this home)
/// COMPLETED → drop from route:
///   * `Reached-Home`, `De-Boarded`, `Trip-Completed`, `No-Show`
///
/// The match is tolerant of separator/casing variants (`Not-Boarded`,
/// `not boarded`, `NOT_BOARDED` all normalise the same) so it works regardless
/// of how the backend formats the status string. When the status is absent it
/// falls back to the timestamp/no-show derivation in [logoutPaxStatusOf].
bool shouldIncludeInRoute(TripPassenger p) {
  final raw = p.paxTrackingStatus;
  if (raw != null && raw.trim().isNotEmpty) {
    // Normalise hyphens/underscores/spaces to a single space, lower-cased.
    final s = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    switch (s) {
      case 'not boarded':
      case 'en route':
      case 'enroute':
      case 'in cab': // legacy backend spelling for En-Route
        return true;
      case 'reached home':
      case 'de boarded':
      case 'deboarded':
      case 'dropped': // legacy backend spelling for Reached-Home
      case 'trip completed':
      case 'completed': // legacy backend spelling for Trip-Completed
      case 'no show':
        return false;
    }
    // Unknown status string → fall through to the timestamp-based derivation.
  }
  // No (or unrecognised) status → derive from no-show / reachedHomeTime.
  return logoutPaxStatusOf(p) == LogoutPaxStatus.boarded;
}

/// True when a LOGOUT passenger's home should remain on the active drop route —
/// i.e. they are still awaiting drop (Not-Boarded / En-Route). Completed homes
/// (Reached-Home, De-Boarded, Trip-Completed) and No-Show are excluded.
///
/// Thin alias over [shouldIncludeInRoute], kept for the existing call sites
/// (markers, route signature, active-target resolution).
bool logoutPaxIsRemaining(TripPassenger p) => shouldIncludeInRoute(p);

/// Returns the LOGOUT passengers still on the remaining-drop route, sorted by
/// `paxOrder` ascending. Completed and no-show passengers are excluded via
/// [shouldIncludeInRoute]; passengers without a `paxOrder` are dropped (they
/// can't be sequenced into the route).
List<TripPassenger> getRemainingDropPassengers(List<TripPassenger> passengers) {
  return passengers
      .where((p) => p.paxOrder != null && shouldIncludeInRoute(p))
      .toList()
    ..sort((a, b) => a.paxOrder!.compareTo(b.paxOrder!));
}

/// Marker hue for a LOGOUT drop stop, keyed on the passenger's live status and
/// whether it is the shuttle's current drop target:
///   Current Drop → Orange · Upcoming Drop → Blue · Completed → Green · No Show → Red
double logoutMarkerHue(LogoutPaxStatus status,
    {required bool isCurrentTarget}) {
  switch (status) {
    case LogoutPaxStatus.completed:
      return BitmapDescriptor.hueGreen; // green
    case LogoutPaxStatus.noShow:
      return BitmapDescriptor.hueRed; // red
    case LogoutPaxStatus.boarded:
      return isCurrentTarget
          ? BitmapDescriptor.hueOrange // current drop
          : BitmapDescriptor.hueAzure; // upcoming drop (blue)
  }
}

/// Short status label for a LOGOUT drop stop, per the spec.
String logoutStatusLabel(LogoutPaxStatus status,
    {required bool isCurrentTarget}) {
  switch (status) {
    case LogoutPaxStatus.completed:
      return 'Completed';
    case LogoutPaxStatus.noShow:
      return 'No Show';
    case LogoutPaxStatus.boarded:
      return isCurrentTarget ? 'Current Drop' : 'Upcoming Drop';
  }
}

// ─── Shuttle stop model ───────────────────────────────────────────────────────

/// One stop on the shuttle's route, as the rider sees it.
///
/// The tracking API models the route per-PASSENGER ([TripPassenger] rows keyed
/// by `paxOrder`), which is right for a shuttle but wrong for a shuttle: a shuttle
/// stop is a place, and several riders can board at the same one. This type is
/// the place-level view — it carries no name, no employee id, and no boarding
/// state of any individual rider, so nothing derived from it can leak who else
/// is travelling.
///
/// Built by [_ShuttleStop.fromTimeline], which collapses the passenger rows of
/// a [RideTimeline] into ordered stops by location.
@immutable
class _ShuttleStop {
  /// 1-based position of the stop along the route ("Stop 1", "Stop 2", …).
  final int index;

  /// Place label — the address the shuttle halts at, never a passenger name.
  final String name;

  /// Where the stop is, used to place its map marker.
  final LatLng? location;

  /// Lifecycle of the stop itself: [StopState.completed] once the shuttle has
  /// served it, [StopState.current] for the stop it is heading to now, and
  /// [StopState.upcoming] for the rest. A stop is never `noShow` — that is a
  /// per-passenger concept and has no meaning for a place.
  final StopState state;

  /// True for the office terminus (start of a logout run, end of a login run).
  final bool isOffice;

  /// True when this is the rider's own boarding/alighting stop. Used only to
  /// highlight the row — it reveals nothing about any other rider.
  final bool isMine;

  /// Scheduled arrival clock for this stop (`plannedScheduleTime` + live
  /// `etaDeviationMinutes`), pre-formatted (e.g. `8:45 AM`). Null when the
  /// backend hasn't scheduled it.
  final String? arrivalClock;

  /// Minutes until the shuttle reaches this stop, when it is the active target
  /// and a live ETA has been computed. Null otherwise.
  final int? etaMinutes;

  /// The clock time the rider was actually picked up here (`8:32 AM`), set only
  /// on the rider's OWN stop once they have boarded. It is the viewer's own
  /// sign-in stamp, so it reveals nothing about anyone else at the halt.
  final String? boardedClock;

  const _ShuttleStop({
    required this.index,
    required this.name,
    required this.state,
    this.location,
    this.isOffice = false,
    this.isMine = false,
    this.arrivalClock,
    this.etaMinutes,
    this.boardedClock,
  });

  /// Label for the stop's position in the route — "Stop 3", or "Office".
  String get sequenceLabel => isOffice ? 'Office' : 'Stop $index';

  /// Short status text for the stop, phrased for a place rather than a person.
  String get statusLabel {
    if (isOffice) {
      switch (state) {
        case StopState.completed:
          return 'Departed';
        case StopState.current:
          return 'Arriving';
        case StopState.upcoming:
        case StopState.noShow:
          return 'Final stop';
      }
    }
    switch (state) {
      case StopState.completed:
        return 'Departed';
      case StopState.current:
        return 'Arriving';
      case StopState.upcoming:
      case StopState.noShow:
        return 'Upcoming';
    }
  }

  /// The ETA text shown on the stop row: the live estimate for the stop the
  /// shuttle is heading to, otherwise the scheduled arrival clock. Null when
  /// neither is known (the row then renders without an ETA rather than "—").
  ///
  /// The live estimate is rendered as an arrival CLOCK (`8:45 AM`), not a
  /// duration, so it matches [arrivalClock] on every other row instead of
  /// reading `1 h 10 min` beside a column of clock times. A shuttle that has
  /// effectively arrived still says "Arriving" — a clock would imply it is
  /// yet to come.
  String? get etaLabel {
    // The rider's own stop keeps a time after the shuttle has served it: the
    // clock they were actually picked up at. Every other completed stop still
    // renders bare — a served halt has no arrival left to predict.
    if (boardedClock != null) return boardedClock;
    if (state == StopState.completed) return null;
    final live = etaMinutes;
    if (live != null) {
      if (live <= 0) return 'Arriving';
      return formatEtaAsClock(live) ?? arrivalClock;
    }
    return arrivalClock;
  }

  /// Collapses a [RideTimeline]'s per-passenger rows into place-level shuttle
  /// stops.
  ///
  /// Rows sharing a location are merged into ONE stop (that's the whole point:
  /// several riders board at the same halt), keyed by rounded lat/lng so GPS
  /// jitter in a planned coordinate doesn't split one halt into two. Rows with
  /// no coordinate fall back to their address text as the key, so an
  /// un-geocoded stop still appears exactly once.
  ///
  /// A merged stop's [state] is the most advanced state of the rows behind it
  /// (`current` wins over `upcoming`; `completed` only when every row there is
  /// done) — the shuttle has served the halt when it has served everyone at it.
  /// No-show rows are ignored for state purposes: one rider not showing up
  /// doesn't mean the shuttle skipped the stop.
  static List<_ShuttleStop> fromTimeline(
    RideTimeline timeline, {
    String? officeName,
    int? activeEtaMinutes,
    int? activeOrder,
    bool activeIsOffice = false,
    String? myBoardedClock,
  }) {
    final out = <_ShuttleStop>[];
    // Key → index in [out], so repeat visits to the same key merge.
    final seen = <String, int>{};
    // Per merged stop: whether any row is the active target, is mine, and the
    // running state/arrival values.
    var index = 0;

    for (final stop in timeline.stops) {
      final loc = stop.location;
      final address = stop.subtitle?.trim();
      final key = loc != null
          ? 'geo:${loc.latitude.toStringAsFixed(4)},'
              '${loc.longitude.toStringAsFixed(4)}'
          : (stop.isOffice
              ? 'office'
              : 'addr:${(address ?? '').toLowerCase()}#${stop.order ?? ''}');

      // The rider-facing name of a stop is its PLACE, never `stop.title`
      // (which is the passenger's name). Fall back to the sequence position
      // when the backend gives no address, so we still never print a name.
      final placeName = stop.isOffice
          ? (officeName ?? stop.title)
          : (address != null && address.isNotEmpty
              ? address
              : 'Stop ${index + 1}');

      final isActive = stop.isOffice
          ? activeIsOffice
          : (activeOrder != null && stop.order == activeOrder);
      final arrival = formatPlannedArrivalClock(
        stop.plannedScheduleTime,
        stop.etaDeviationMinutes,
      );

      // The pickup stamp belongs to the viewer alone, so it rides only on the
      // stop that is theirs — never on a halt they merely share with someone.
      final boarded =
          (stop.isMe && !stop.isOffice) ? myBoardedClock : null;

      final existing = seen[key];
      if (existing != null) {
        final prev = out[existing];
        out[existing] = _ShuttleStop(
          index: prev.index,
          name: prev.name,
          location: prev.location ?? loc,
          state: _mergeState(prev.state, stop.state),
          isOffice: prev.isOffice || stop.isOffice,
          isMine: prev.isMine || stop.isMe,
          arrivalClock: prev.arrivalClock ?? arrival,
          etaMinutes: prev.etaMinutes ?? (isActive ? activeEtaMinutes : null),
          boardedClock: prev.boardedClock ?? boarded,
        );
        continue;
      }

      if (!stop.isOffice) index++;
      seen[key] = out.length;
      out.add(_ShuttleStop(
        index: index,
        name: placeName,
        location: loc,
        state: _stopStateFor(stop.state),
        isOffice: stop.isOffice,
        isMine: stop.isMe,
        arrivalClock: arrival,
        etaMinutes: isActive ? activeEtaMinutes : null,
        boardedClock: boarded,
      ));
    }

    return out;
  }

  /// Maps a per-passenger [StopState] onto a place-level one. A no-show is a
  /// property of a rider, not of a halt, so it degrades to `upcoming` — the
  /// shuttle still has that stop ahead of it.
  static StopState _stopStateFor(StopState s) =>
      s == StopState.noShow ? StopState.upcoming : s;

  /// Most-advanced-wins merge for two rows at the same halt.
  static StopState _mergeState(StopState a, StopState b) {
    final x = _stopStateFor(a);
    final y = _stopStateFor(b);
    if (x == StopState.current || y == StopState.current) {
      return StopState.current;
    }
    // Completed only when BOTH sides are done — otherwise the shuttle still has
    // someone to serve there, so the halt is still ahead.
    if (x == StopState.completed && y == StopState.completed) {
      return StopState.completed;
    }
    if (x == StopState.completed || y == StopState.completed) {
      return StopState.upcoming;
    }
    return StopState.upcoming;
  }
}

/// Live tracking screen for a SHUTTLE trip.
///
/// Differs from the shuttle tracking screen in three deliberate ways, because a
/// shuttle is a fixed-route service rather than a door-to-door ride:
///   * No boarding OTP — shuttle boarding is by stop/QR, not a per-rider PIN.
///   * No passenger list — riders see the route's STOPS, never who else is on
///     board. Nothing on this screen identifies another passenger.
///   * Stops carry their own ETA, so the sheet reads like a shuttle timetable.
class ShuttleRideTrackingScreen extends StatefulWidget {
  final String? userName;
  final int? tripId;
  final int? empId;
  // UserAppConfiguration highest-priority feature gates, passed in from the
  // caller (which has the loaded config). When `false` the corresponding button
  // is always hidden; defaults to `true` so behaviour is unchanged when a caller
  // does not supply a value.
  final bool gateChat;
  final bool gateIvrCall;

  /// Whether the tracked trip is a SHUTTLE (`TransportType == 2`).
  ///
  /// Shuttle trips have no group chat — a rider is shown the line, never who
  /// else is on it — so the Chat entry is hidden regardless of [gateChat].
  /// Defaults to `true` because this screen only ever tracks shuttles.
  final bool isShuttleTransport;

  const ShuttleRideTrackingScreen({
    super.key,
    this.userName,
    this.tripId,
    this.empId,
    this.gateChat = true,
    this.gateIvrCall = true,
    this.isShuttleTransport = true,
  });

  @override
  State<ShuttleRideTrackingScreen> createState() => _ShuttleRideTrackingScreenState();
}

class _ShuttleRideTrackingScreenState extends State<ShuttleRideTrackingScreen>
    with TickerProviderStateMixin {
  final Completer<GoogleMapController> _mapController = Completer();

  static const LatLng _fallbackCenter = LatLng(28.5930, 77.0490);
  static const double _followZoom = 17.0;

  LatLng _driverLatLng = _fallbackCenter;
  LatLng _animatedDriverLatLng = _fallbackCenter;

  // ── Camera behaviour (Ola/Uber style) ──────────────────────────────────────
  // The camera is deliberately NOT moved on every GPS update. It is positioned
  // once at the start (fit to bounds), then left fixed so the background map
  // stays rock-steady while only the marker + polyline animate. It moves again
  // only on: recenter tap, the initial fit, or the shuttle drifting off-screen.

  // Whether the one-time initial camera fit has run yet.
  bool _didInitialCameraFit = false;
  // The latitude/longitude region currently visible on screen, refreshed from
  // onCameraIdle. Used to detect when the shuttle has drifted out of view.
  LatLngBounds? _visibleBounds;
  // Guards against issuing overlapping programmatic camera moves (which would
  // themselves fire onCameraIdle and could loop).
  bool _cameraMoveInFlight = false;
  // Padding (px) used when fitting bounds so markers aren't flush to the edge.
  static const double _boundsPadding = 80.0;

  // Bearing state. `_carBearing` is the live (animated) rotation rendered on the
  // marker; `_bearingFrom`/`_bearingTo` are the endpoints the current move tween
  // rotates between, taking the shortest angular path (no jitter / no spinning).
  double _carBearing = 0.0;
  double _bearingFrom = 0.0;
  double _bearingTo = 0.0;
  // True when the current heading came from the server bearing and was applied
  // instantly. While set, the per-frame move tick must NOT re-interpolate the
  // rotation (that would ease it back down from the snapped value).
  bool _bearingSnapped = false;

  // Anchor for the bus PIN marker (`assets/images/bus_marker.jpg`).
  //
  // A pin points at its location with its TIP, so the anchor sits at the tip
  // rather than the image centre — anchoring centre would draw the shuttle half
  // a pin-height north of where it actually is.
  //
  // Values measured from the 512x512 source art: content spans y 25..487, so the
  // tip bottoms out at 487/512 = 0.9531 (there is white padding below it), and
  // the tip's horizontal centre is x 252..257 => 0.4971.
  //
  // The pin is deliberately NOT rotated by the heading: unlike the cab screen's
  // car sprite, rotating a pin tips it over instead of aiming it.
  static const Offset _kBusPinAnchor = Offset(0.497, 0.953);

  CameraPosition _initialCamera = const CameraPosition(
    target: _fallbackCenter,
    zoom: _followZoom,
  );

  // Smooth car movement animation (like Rapido/Ola).
  late AnimationController _moveController;
  Animation<double>? _latAnim;
  Animation<double>? _lngAnim;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  bool _isExpanded = false;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  late AnimationController _pulseController;
  Timer? _pollingTimer;
  // Silent 200 ms tick: re-merges the latest SignalR pax data (status, ETA
  // deviation, planned time) and repaints so the live arrival clock stays
  // current. See [_refreshPaxTrackingStatus].
  Timer? _statusRefreshTimer;
  // Last time the 200 ms tick dispatched a silent REST refresh. Throttled so we
  // never hammer the API at the tick's cadence — see [_silentRefreshThrottle].
  DateTime? _lastSilentRefreshAt;
  // Minimum gap between silent API refreshes fired by the 200 ms tick. The tick
  // repaints + re-merges the cached SignalR payload every 200 ms (so the UI
  // feels real-time), but a fresh server fetch only goes out this often to keep
  // passenger data current between SignalR pings without flooding the backend.
  static const Duration _silentRefreshThrottle = Duration(seconds: 2);

  final RouteTrackingSignalRService _signalR = RouteTrackingSignalRService();
  bool _signalREnabled = false;
  // Set to true after the first SignalR location push. Once true, REST polling
  // must not overwrite the driver position — SignalR is the authoritative source.
  bool _signalRHasLocation = false;

  // Testing-only simulator. Non-null ONLY when TrackingConfig.useDummyTracking
  // is true (debug build started with --dart-define=DUMMY_TRACKING=true). In
  // every release build this stays null and the live flow runs untouched.
  DummyTrackingService? _dummy;
  // In dummy mode the bloc never emits data, so the bottom sheet reads from this
  // seed instead (driver/vehicle). Null in live mode.
  RideTrackingDataState? _dummyData;

  // Freshest data state applied to the screen, cached here so the bottom sheet
  // (driver card / vehicle / stop list) reads from it on EVERY
  // repaint — including the silent 0.2 s tick — not just on bloc emits. This is
  // what makes the whole sheet refresh in real time (Uber/Rapido style) without
  // a loader, since SignalR/tick updates fold into _latestStatus continuously.
  RideTrackingDataState? _latestData;

  // Live ETA computed from each SignalR location update (driver position +
  // speed → remaining distance to the office). Null until first computed.
  int? _etaMinutes;
  // Latest status + planned route cached from the bloc so the SignalR callback
  // can compute the ETA without reaching back into bloc state.
  TrackingStatusResponse? _latestStatus;
  List<LatLng> _plannedPoints = const [];
  // Road-following shuttle → next-stop leg from Google Directions (Option B).
  List<LatLng> _activeLegPoints = const [];
  DateTime? _lastActiveLegFetchAt;
  String? _activeLegTargetKey;
  int _activeLegFetchGen = 0;
  static const Duration _activeLegThrottle = Duration(seconds: 12);

  // ── Planned-route (Directions) memo ────────────────────────────────────────
  // The planned route's SHAPE is a pure function of its ordered waypoints, so
  // refetching it for an unchanged waypoint list returns identical geometry.
  // These fields memo the last result by waypoint signature so the repeated
  // REST-driven rebuilds (which fire on every bloc emit via _applyStateToMap →
  // _loadGpsRoutePolylines) reuse it instead of issuing a Directions request.
  //
  // This mirrors the guard the SignalR path already applies at
  // `if (_plannedPoints.length < 2)`, whose comment notes that refetching per
  // tick made the polyline geometry visibly fluctuate.
  //
  // A genuine sequence change (a pickup boards, a drop completes, a no-show)
  // changes the waypoint list, hence the signature, so the route still rebuilds
  // exactly as before — including via the _loginRouteSignature() /
  // _logoutRouteSignature() triggers in _rebuildTimelineFromPayload.
  String? _plannedRouteSignature;
  List<LatLng> _plannedRouteCache = const [];
  // Non-null while a planned-route Directions fetch is in flight; concurrent
  // callers await this same Future rather than starting a duplicate request.
  Future<List<LatLng>>? _plannedRouteInFlight;
  // Personalised, ordered tracking timeline (built from status.passengers and
  // the logged-in user's empId). On a shuttle this drives ROUTING ONLY — the
  // planned/active polylines, the camera fit and the ETA target. It is never
  // rendered directly, because its rows are per-passenger and carry names.
  RideTimeline _timeline = RideTimeline.empty;
  // Full (non-personalised) timeline — every stop on the route. Built alongside
  // [_timeline] from the same status but with includeAllStops, and fed through
  // [_ShuttleStop.fromTimeline] so the sheet and markers show place-level stops
  // with no passenger identity attached.
  RideTimeline _fullTimeline = RideTimeline.empty;
  // Fallback average speed (km/h) used when the shuttle is stopped / GPS speed is
  // 0 or missing, so the ETA never shows infinity.
  static const double _fallbackSpeedKmh = 25.0;

  /// The live vehicle marker — the bus pin asset.
  BitmapDescriptor _busIcon = BitmapDescriptor.defaultMarker;

  /// Guards the one-time bus-marker load in [didChangeDependencies].
  bool _busIconRequested = false;

  // Latest SignalR payload, surfaced verbatim in the debug overlay so the live
  // shuttle lat/lng and every passenger's paxOrder are visible while tracking.
  RouteLocationPayload? _lastPayload;

  /// Loads the bus map pin from `assets/images/bus_marker.jpg`.
  ///
  /// Decoded at a device-scaled width so the pin is neither fuzzy on a 3x screen
  /// nor oversized on 1x. The source art is a 512x512 square pin, so only
  /// [targetWidth] is set and the decoder keeps the aspect ratio.
  ///
  /// The asset is a JPEG, which cannot store an alpha channel — every pixel
  /// decodes fully opaque, so dropping it straight onto the map would show the
  /// pin inside a white box. [_keyOutWhite] therefore removes the white
  /// background before the bitmap is handed to Maps.
  Future<void> _loadBusIcon() async {
    // Logical pin width on screen; scaled by DPR for the raster it decodes to.
    const double logicalWidth = 38.0;
    final dpr =
        (MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0).clamp(1.0, 4.0);

    try {
      final bytes = await rootBundle.load('assets/images/bus_marker.png');
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(),
        targetWidth: (logicalWidth * dpr).round(),
      );
      final frame = await codec.getNextFrame();
      final png = await _keyOutWhite(frame.image);
      if (png == null || !mounted) return;
      setState(() {
        _busIcon = BitmapDescriptor.bytes(png, width: logicalWidth);
      });
    } catch (e) {
      // Leave the default marker in place — tracking must not break over art.
      debugPrint('[ShuttleRideTrackingScreen] bus marker load failed: $e');
    }
  }

  /// Re-encodes [src] as a PNG with its white background made transparent.
  ///
  /// Needed because the pin art ships as a JPEG (no alpha), so the marker would
  /// otherwise render as a pin inside an opaque white square. Only near-white
  /// pixels are cleared; the pin itself is red/grey and unaffected. Pixels close
  /// to the threshold get partial alpha so the pin keeps a smooth edge instead of
  /// a hard aliased cut.
  Future<Uint8List?> _keyOutWhite(ui.Image src) async {
    final raw = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) return null;

    // Fully transparent at/above `clear`, fully opaque at/below `keep`, ramped
    // in between. JPEG compression smears the background slightly off-white, so
    // the clear threshold sits below 255.
    const int clear = 250;
    const int keep = 228;

    final bytes = raw.buffer.asUint8List();
    for (var i = 0; i < bytes.length; i += 4) {
      final r = bytes[i], g = bytes[i + 1], b = bytes[i + 2];
      // Distance from white, using the darkest channel so coloured pixels of
      // similar luminance are never keyed out.
      final min = r < g ? (r < b ? r : b) : (g < b ? g : b);
      if (min >= clear) {
        bytes[i + 3] = 0;
      } else if (min > keep) {
        bytes[i + 3] = (255 * (clear - min) / (clear - keep)).round();
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      src.width,
      src.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final keyed = await completer.future;
    final png = await keyed.toByteData(format: ui.ImageByteFormat.png);
    return png?.buffer.asUint8List();
  }

  void _onSignalRLocation(RouteLocationPayload payload) {
    if (!mounted) return;
    // Keep the freshest payload for the debug overlay (shuttle lat/lng + pax orders).
    _lastPayload = payload;
    if (payload.latitude == null || payload.longitude == null) return;
    _signalRHasLocation = true;
    context.read<CabTrackingBloc>().add(SignalRLocationReceived(payload));
    final newLatLng = LatLng(payload.latitude!, payload.longitude!);
    // Recompute the ETA from this fresh location + speed every time SignalR
    // pushes an update, so the bottom sheet always shows a live estimate.
    _updateEta(driver: newLatLng, speedKmh: payload.speed);
    // If this payload carries fresher passenger boarding data, rebuild the
    // timeline so the markers / segments / sheet reflect new boardings live.
    _rebuildTimelineFromPayload(payload);
    if (_useSignalRWaypoints && payload.passengers.isNotEmpty) {
      _rebuildStopMarkers();
      // Only (re)fetch the directions route when we don't yet have one. Do NOT
      // refetch on every GPS tick: the planned route's SHAPE only changes when
      // the drop/pickup sequence changes (handled in _rebuildTimelineFromPayload
      // via the route signature). Refetching each tick rebuilt the polyline from
      // the shuttle's latest position, so its geometry jumped every push — that was
      // the visible "fluctuation". The shuttle's forward motion is already reflected
      // by the gray/blue split below (shuttleOverride) and the active-leg refresh.
      if (_plannedPoints.length < 2) {
        unawaited(_refreshDirectionsRoute(shuttleOverride: newLatLng));
      }
    }
    _rebuildRoutePolylines(_plannedPoints, shuttleOverride: newLatLng);
    unawaited(_refreshActiveLegPolyline(shuttle: newLatLng));
    // Prefer the server-reported heading (miscellaneous.bearing) so the car icon
    // points where the device says it's heading, falling back to the computed
    // bearing from consecutive positions when the payload omits it.
    _animateCarTo(newLatLng, serverBearing: payload.miscellaneous?.bearing);
  }

  /// Merges any passenger boarding data carried on a SignalR payload into the
  /// cached status and rebuilds the personalised [_timeline].
  ///
  /// Polling is disabled while SignalR is live, so boarding changes
  /// (`empSigninTime` becoming non-null, or a `noShow` flip) would otherwise
  /// never reach the UI between REST refreshes. Each payload passenger is
  /// matched to the cached one by [empId] and its boarding fields override the
  /// cached values; passengers absent from the payload keep their cached state.
  /// Builds a [TripPassenger] from a live SignalR [RouteTripPassenger]. Used to
  /// surface passengers the REST status didn't carry, so their drop markers
  /// still appear (the payload is authoritative for `plannedLat`/`plannedLng`).
  TripPassenger _tripPassengerFromPayload(RouteTripPassenger p) {
    return TripPassenger(
      empId: p.empId,
      employeeID: p.employeeID,
      firstname: p.firstname,
      lastName: p.lastName,
      gender: p.gender,
      mobileno: p.mobileno,
      empLocCode: p.empLocCode,
      tripType: p.tripType,
      paxOrder: p.paxOrder,
      address: p.address,
      plannedLat: p.plannedLat,
      plannedLng: p.plannedLng,
      noShow: p.noShow ?? false,
      noShowReasonId: p.noShowReasonId,
      orsDeviation: p.orsDeviation ?? false,
      scheduled: p.scheduled ?? false,
      paxAdded: p.paxAdded ?? false,
      paxType: p.paxType,
      empDistance: p.empDistance,
      empDirectDistance: p.empDirectDistance,
      empCost: p.empCost,
      plannedScheduleTime: p.plannedScheduleTime,
      etaDeviationMinutes: p.etaDeviationMinutes,
      empSigninTime: p.empSigninTime,
      empSigninLat: p.empSigninLat,
      empSigninLng: p.empSigninLng,
      empSignOutTime: p.empSignOutTime,
      empSignOutLat: p.empSignOutLat,
      empSignOutLng: p.empSignOutLng,
      cabReachedTime: p.cabReachedTime,
      cabReachedLat: p.cabReachedLat,
      cabReachedLng: p.cabReachedLng,
      reachedHomeTime: p.reachedHomeTime,
      reachedHomeLat: p.reachedHomeLat,
      reachedHomeLng: p.reachedHomeLng,
      paxTrackingStatus: p.paxTrackingStatus,
    );
  }

  void _rebuildTimelineFromPayload(RouteLocationPayload payload) {
    final status = _latestStatus;
    if (status == null || payload.passengers.isEmpty) return;

    final byEmpId = {
      for (final p in payload.passengers)
        if (p.empId != null) p.empId!: p,
    };

    final merged = status.passengers.map((cached) {
      final live = byEmpId[cached.empId];
      if (live == null) return cached;
      return TripPassenger(
        empId: cached.empId,
        employeeID: cached.employeeID,
        firstname: cached.firstname,
        lastName: cached.lastName,
        gender: cached.gender,
        mobileno: cached.mobileno,
        empLocCode: cached.empLocCode,
        tripType: cached.tripType,
        paxOrder: live.paxOrder ?? cached.paxOrder,
        address: cached.address,
        // Use the live SignalR planned coords whenever SignalR is active — this
        // drives BOTH the passenger markers and (when shouldUsePolyline is on)
        // the route. Gating on shouldUsePolyline too meant a SignalR trip with
        // polyline off never placed passenger markers even though the payload
        // carried valid plannedLat/Lng. Only adopt non-zero live coords.
        plannedLat: status.shouldUseSignalR &&
                live.plannedLat != null &&
                live.plannedLat != 0
            ? live.plannedLat
            : cached.plannedLat,
        plannedLng: status.shouldUseSignalR &&
                live.plannedLng != null &&
                live.plannedLng != 0
            ? live.plannedLng
            : cached.plannedLng,
        noShow: live.noShow ?? cached.noShow,
        noShowReasonId: live.noShowReasonId ?? cached.noShowReasonId,
        orsDeviation: cached.orsDeviation,
        scheduled: cached.scheduled,
        paxAdded: cached.paxAdded,
        paxType: cached.paxType,
        empDistance: cached.empDistance,
        empDirectDistance: cached.empDirectDistance,
        empCost: cached.empCost,
        // Prefer the live SignalR schedule/deviation so the expected arrival
        // clock (plannedScheduleTime + etaDeviationMinutes) stays current on
        // every push, falling back to the cached values when absent.
        plannedScheduleTime:
            live.plannedScheduleTime ?? cached.plannedScheduleTime,
        etaDeviationMinutes:
            live.etaDeviationMinutes ?? cached.etaDeviationMinutes,
        empSigninTime: live.empSigninTime ?? cached.empSigninTime,
        empSigninLat: live.empSigninLat ?? cached.empSigninLat,
        empSigninLng: live.empSigninLng ?? cached.empSigninLng,
        empSignOutTime: live.empSignOutTime ?? cached.empSignOutTime,
        empSignOutLat: live.empSignOutLat ?? cached.empSignOutLat,
        empSignOutLng: live.empSignOutLng ?? cached.empSignOutLng,
        cabReachedTime: live.cabReachedTime ?? cached.cabReachedTime,
        cabReachedLat: live.cabReachedLat ?? cached.cabReachedLat,
        cabReachedLng: live.cabReachedLng ?? cached.cabReachedLng,
        reachedHomeTime: live.reachedHomeTime ?? cached.reachedHomeTime,
        reachedHomeLat: live.reachedHomeLat ?? cached.reachedHomeLat,
        reachedHomeLng: live.reachedHomeLng ?? cached.reachedHomeLng,
        paxTrackingStatus: live.paxTrackingStatus ?? cached.paxTrackingStatus,
      );
    }).toList();

    // Some REST status responses carry no passenger rows (or omit ones the
    // SignalR payload knows about), so a pure empId merge would drop those
    // passengers and their drop markers would never render. Append any payload
    // passenger that has no cached match, synthesised straight from the live
    // SignalR fields — this is the authoritative source for plannedLat/Lng.
    final cachedEmpIds = {
      for (final c in status.passengers)
        if (c.empId != null) c.empId,
    };
    for (final live in payload.passengers) {
      if (live.empId == null || cachedEmpIds.contains(live.empId)) continue;
      merged.add(_tripPassengerFromPayload(live));
    }
    merged.sort((a, b) => (a.paxOrder ?? 0).compareTo(b.paxOrder ?? 0));

    final wasBoarded = _timeline.meBoarded;
    // LOGIN: signature of the remaining-pickup route while not yet boarded
    // (current pickup target + count of unboarded pickups up to my own). When a
    // pickup ahead boards/no-shows, the not-boarded blue route shortens, so it
    // must be rebuilt even though the viewer's own boarding state hasn't flipped.
    final prevLoginSig = _isLoginTripType() ? _loginRouteSignature() : null;
    // LOGOUT: signature of the remaining drop sequence (current target order +
    // count of homes still to visit). When a passenger is dropped or marked
    // no-show this changes, so the planned route must be rebuilt.
    final prevLogoutSig = _isLogoutTripType() ? _logoutRouteSignature() : null;

    final mergedStatus = status.withPassengers(merged);
    _latestStatus = mergedStatus;
    // Keep the cached state in sync so the bottom sheet reflects the merged
    // live passenger data on the next repaint (no loader, real-time).
    _latestData = _latestData?.copyWith(status: mergedStatus);
    _timeline = RideTimeline.fromStatus(mergedStatus, meEmpId: widget.empId);
    _fullTimeline = RideTimeline.fromStatus(mergedStatus,
        meEmpId: widget.empId, includeAllStops: true);
    // Refresh markers + active leg when paxTrackingStatus advances the target.
    _rebuildStopMarkers();
    // Flush to UI so the stop list + banner reflect the new
    // paxTrackingStatus values immediately on every SignalR push.
    if (mounted) setState(() {});
    final shuttle = (payload.latitude != null && payload.longitude != null)
        ? LatLng(payload.latitude!, payload.longitude!)
        : null;
    // LOGIN: rebuild the planned route when either
    //   * the viewer's own boarding state flips (not boarded → shuttle → … → my
    //     pickup; boarded → next pickups + office), or
    //   * the remaining-pickup sequence ahead changes while not boarded (a
    //     pickup ahead boards/no-shows), shortening the blue tail.
    // so the blue route stays correct live, regardless of whether waypoints
    // come from SignalR or REST.
    if (_isLoginTripType() &&
        (_timeline.meBoarded != wasBoarded ||
            _loginRouteSignature() != prevLoginSig)) {
      unawaited(_refreshDirectionsRoute(shuttleOverride: shuttle));
    }
    // LOGOUT: rebuild the planned route whenever the remaining drop sequence
    // changes (a passenger dropped home or marked no-show), so completed homes
    // disappear and the current/upcoming colouring stays correct live.
    if (_isLogoutTripType() && _logoutRouteSignature() != prevLogoutSig) {
      unawaited(_refreshDirectionsRoute(shuttleOverride: shuttle));
    }
    unawaited(_refreshActiveLegPolyline(shuttle: shuttle));
  }

  /// A compact signature of the LOGOUT remaining-drop route — the current drop
  /// target's paxOrder plus the count of passengers still awaiting drop. Used
  /// to detect when a drop/no-show has reshaped the route so it can be rebuilt.
  String _logoutRouteSignature() {
    final status = _latestStatus;
    if (status == null) return '';
    var remaining = 0;
    for (final p in status.passengers) {
      if (logoutPaxIsRemaining(p)) remaining++;
    }
    return '${_fleetFirstPendingDrop?.order ?? -1}:$remaining';
  }

  /// A compact signature of the LOGIN remaining-pickup route while the viewer is
  /// NOT yet boarded — the current pickup target's order plus the count of
  /// unboarded pickups up to and including the viewer's own pickup. When a
  /// pickup ahead boards/no-shows (or the viewer's own order resolves), this
  /// changes so the not-boarded blue route (shuttle → … → my pickup) is rebuilt.
  String _loginRouteSignature() {
    final status = _latestStatus;
    if (status == null) return '';
    final cap = _myPaxOrder;
    var remaining = 0;
    for (final p in status.passengers) {
      final order = p.paxOrder;
      if (order == null) continue;
      if (cap != null && order > cap) continue;
      if (isPaxRouteResolved(p, isPickupTrip: true)) continue;
      remaining++;
    }
    return '${_fleetFirstPendingPickup?.order ?? -1}:$remaining';
  }

  /// True when waypoint markers should use live SignalR passenger coordinates.
  bool get _useSignalRWaypoints {
    final status = _latestStatus;
    return status?.shouldUseSignalR == true &&
        status?.shouldUsePolyline == true;
  }

  /// Resolves a stop's map position from the correct source:
  /// SignalR [RouteTripPassenger.plannedLat]/[plannedLng] when both tracking
  /// flags are on, otherwise [TripPassenger.plannedLat]/[plannedLng] from REST.
  LatLng? _waypointLocationForStop(RideStop stop) {
    if (stop.isOffice) return stop.location;

    // REST passengers — [TripPassenger.plannedLat]/[plannedLng] via timeline.
    if (!_useSignalRWaypoints) return stop.location;

    // Live SignalR waypoints — match by [paxOrder], fall back to merged status.
    final order = stop.order;
    if (order != null) {
      final payloadPax = _lastPayload?.passengers ?? const [];
      for (final p in payloadPax) {
        if (p.paxOrder == order) {
          final lat = p.plannedLat;
          final lng = p.plannedLng;
          if (lat != null && lng != null && (lat != 0 || lng != 0)) {
            return LatLng(lat, lng);
          }
          break;
        }
      }

      final statusPax = _latestStatus?.passengers ?? const [];
      for (final p in statusPax) {
        if (p.paxOrder == order) {
          final lat = p.plannedLat;
          final lng = p.plannedLng;
          if (lat != null && lng != null && (lat != 0 || lng != 0)) {
            return LatLng(lat, lng);
          }
          break;
        }
      }
    }

    return stop.location;
  }

  /// Ordered waypoint coordinates for the Google Directions API fallback.
  ///
  /// Uses the full fleet passenger list (all paxOrders sorted ascending) plus
  /// the office — NOT the personalised [_timeline.stops] — so that the planned
  /// polyline always passes through every stop in route order regardless of
  /// which passenger is viewing (e.g. pax2 still sees the pax1 → pax2 leg).
  List<LatLng> _orderedWaypointPoints() {
    final status = _latestStatus;
    if (status == null) {
      // Fallback: derive from timeline stops (no status cached yet).
      final pts = <LatLng>[];
      for (final stop in _timeline.stops) {
        final loc = _waypointLocationForStop(stop);
        if (loc != null) pts.add(loc);
      }
      return pts;
    }

    // LOGIN: the planned route is gated by boarding state — not boarded shows
    // only the active leg (no planned route); boarded shows every remaining
    // unboarded pickup + office.
    if (_isLoginTripType()) {
      return _loginPlannedWaypoints();
    }

    // LOGOUT: shuttle → remaining drops (excluding completed/no-show) up to the
    // viewer's own drop. No office node — the shuttle has already left the office.
    if (_isLogoutTripType()) {
      return buildLogoutTripWaypoints();
    }

    final pax = List<TripPassenger>.from(status.passengers)
      ..sort((a, b) => (a.paxOrder ?? 0).compareTo(b.paxOrder ?? 0));

    final pts = <LatLng>[];
    final isLogout = _timeline.isLogout;

    // LOGOUT: the planned route for THIS viewer ends at their own drop stop —
    // never beyond it. Cap the waypoint list at the viewer's paxOrder so the
    // polyline (gray completed + orange active) terminates at their lat/lng.
    final int? myOrder = isLogout ? _myPaxOrder : null;

    // LOGOUT: office first (origin), then drop stops.
    if (isLogout) {
      final officeLat = status.officeLat;
      final officeLng = status.officeLng;
      if (officeLat != null &&
          officeLng != null &&
          (officeLat != 0 || officeLng != 0)) {
        pts.add(LatLng(officeLat, officeLng));
      }
    }

    for (final p in pax) {
      // Stop once we pass the viewer's own drop on a LOGOUT trip.
      if (myOrder != null && p.paxOrder != null && p.paxOrder! > myOrder) break;
      LatLng? loc;
      if (_useSignalRWaypoints) {
        // Prefer live SignalR coords when available.
        final payloadPax = _lastPayload?.passengers ?? const [];
        for (final pp in payloadPax) {
          if (pp.paxOrder == p.paxOrder) {
            final lat = pp.plannedLat;
            final lng = pp.plannedLng;
            if (lat != null && lng != null && (lat != 0 || lng != 0)) {
              loc = LatLng(lat, lng);
            }
            break;
          }
        }
        // Fall back to merged status coords.
        if (loc == null) {
          final lat = p.plannedLat;
          final lng = p.plannedLng;
          if (lat != null && lng != null && (lat != 0 || lng != 0)) {
            loc = LatLng(lat, lng);
          }
        }
      } else {
        final lat = p.plannedLat;
        final lng = p.plannedLng;
        if (lat != null && lng != null && (lat != 0 || lng != 0)) {
          loc = LatLng(lat, lng);
        }
      }
      if (loc != null) pts.add(loc);
    }

    // LOGIN: office last (destination).
    if (!isLogout) {
      final officeLat = status.officeLat;
      final officeLng = status.officeLng;
      if (officeLat != null &&
          officeLng != null &&
          (officeLat != 0 || officeLng != 0)) {
        pts.add(LatLng(officeLat, officeLng));
      }
    }

    return pts;
  }

  /// Builds the planned route through every stop via Google Directions API.
  ///
  /// Memoised by waypoint signature: the route's geometry depends only on its
  /// ordered waypoints, so an unchanged stop sequence reuses the previous result
  /// instead of issuing another Directions request. A changed sequence (boarding,
  /// drop, no-show) produces a new signature and refetches, so every existing
  /// rebuild trigger behaves exactly as before.
  Future<List<LatLng>> _fetchDirectionsPlannedRoute() async {
    final waypoints = _orderedWaypointPoints();
    if (waypoints.length < 2) return const [];

    final signature = _waypointsSignature(waypoints);

    // Same waypoints as the last successful fetch — reuse that geometry.
    if (signature == _plannedRouteSignature && _plannedRouteCache.length >= 2) {
      return _plannedRouteCache;
    }

    // A fetch for this exact waypoint list is already running — join it so
    // overlapping callers produce a single Directions request.
    final inFlight = _plannedRouteInFlight;
    if (inFlight != null && signature == _plannedRouteSignature) {
      return inFlight;
    }

    // Publish the signature + Future synchronously (before any await) so a
    // caller in the same event-loop turn joins instead of starting a duplicate.
    _plannedRouteSignature = signature;
    final request = fetchRoutePolylineThroughPoints(waypoints);
    _plannedRouteInFlight = request;

    try {
      final points = await request;
      // Cache successes only. `fetchRoutePolylineThroughPoints` falls back to
      // returning the raw waypoints when the API fails, so require a real
      // road-following result before memoising it.
      if (points.length >= 2) {
        _plannedRouteCache = points;
      } else {
        _plannedRouteSignature = null;
      }
      return points;
    } catch (_) {
      // Don't memoise a failure — let the next call retry, as it does today.
      _plannedRouteSignature = null;
      rethrow;
    } finally {
      if (_plannedRouteInFlight == request) _plannedRouteInFlight = null;
    }
  }

  /// Compact signature of an ordered waypoint list, used to detect whether the
  /// planned route's shape actually changed. Coordinates are rounded to ~1 m so
  /// insignificant GPS jitter in a stop's reported position doesn't invalidate
  /// the memo.
  String _waypointsSignature(List<LatLng> points) => points
      .map((p) => '${p.latitude.toStringAsFixed(5)},'
          '${p.longitude.toStringAsFixed(5)}')
      .join(';');

  Future<void> _applyDirectionsPlannedRoute({LatLng? shuttleOverride}) async {
    final planned = await _fetchDirectionsPlannedRoute();
    if (!mounted || planned.isEmpty) return;
    _plannedPoints = planned;
    _rebuildRoutePolylines(_plannedPoints);
    setState(() {});
    unawaited(_refreshActiveLegPolyline(shuttle: shuttleOverride));
  }

  Future<void> _refreshDirectionsRoute({LatLng? shuttleOverride}) async {
    await _applyDirectionsPlannedRoute(shuttleOverride: shuttleOverride);
  }

  List<LatLng> _decodePolyline(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return const [];
    try {
      return PolylinePoints()
          .decodePolyline(encoded)
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Fetches [GpsRouteResponse] and decodes the full planned polyline for the
  /// map. Falls back to Google Directions through waypoint stops when
  /// the encoded planned polyline is absent. Safe to call repeatedly.
  Future<void> _loadGpsRoutePolylines(int tripId) async {
    try {
      final route = await sl<UserCabTrackingRepo>().getGpsRoute(tripId: tripId);
      if (!mounted) return;

      // The encoded planned polyline from the API traces the FULL fleet route
      // (office → every drop). On LOGOUT trips that would draw the route past
      // the viewer's own drop, and on LOGIN trips it would show the whole route
      // before the viewer has even boarded — both want a personalised route
      // instead, so suppress the encoded polyline and let the Directions
      // fallback below build the capped/boarding-gated route. Other trip types
      // keep using the precise encoded polyline when present.
      var planned = (_isLogoutTripType() || _isLoginTripType())
          ? const <LatLng>[]
          : _decodePolyline(route.plannedRoutePolyline);

      if (planned.isNotEmpty) {
        _plannedPoints = planned;
      } else {
        planned = await _fetchDirectionsPlannedRoute();
        if (planned.isNotEmpty) {
          _plannedPoints = planned;
        }
      }

      _rebuildRoutePolylines(_plannedPoints);
      setState(() {});
      unawaited(_refreshActiveLegPolyline());
    } catch (e) {
      debugPrint('[ShuttleRideTrackingScreen] GPS route fetch error: $e');
      await _applyDirectionsPlannedRoute();
    }
  }

  /// The shuttle's route as place-level stops, rebuilt from the current
  /// timeline on every read so it always reflects the freshest live data.
  ///
  /// Uses the FULL timeline (every stop on the route), not the personalised
  /// one: a shuttle rider is shown the whole line, the same way a bus route is
  /// posted at the stop. Because [_ShuttleStop] carries no rider identity, this
  /// still exposes nothing about who else is travelling.
  List<_ShuttleStop> get _shuttleStops {
    final target = _activeTarget;
    return _ShuttleStop.fromTimeline(
      _fullTimeline,
      officeName: _empOfficeName,
      activeEtaMinutes: _shouldShowActiveLeg() ? _etaMinutes : null,
      activeOrder: target?.isOffice == true ? null : target?.order,
      activeIsOffice: target?.isOffice == true,
      myBoardedClock: _myBoardedClock,
    );
  }

  /// Rebuilds the shuttle's stop + office markers from the current route,
  /// leaving the driver marker untouched (it is animated separately).
  ///
  /// Markers are place-level: each one is titled "Stop N — <address>" and never
  /// carries a passenger's name, so tapping a pin on a shuttle can't reveal who
  /// boards there. Colouring follows the stop's own progress — green once the
  /// shuttle has served it, orange for the stop it is heading to, blue for the
  /// ones still ahead, purple for the office terminus.
  void _rebuildStopMarkers() {
    _markers.removeWhere((m) =>
        m.markerId.value.startsWith('stop_') || m.markerId.value == 'office');

    for (final stop in _shuttleStops) {
      // Resolve the live coordinate the same way the route waypoints do, so a
      // marker never drifts from the polyline it sits on.
      final loc = _shuttleStopLocation(stop);
      if (loc == null) continue;

      final id = stop.isOffice ? 'office' : 'stop_${stop.index}';
      final title = stop.isOffice
          ? stop.name
          : '${stop.sequenceLabel} · ${stop.name}'
              '${stop.isMine ? ' (Your stop)' : ''}';

      final eta = stop.etaLabel;
      // On the rider's own boarded stop the time is a pickup that already
      // happened, so it is labelled as such rather than as an ETA.
      final boarded = stop.boardedClock;
      final snippet = boarded != null
          ? '${stop.statusLabel} · Picked up $boarded'
          : eta == null
              ? stop.statusLabel
              : '${stop.statusLabel} · ETA $eta';

      _markers.add(Marker(
        markerId: MarkerId(id),
        position: loc,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _shuttleStopHue(stop),
        ),
        infoWindow: InfoWindow(title: title, snippet: snippet),
      ));
    }
  }

  /// Marker hue for a shuttle stop: office=purple, served=green,
  /// next stop=orange, still ahead=blue.
  double _shuttleStopHue(_ShuttleStop stop) {
    if (stop.isOffice) return BitmapDescriptor.hueViolet;
    switch (stop.state) {
      case StopState.completed:
        return BitmapDescriptor.hueGreen;
      case StopState.current:
        return BitmapDescriptor.hueOrange;
      case StopState.upcoming:
      case StopState.noShow:
        return BitmapDescriptor.hueAzure;
    }
  }

  /// Live coordinate for a shuttle stop, preferring the SignalR-sourced
  /// waypoint (matched by route position) over the one baked into the stop, so
  /// markers and the drawn route stay in agreement.
  LatLng? _shuttleStopLocation(_ShuttleStop stop) {
    if (stop.isOffice) return stop.location ?? _officeLatLng;
    if (!_useSignalRWaypoints) return stop.location;

    final loc = stop.location;
    if (loc == null) return null;

    // Match the live payload by proximity: [_ShuttleStop] is keyed by place,
    // not paxOrder, so several passengers may back one stop. Any live
    // coordinate within ~50 m is the same halt.
    for (final p in _lastPayload?.passengers ?? const []) {
      final lat = p.plannedLat;
      final lng = p.plannedLng;
      if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;
      final live = LatLng(lat, lng);
      if (_approxDistanceMeters(live, loc) < 50) return live;
    }
    return loc;
  }

  /// Recomputes the live ETA to the office destination from the driver's
  /// current position and reported GPS speed.
  ///
  /// Distance is measured along the remaining planned route polyline when one
  /// is available (more accurate than straight-line), falling back to the
  /// great-circle distance to the office otherwise. Speed falls back to
  /// [_fallbackSpeedKmh] when the shuttle is stopped so the ETA never blows up.
  /// When [notify] is false the field is updated without calling setState —
  /// used when the caller (e.g. `_applyStateToMap`) flushes its own setState.
  void _updateEta({
    required LatLng driver,
    double? speedKmh,
    bool notify = true,
  }) {
    final dest = _destination;
    if (dest == null) return;

    final meters = _remainingRouteMeters(driver, dest);
    final int minutes;
    if (meters <= 0) {
      minutes = 0;
    } else {
      final effectiveSpeed =
          (speedKmh != null && speedKmh > 1) ? speedKmh : _fallbackSpeedKmh;
      final hours = (meters / 1000.0) / effectiveSpeed;
      minutes = (hours * 60).ceil().clamp(0, 24 * 60);
    }

    if (minutes == _etaMinutes) return;
    if (notify) {
      setState(() {
        _etaMinutes = minutes;
        _rebuildStopMarkers();
      });
    } else {
      _etaMinutes = minutes;
    }
  }

  /// The office coordinates, when known.
  LatLng? get _officeLatLng {
    final status = _latestStatus;
    final lat = status?.officeLat;
    final lng = status?.officeLng;
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return LatLng(lat, lng);
  }

  /// My own pickup/drop stop on the personalised timeline (the "(You)" stop).
  RideStop? get _myStop {
    for (final s in _timeline.stops) {
      if (s.isMe) return s;
    }
    return null;
  }

  /// The logged-in passenger's own paxOrder, or null if it can't be resolved.
  int? get _myPaxOrder {
    final meEmpId = widget.empId;
    final status = _latestStatus;
    if (meEmpId != null && status != null) {
      for (final p in status.passengers) {
        if (p.empId == meEmpId) return p.paxOrder;
      }
    }
    // Fall back to the personalised timeline's "(You)" stop order.
    return _myStop?.order;
  }

  /// The clock time at which the viewer was actually picked up, from their own
  /// `empSigninTime` (the driver's sign-in stamp, and the same field that drives
  /// [TripPassenger.isBoarded]). Null until they board, so the banner shows the
  /// row only once there is a real pickup to report.
  String? get _myBoardedClock {
    final status = _latestStatus;
    final meEmpId = widget.empId;
    if (status == null || meEmpId == null) return null;
    for (final p in status.passengers) {
      if (p.empId == meEmpId) {
        return p.isBoarded ? formatBoardedClock(p.empSigninTime) : null;
      }
    }
    return null;
  }

  /// The office name to display, sourced from the logged-in passenger's
  /// [TripPassenger.empOffice]. Prefers the viewer's own passenger row (matched
  /// by [widget.empId]); falls back to the first non-empty `empOffice` on the
  /// trip. Returns null when no passenger carries an office name, so callers can
  /// preserve their existing fallback (the timeline's office title).
  String? get _empOfficeName {
    final status = _latestStatus;
    if (status == null) return null;
    final meEmpId = widget.empId;
    if (meEmpId != null) {
      for (final p in status.passengers) {
        if (p.empId == meEmpId) {
          final name = p.empOffice?.trim();
          if (name != null && name.isNotEmpty) return name;
          break;
        }
      }
    }
    for (final p in status.passengers) {
      final name = p.empOffice?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

  /// The shuttle's first/next pending pickup on a LOGIN trip ("pickup1") — the first
  /// stop in route order whose passenger has not yet been picked up. Used to aim
  /// the active leg at the shuttle's next real pickup before the viewer has boarded,
  /// even when other passengers are picked up ahead of them. Null on non-LOGIN
  /// trips or when no pending pickup remains.
  RideStop? get _fleetFirstPendingPickup {
    if (!_isLoginTripType()) return null;
    final status = _latestStatus;
    if (status == null) return null;

    final pax = List<TripPassenger>.from(status.passengers)
      ..sort((a, b) => (a.paxOrder ?? 0).compareTo(b.paxOrder ?? 0));
    for (final p in pax) {
      if (isPaxFleetActiveLegCandidate(p, isPickupTrip: true)) {
        for (final s in _timeline.stops) {
          if (!s.isOffice && s.order == p.paxOrder) return s;
        }
        break;
      }
    }
    return null;
  }

  /// The shuttle's current drop target on a LOGOUT trip — the first passenger (by
  /// paxOrder) where `reachedHomeTime == null && noShow != true`. This is the
  /// home the shuttle is actively heading to. Null on non-LOGOUT trips or once every
  /// passenger has been dropped / marked no-show.
  RideStop? get _fleetFirstPendingDrop {
    if (!_isLogoutTripType()) return null;
    final status = _latestStatus;
    if (status == null) return null;

    final pax = List<TripPassenger>.from(status.passengers)
      ..sort((a, b) => (a.paxOrder ?? 0).compareTo(b.paxOrder ?? 0));
    for (final p in pax) {
      if (logoutPaxIsRemaining(p)) {
        for (final s in _timeline.stops) {
          if (!s.isOffice && s.order == p.paxOrder) return s;
        }
        break;
      }
    }
    return null;
  }

  /// The office stop from the current timeline, if present.
  RideStop? get _officeStop {
    for (final s in _timeline.stops) {
      if (s.isOffice) return s;
    }
    return null;
  }

  /// Effective active-leg target stop — the next place the shuttle is driving to.
  ///
  /// LOGIN (passenger-wise shuttle logic): the active leg always follows the
  /// shuttle's real next move, regardless of the viewer's own paxOrder:
  ///   * pickups still pending → shuttle → next unboarded pickup ("pickup1").
  ///   * all pickups boarded/no-show → shuttle → office (final destination).
  /// This holds both before and after the viewer boards, so a boarded P1 and a
  /// still-waiting P3 both see the leg pointed at the shuttle's actual next stop.
  ///
  /// LOGOUT (passenger-wise drop logic): the active leg follows the shuttle's real
  /// next drop — the first passenger still awaiting drop (`reachedHomeTime ==
  /// null && !noShow`) by paxOrder — for every viewer alike. Once all drops are
  /// done it is null (trip complete). The office is never a target on a drop
  /// trip: the shuttle has already left it.
  ///
  /// Other trip types keep the personalised [_timeline.target].
  RideStop? get _activeTarget {
    if (_isLoginTripType()) {
      final nextPickup = _fleetFirstPendingPickup;
      if (nextPickup != null) return nextPickup;
      // No pickups left → head to office.
      return _officeStop ?? _timeline.target;
    }
    if (_isLogoutTripType()) {
      // LOGOUT viewer-status gating (keyed off THIS passenger's status):
      //   * Not-Boarded → shuttle has not left with them yet → aim the orange leg at
      //     the office (shuttle → office), not at a drop home.
      //   * No-Show     → no active leg at all (also gated in _shouldShowActiveLeg).
      //   * En-Route / others → existing behaviour: shuttle → first remaining drop.
      switch (_myLogoutTrackingStatus) {
        case 'not-boarded':
          return _officeStop ?? _fleetFirstPendingDrop;
        case 'no-show':
          return null;
      }
      // Shuttle → first remaining drop; null when every passenger is dropped.
      return _fleetFirstPendingDrop;
    }
    return _timeline.target;
  }

  /// Destination for the live ETA — matches the orange active-leg endpoint.
  LatLng? get _destination => _activeLegDestinationLatLng();

  /// True when the orange shuttle→stop leg should render (hidden after Completed/Dropped).
  bool _shouldShowActiveLeg() {
    final target = _activeTarget;
    if (target == null) return false;

    final me = _myStop;
    final status = _latestStatus;
    final meEmpId = widget.empId;

    if (me != null && status != null && meEmpId != null) {
      for (final p in status.passengers) {
        if (p.empId != meEmpId) continue;
        // LOGOUT (spec): the viewer's trip ends the moment they reach home
        // (Completed) or are a no-show — stop their active navigation then.
        if (_isLogoutTripType()) {
          final st = logoutPaxStatusOf(p);
          return st == LogoutPaxStatus.boarded;
        }
        return !shouldHideActiveLegForPassenger(
          p,
          isPickupTrip: !_timeline.isLogout,
        );
      }
    }
    return true;
  }

  /// Resolves the orange active-leg endpoint — the shuttle's current drop/pickup
  /// target home. On LOGOUT trips this is always the first remaining drop home
  /// (no office routing: the shuttle has already left the office).
  LatLng? _activeLegDestinationLatLng() {
    if (!_shouldShowActiveLeg()) return null;

    final target = _activeTarget;
    if (target == null) return null;

    if (target.isOffice) return _waypointLocationForStop(target);

    return _waypointLocationForStop(target);
  }

  /// Distance (m) from [driver] to [dest] along the planned polyline if one
  /// exists, else the straight-line great-circle distance.
  ///
  /// Sums segment lengths from the vertex nearest the driver to the vertex
  /// nearest [dest] (the current target stop), so the ETA counts down to the
  /// stop the shuttle is actually heading to — not always the route's end.
  double _remainingRouteMeters(LatLng driver, LatLng dest) {
    final route = _plannedPoints;
    if (route.length < 2) return _approxDistanceMeters(driver, dest);

    final driverIdx = _nearestVertexIndex(route, driver);
    final destIdx = _nearestVertexIndex(route, dest);
    // If the target sits "behind" the shuttle along the polyline, fall back to the
    // straight-line distance rather than summing a negative span.
    if (destIdx <= driverIdx) return _approxDistanceMeters(driver, dest);

    var meters = _approxDistanceMeters(driver, route[driverIdx]);
    for (var i = driverIdx; i < destIdx; i++) {
      meters += _approxDistanceMeters(route[i], route[i + 1]);
    }
    return meters;
  }

  String? _activeLegTargetKeyFor(RideStop? stop) {
    if (stop == null) return null;
    return '${stop.kind}_${stop.order ?? 'office'}';
  }

  /// Rebuilds [_polylines] per tracking spec:
  ///   * gray  — completed portion of planned route (behind the shuttle)
  ///   * orange — active leg ONLY (shuttle → target via Directions API)
  ///   * blue  — upcoming planned route ahead of the shuttle. LOGIN only, and only
  ///            once the viewer has boarded: shuttle → next pickups → office. Before
  ///            boarding (and on every other trip type) it stays hidden.
  void _rebuildRoutePolylines(List<LatLng> points, {LatLng? shuttleOverride}) {
    _polylines.clear();

    if (points.length >= 2) {
      final shuttleIdx = _nearestVertexIndex(
        points,
        shuttleOverride ?? _animatedDriverLatLng,
      );
      // Grey "completed" segment = the planned route already behind the shuttle.
      // This only makes sense once the shuttle has actually started consuming the
      // route — i.e. the viewer has boarded (LOGIN) or the drop sequence is
      // underway (LOGOUT). For a NOT-boarded LOGIN viewer the whole route is
      // still upcoming: shuttle → pickup1 is the orange active leg and pickup1 → my
      // pickup is the blue tail, with nothing completed. The planned route there
      // starts at pickup1 (not at the shuttle), so the shuttle's nearest vertex lands
      // mid-route and `shuttleIdx > 0` would otherwise paint the pickup1 → my-pickup
      // chunk grey. Suppress grey entirely until the viewer has boarded.
      final showCompleted = !(_isLoginTripType() && !_timeline.meBoarded);
      if (showCompleted && shuttleIdx > 0) {
        _polylines.add(Polyline(
          polylineId: const PolylineId('route_completed'),
          color: const Color(0xFFB0B6BE),
          width: 4,
          zIndex: 0,
          points: points.sublist(0, shuttleIdx + 1),
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ));
      }

      // Blue upcoming route — the remaining stop sequence BEYOND the current
      // target (the orange active leg already covers shuttle → current target):
      //   * LOGIN not boarded → next pickups → MY pickup (capped at my order).
      //   * LOGIN boarded     → next pickups → office.
      //   * LOGOUT always     → remaining drops up to the viewer's own drop.
      //
      // The blue must start where the orange leg ends — at the current target's
      // vertex — NOT at the shuttle. Anchoring it to the shuttle (`shuttleIdx`) drew the
      // whole shuttle → target span in blue underneath the wider, higher-zIndex
      // orange leg, so the blue was fully shadowed (and entirely invisible when
      // the target was the last stop). We therefore start the blue at the
      // target's nearest vertex, falling back to the shuttle vertex when no active
      // target resolves (so a route still draws). The blue's start point is
      // snapped to the shuttle's heading edge of that vertex via max(shuttleIdx, …) so
      // it never doubles back behind the shuttle.
      //
      // LOGIN is gated by `_loginPlannedWaypoints` (it returns empty when there
      // is nothing to draw — incl. before pickup data arrives, or once boarded
      // with no pickups left), so any non-empty login `points` should render —
      // including a not-yet-boarded pickup2 seeing shuttle → pickup1 → pickup2.
      // LOGOUT viewer-status gating for the blue upcoming route:
      //   * Not-Boarded → orange is shuttle → office only, no future pax route (blue off).
      //   * No-Show     → no future route at all (blue off).
      //   * En-Route / others → existing behaviour (blue upcoming → own drop).
      final logoutStatus = _myLogoutTrackingStatus;
      final showUpcoming = _isLoginTripType() ||
          (_isLogoutTripType() &&
              logoutStatus != 'not-boarded' &&
              logoutStatus != 'no-show');
      if (showUpcoming) {
        final targetLoc = _activeLegDestinationLatLng();
        // Anchor the blue at the current target's vertex (where the orange leg
        // ends). Normally we clamp to `max(shuttleIdx, …)` so it never doubles back
        // behind the shuttle. But for a NOT-boarded LOGIN viewer the route starts at
        // the target (pickup1) and the shuttle sits before it, so `shuttleIdx` lands
        // mid-route — clamping would leave the pickup1 → shuttleIdx chunk undrawn
        // (grey is suppressed there too). In that case anchor purely to the
        // target vertex so the blue covers the whole pickup1 → my-pickup tail.
        final notBoardedLogin = _isLoginTripType() && !_timeline.meBoarded;
        final int startIdx;
        if (targetLoc != null) {
          final targetIdx = _nearestVertexIndex(points, targetLoc);
          startIdx = notBoardedLogin ? targetIdx : math.max(shuttleIdx, targetIdx);
        } else {
          startIdx = shuttleIdx;
        }
        if (startIdx < points.length - 1) {
          _polylines.add(Polyline(
            polylineId: const PolylineId('route_upcoming'),
            color: const Color(0xFF2563EB),
            width: 4,
            zIndex: 1,
            points: points.sublist(startIdx),
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ));
        }
      }
    }

    if (_shouldShowActiveLeg() && _activeLegPoints.length >= 2) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route_active'),
        color: const Color(0xFFF59E0B),
        width: 5,
        zIndex: 2,
        points: _activeLegPoints,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
    }
  }

  /// Fetches a road-following polyline from the shuttle to the active-leg destination
  /// via Google Directions. Throttled to avoid hammering the API on every GPS tick.
  ///
  /// The orange active leg is always the DIRECT shuttle → current target home:
  ///   * LOGIN  → shuttle → next pickup ("pickup1") or office once all are aboard.
  ///   * LOGOUT → shuttle → first remaining drop home (the shuttle has already left the
  ///     office, so it never routes back through it).
  /// The remaining drop/pickup sequence beyond the current target is drawn as
  /// the blue "upcoming" planned route, not folded into this leg.
  Future<void> _refreshActiveLegPolyline({LatLng? shuttle}) async {
    final shuttlePos = shuttle ?? _animatedDriverLatLng;
    final targetStop = _activeTarget;
    final targetKey = _activeLegTargetKeyFor(targetStop);

    if (!_shouldShowActiveLeg() || targetStop == null || targetKey == null) {
      if (_activeLegPoints.isNotEmpty) {
        _activeLegPoints = const [];
        _activeLegTargetKey = null;
        _rebuildRoutePolylines(_plannedPoints, shuttleOverride: shuttle);
        if (mounted) setState(() {});
      }
      return;
    }

    final targetLoc = _activeLegDestinationLatLng();
    if (targetLoc == null) return;

    if (_approxDistanceMeters(shuttlePos, targetLoc) < 30) {
      _activeLegPoints = const [];
      _rebuildRoutePolylines(_plannedPoints, shuttleOverride: shuttle);
      if (mounted) setState(() {});
      return;
    }

    final targetChanged = targetKey != _activeLegTargetKey;
    if (targetChanged) {
      _activeLegTargetKey = targetKey;
      _lastActiveLegFetchAt = null;
      // Clear stale points immediately so the old route (which may extend past
      // the new target) is removed before the new fetch completes.
      if (_activeLegPoints.isNotEmpty) {
        _activeLegPoints = const [];
        _rebuildRoutePolylines(_plannedPoints, shuttleOverride: shuttle);
        if (mounted) setState(() {});
      }
    }

    final now = DateTime.now();
    if (!targetChanged &&
        _lastActiveLegFetchAt != null &&
        now.difference(_lastActiveLegFetchAt!) < _activeLegThrottle &&
        _activeLegPoints.length >= 2) {
      return;
    }

    _lastActiveLegFetchAt = now;
    final gen = ++_activeLegFetchGen;

    // Direct shuttle → current target home for every trip type (the remaining
    // sequence is the blue upcoming planned route).
    final leg = await fetchDirectionsPolyline(
      origin: shuttlePos,
      destination: targetLoc,
    );

    if (!mounted || gen != _activeLegFetchGen) return;

    _activeLegPoints = leg;
    _rebuildRoutePolylines(_plannedPoints, shuttleOverride: shuttle);
    setState(() {});
  }

  /// True when the current trip is a LOGOUT/drop trip (tripTypeCode == 2).
  bool _isLogoutTripType() {
    final status = _latestStatus;
    if (status == null) return _timeline.isLogout;
    final code = status.tripType ?? status.tripTypeCode;
    if (code != null) return code == 2;
    return _timeline.isLogout;
  }

  /// True when the current trip is a LOGIN/pickup trip (tripTypeCode == 1).
  bool _isLoginTripType() {
    final status = _latestStatus;
    if (status == null) return !_timeline.isLogout;
    final code = status.tripType ?? status.tripTypeCode;
    if (code != null) return code == 1;
    return !_timeline.isLogout;
  }

  /// The viewer's own live LOGOUT drop status, keyed off THEIR
  /// [TripPassenger.paxTrackingStatus] (matched by [widget.empId]), normalised to
  /// one of `'not-boarded'`, `'en-route'`, `'no-show'`. Returns null on non-LOGOUT
  /// trips, when the viewer's row / status is missing, or when the status is any
  /// other value — callers then fall back to the existing behaviour untouched.
  ///
  /// Only used to gate the LOGOUT polyline set (see [_rebuildRoutePolylines] /
  /// [_activeTarget]); login and all other logic are unaffected.
  String? get _myLogoutTrackingStatus {
    if (!_isLogoutTripType()) return null;
    final status = _latestStatus;
    final meEmpId = widget.empId;
    if (status == null || meEmpId == null) return null;
    for (final p in status.passengers) {
      if (p.empId != meEmpId) continue;
      final raw = p.paxTrackingStatus;
      if (raw == null || raw.trim().isEmpty) return null;
      // Normalise hyphen/underscore/space + casing, matching the existing
      // [shouldIncludeInRoute] convention.
      final s = raw
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[-_]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ');
      switch (s) {
        case 'not boarded':
          return 'not-boarded';
        case 'en route':
        case 'enroute':
        case 'in cab': // legacy backend spelling for En-Route
          return 'en-route';
        case 'no show':
          return 'no-show';
      }
      return null;
    }
    return null;
  }

  /// LOGIN-only planned-route gating (Uber/Ola-shuttle passenger-wise logic).
  ///
  /// Until the logged-in passenger boards (status still "Not Picked Up"), the
  /// only route the viewer should see is the orange active leg shuttle → pickup1
  /// (the shuttle's first unboarded pickup). So the planned route is suppressed
  /// (empty) and only the active leg renders.
  ///
  /// Once the viewer has boarded (status "Boarded"), every boarded passenger
  /// sees the SAME remaining journey — shuttle → every still-unboarded pickup (in
  /// paxOrder) → office — independent of their own paxOrder. So the moment a
  /// passenger boards, their own home drops off the route and the route shows
  /// only the pickups still ahead plus the office destination. No-show pickups
  /// are skipped; once all pickups are done it collapses to shuttle → office.
  ///
  /// Returns the personalised planned-route waypoints for a LOGIN trip, or an
  /// empty list when nothing beyond the active leg should be drawn.
  List<LatLng> _loginPlannedWaypoints() {
    final status = _latestStatus;
    if (status == null) return const [];

    final boarded = _timeline.meBoarded;

    // NOT boarded yet → the viewer (e.g. pickup2) still sees the shuttle's path to
    // their own pickup: shuttle → next unboarded pickups (in route order) → MY
    // pickup, capped at the viewer's own paxOrder. The orange active leg covers
    // shuttle → pickup1; this planned route continues pickup1 → … → my pickup as
    // the blue "upcoming" line. No office tail before boarding (the office only
    // matters once the viewer is onboard). Previously this returned an empty
    // list, so a not-yet-boarded pickup2 never got a blue route at all.
    //
    // BOARDED → every remaining unboarded pickup (in route order) + office. The
    // viewer's own paxOrder is irrelevant here: all onboard passengers share the
    // same forward route, so we never cap by `myOrder`.
    final int? cap = boarded ? null : _myPaxOrder;

    final pax = List<TripPassenger>.from(status.passengers)
      ..sort((a, b) => (a.paxOrder ?? 0).compareTo(b.paxOrder ?? 0));

    final pts = <LatLng>[];
    for (final p in pax) {
      final order = p.paxOrder;
      if (order == null) continue;
      // Before boarding, never route beyond the viewer's own pickup.
      if (cap != null && order > cap) break;
      // Skip pickups already boarded/completed and no-shows — only stops the
      // shuttle still has to reach remain on the route. The viewer's own (still
      // unboarded) pickup is NOT resolved, so it stays as the route's tail.
      if (isPaxRouteResolved(p, isPickupTrip: true)) continue;

      LatLng? loc;
      if (_useSignalRWaypoints) {
        final payloadPax = _lastPayload?.passengers ?? const [];
        for (final pp in payloadPax) {
          if (pp.paxOrder == order) {
            final lat = pp.plannedLat;
            final lng = pp.plannedLng;
            if (lat != null && lng != null && (lat != 0 || lng != 0)) {
              loc = LatLng(lat, lng);
            }
            break;
          }
        }
      }
      loc ??= (p.plannedLat != null &&
              p.plannedLng != null &&
              (p.plannedLat != 0 || p.plannedLng != 0))
          ? LatLng(p.plannedLat!, p.plannedLng!)
          : null;

      if (loc != null) pts.add(loc);
    }

    // Office tail (destination) — only once boarded; before boarding the route
    // ends at the viewer's own pickup.
    if (boarded) {
      final office = _officeLatLng;
      if (office != null) pts.add(office);
    }

    // Fewer than 2 points can't draw a polyline.
    return pts.length >= 2 ? pts : const [];
  }

  /// LOGOUT-only planned-route builder — cumulative remaining-drop routing
  /// (Uber/Ola employee-transport spec).
  ///
  /// Destinations are the remaining passenger home drops in `paxOrder` order:
  /// [getRemainingDropPassengers] keeps only the ACTIVE ones (Not-Boarded /
  /// En-Route) and drops every COMPLETED / No-Show home, so completed drops are
  /// excluded outright and a dropped passenger's home disappears from the route
  /// the instant their status flips. Mid-sequence completions/no-shows are
  /// skipped while later pending drops stay (e.g. Drop1=Reached-Home,
  /// Drop2=No-Show, Drop3/Drop4=Not-Boarded → Drop3 → Drop4).
  ///
  /// Since this is the passenger app, the chain is capped at the viewer's OWN
  /// drop (their `paxOrder`) — they never see drops beyond their home, per the
  /// Passenger App Rules. The shuttle live location is the source and is prepended
  /// here as the first waypoint, so the drawn chain reads shuttle → … → myDrop.
  /// Prepending the shuttle also guarantees ≥2 points when the viewer is the only
  /// remaining drop (paxOrder 1) — otherwise the route would never render.
  ///
  /// The office is NOT a node here: the shuttle has already left it. Returns the
  /// shuttle origin followed by the ordered remaining drop coordinates, or an empty
  /// list when no remaining drop exists (nothing left to draw).
  List<LatLng> buildLogoutTripWaypoints() {
    final status = _latestStatus;
    if (status == null) return const [];

    final myOrder = _myPaxOrder;
    // Active (Not-Boarded / En-Route) passengers only, sorted by paxOrder ASC.
    final remaining = getRemainingDropPassengers(status.passengers);

    final pts = <LatLng>[];

    // The shuttle live location is the route's origin (the shuttle has already left the
    // office). Prepend it so the chain reads shuttle → drop1 → … → myDrop, which
    // also guarantees ≥2 points when the viewer is the shuttle's only remaining
    // drop (paxOrder 1) — otherwise a single drop would yield no polyline.
    pts.add(_animatedDriverLatLng);

    for (final p in remaining) {
      final order =
          p.paxOrder!; // non-null guaranteed by getRemainingDropPassengers
      // Cap at the viewer's own drop — passengers never see drops beyond theirs.
      if (myOrder != null && order > myOrder) break;

      LatLng? loc;
      if (_useSignalRWaypoints) {
        final payloadPax = _lastPayload?.passengers ?? const [];
        for (final pp in payloadPax) {
          if (pp.paxOrder == order) {
            final lat = pp.plannedLat;
            final lng = pp.plannedLng;
            if (lat != null && lng != null && (lat != 0 || lng != 0)) {
              loc = LatLng(lat, lng);
            }
            break;
          }
        }
      }
      loc ??= (p.plannedLat != null &&
              p.plannedLng != null &&
              (p.plannedLat != 0 || p.plannedLng != 0))
          ? LatLng(p.plannedLat!, p.plannedLng!)
          : null;

      if (loc != null) pts.add(loc);
    }

    return pts.length >= 2 ? pts : const [];
  }

  /// Index of the polyline vertex closest to [p].
  int _nearestVertexIndex(List<LatLng> points, LatLng p) {
    var bestIdx = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = _approxDistanceMeters(p, points[i]);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  // ── Camera control (fit once, then stay fixed) ─────────────────────────────

  /// All the points the initial camera should frame: shuttle + every visible stop
  /// (pickups/drops) + office, deduped of empty coordinates.
  List<LatLng> _trackingFocusPoints() {
    final pts = <LatLng>[_animatedDriverLatLng];
    for (final stop in _timeline.stops) {
      final loc = _waypointLocationForStop(stop);
      if (loc != null) pts.add(loc);
    }
    return pts;
  }

  /// Builds a [LatLngBounds] enclosing [points] (≥1). Returns null if empty.
  LatLngBounds? _boundsOf(List<LatLng> points) {
    if (points.isEmpty) return null;
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    // Guard against a zero-area box (single point) which fitBounds dislikes.
    if ((maxLat - minLat).abs() < 1e-5) {
      minLat -= 0.0015;
      maxLat += 0.0015;
    }
    if ((maxLng - minLng).abs() < 1e-5) {
      minLng -= 0.0015;
      maxLng += 0.0015;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// Frames the whole trip (shuttle + stops + office) ONCE. Subsequent live updates
  /// never call this — the camera then stays put until the user recenters or
  /// the shuttle drifts off-screen. Safe to call before the controller exists.
  Future<void> _fitToTrackingBounds({bool force = false}) async {
    if (!force && _didInitialCameraFit) return;
    if (!_mapController.isCompleted) return;

    // Don't fit on a fallback-only frame (no real shuttle fix AND no stops yet) —
    // we'd just frame an arbitrary default point. Wait for real data.
    final hasRealShuttle = _animatedDriverLatLng != _fallbackCenter;
    final hasStops = _timeline.stops.any((s) => s.location != null);
    if (!force && !hasRealShuttle && !hasStops) return;

    final bounds = _boundsOf(_trackingFocusPoints());
    if (bounds == null) return;

    _didInitialCameraFit = true;
    _cameraMoveInFlight = true;
    final ctrl = await _mapController.future;
    await ctrl.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, _boundsPadding),
    );
  }

  /// Recenters on the shuttle at a close zoom — used by the recenter FAB and when
  /// the shuttle drifts out of the visible region. This is the ONLY camera move
  /// during live tracking, and it is event-driven (not per-GPS-update).
  Future<void> _recenterOnShuttle({double zoom = _followZoom}) async {
    if (!_mapController.isCompleted) return;
    _cameraMoveInFlight = true;
    final ctrl = await _mapController.future;
    await ctrl.animateCamera(
      CameraUpdate.newLatLngZoom(_animatedDriverLatLng, zoom),
    );
  }

  /// True when [p] sits outside the currently-visible map region, leaving a
  /// small inner margin so we recenter slightly before the shuttle hits the edge.
  bool _isOutsideVisibleBounds(LatLng p) {
    final b = _visibleBounds;
    if (b == null) return false;
    final latMargin = (b.northeast.latitude - b.southwest.latitude) * 0.12;
    final lngMargin = (b.northeast.longitude - b.southwest.longitude) * 0.12;
    return p.latitude > b.northeast.latitude - latMargin ||
        p.latitude < b.southwest.latitude + latMargin ||
        p.longitude > b.northeast.longitude - lngMargin ||
        p.longitude < b.southwest.longitude + lngMargin;
  }

  // Computes compass bearing (0–360°) from [from] to [to].
  double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  void _animateCarTo(LatLng target, {double? serverBearing}) {
    final from = _animatedDriverLatLng;

    // Only update the heading on meaningful movement (>1m). Below that, GPS
    // noise would spin the marker randomly while the car is effectively stopped.
    final dist = _approxDistanceMeters(from, target);
    _bearingFrom = _carBearing;
    final bool hasServerBearing = serverBearing != null && serverBearing >= 0;
    // Prefer the server-reported heading (miscellaneous.bearing) when present and
    // valid; otherwise derive it from consecutive positions. Either way the
    // marker rotates the shortest angular path so it never spins wildly.
    final double? targetBearing = hasServerBearing
        ? serverBearing % 360
        : (dist > 1 ? _bearing(from, target) : null);
    if (targetBearing != null) {
      // Compute the shortest rotation path from the current bearing
      // (e.g. 350° → 10° rotates +20°, not -340°).
      _bearingTo = _bearingFrom + _shortestTurn(_bearingFrom, targetBearing);
    } else {
      _bearingTo = _bearingFrom;
    }

    // The server bearing is authoritative and arrives per push, so apply it to
    // the icon INSTANTLY rather than easing it across the 800ms position tween —
    // this is what makes the rotation feel real-time. The position still
    // animates smoothly underneath it. `_bearingSnapped` tells the per-frame
    // tick not to re-interpolate the rotation back down toward the old value.
    _bearingSnapped = hasServerBearing && targetBearing != null;
    if (_bearingSnapped) {
      _carBearing = _bearingTo;
      _renderDriverMarker();
      setState(() {});
    }

    _moveController.stop();
    _latAnim = Tween<double>(begin: from.latitude, end: target.latitude)
        .animate(
            CurvedAnimation(parent: _moveController, curve: Curves.easeInOut));
    _lngAnim = Tween<double>(begin: from.longitude, end: target.longitude)
        .animate(
            CurvedAnimation(parent: _moveController, curve: Curves.easeInOut));

    _moveController
      ..reset()
      ..addListener(_onMoveAnimTick)
      ..forward()
          .whenComplete(() => _moveController.removeListener(_onMoveAnimTick));

    // Ola/Uber behaviour: the camera is NOT moved on every GPS update — the
    // background map stays fixed while only the marker animates. The camera is
    // nudged only when the shuttle drifts out of the currently-visible region, and
    // only after the initial fit has happened.
    if (_didInitialCameraFit &&
        !_cameraMoveInFlight &&
        _isOutsideVisibleBounds(target)) {
      _recenterOnShuttle();
    }
  }

  // Signed shortest angular delta (−180..180) to rotate from [from] to [to].
  double _shortestTurn(double from, double to) {
    var diff = (to - from) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return diff;
  }

  void _onMoveAnimTick() {
    if (!mounted) return;
    final lat = _latAnim?.value;
    final lng = _lngAnim?.value;
    if (lat == null || lng == null) return;

    _animatedDriverLatLng = LatLng(lat, lng);

    // When the heading came from the server it was already snapped instantly in
    // _animateCarTo — keep it fixed for this move instead of easing it. For a
    // computed (positional) bearing, interpolate with the same eased progress as
    // the position so the car turns gradually into the new heading.
    if (!_bearingSnapped) {
      final t = _moveController.value;
      _carBearing = _bearingFrom + (_bearingTo - _bearingFrom) * t;
    }

    _renderDriverMarker();
    setState(() {});
  }

  /// (Re)builds the animated bus marker at the current position.
  ///
  /// The bus art is a map PIN, not a directional vehicle sprite, so it is NOT
  /// rotated by the heading — spinning a pin would tilt it off-vertical. See
  /// [_kBusPinAnchor] for why it anchors at the tip.
  void _renderDriverMarker() {
    _markers.removeWhere((m) => m.markerId.value == 'driver');
    _markers.add(Marker(
      markerId: const MarkerId('driver'),
      position: _animatedDriverLatLng,
      icon: _busIcon,
      anchor: _kBusPinAnchor,
      zIndexInt: 1,
    ));
  }

  double _approxDistanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final h = sinLat * sinLat +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            sinLng *
            sinLng;
    return 2 * r * math.asin(math.sqrt(h));
  }

  Future<void> _connectSignalR(TrackingStatusResponse status) async {
    // Only connect if the backend says to use SignalR and we haven't yet.
    if (_signalREnabled || !status.shouldUseSignalR) return;
    final dsId = status.dsId ?? widget.tripId;
    if (dsId == null) return;

    final token = AuthLocalStorage().getAccessToken();
    if (token == null) return;

    _signalREnabled = true;
    _signalR.addLocationListener(_onSignalRLocation);

    try {
      await _signalR.connect(accessToken: token);
      await _signalR.joinTrackingGroup(dsId);
      // Disable polling when SignalR is active to avoid redundant REST calls.
      _pollingTimer?.cancel();
      _pollingTimer = null;
    } catch (e) {
      debugPrint('[ShuttleRideTrackingScreen] SignalR connect error: $e');
      _signalREnabled = false;
      _signalR.removeLocationListener(_onSignalRLocation);
    }
  }

  @override
  void initState() {
    super.initState();
    // The bus marker is built in didChangeDependencies instead — it reads the
    // device pixel ratio off MediaQuery, which is not available this early.
    _setupFallbackMarkers();

    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _sheetController.addListener(() {
      final expanded = _sheetController.size > 0.35;
      if (expanded != _isExpanded) setState(() => _isExpanded = expanded);
    });

    if (TrackingConfig.useDummyTracking) {
      // Testing/demo path: drive the SAME code paths with a local simulator
      // instead of the bloc/REST/SignalR feed. The screen never learns it's
      // dummy — it consumes identical RouteLocationPayload updates.
      _startDummyTracking();
    } else {
      // Production path — unchanged.
      _startPolling();
    }

    // Refresh paxTrackingStatus + rebuild the personalised/full timelines from
    // the latest SignalR payload every 200 ms (silent UI tick — no loader).
    // This also keeps the expected-arrival clock current since it repaints.
    _statusRefreshTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _refreshPaxTrackingStatus(),
    );
  }

  /// Seeds the screen from canned data and starts the local GPS simulator.
  /// Bypasses the bloc/REST/SignalR flow entirely; only runs in dummy mode.
  void _startDummyTracking() {
    final dummy = DummyTrackingService();
    _dummy = dummy;

    // Seed the map/timeline from a status that matches the live API structure,
    // routed through the same _applyStateToMap the live state uses.
    final status = dummy.seedStatus;
    final seed = RideTrackingDataState(
      status: status,
      detail: CabTrackingData(
        driverName: status.driverName,
        vehicleRegistrationNo: status.vehicleNo,
        officeLat: status.officeLat,
        officeLng: status.officeLng,
        totalPax: status.passengers.length,
      ),
      plannedPolylinePoints: dummy.routePoints,
    );
    _dummyData = seed;
    // After first frame so the map controller / context are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyStateToMap(seed);
      // Synthetic location updates arrive via the SAME callback SignalR uses.
      dummy.addLocationListener(_onSignalRLocation);
      dummy.start();
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      context.read<CabTrackingBloc>().add(const RefreshCabTracking());
    });
  }

  /// Dispatches a silent [RefreshCabTracking] (no loader — the bloc emits a
  /// fresh [RideTrackingDataState], never a loading state) at most once every
  /// [_silentRefreshThrottle], so passenger data keeps refreshing from the API
  /// between SignalR pings. The driver position stays SignalR-authoritative
  /// (REST never overwrites it once [_signalRHasLocation] is true), so this only
  /// freshens passenger/status fields — exactly the real-time update we want.
  ///
  /// Skipped in dummy mode (no bloc feed) and while a fresh refresh is still
  /// inside the throttle window.
  void _maybeSilentRefresh() {
    if (TrackingConfig.useDummyTracking) return;
    final now = DateTime.now();
    final last = _lastSilentRefreshAt;
    if (last != null && now.difference(last) < _silentRefreshThrottle) return;
    _lastSilentRefreshAt = now;
    context.read<CabTrackingBloc>().add(const RefreshCabTracking());
  }

  /// Silently re-applies [paxTrackingStatus] from the latest SignalR payload
  /// into the timeline stops and flushes the UI — no loading state touched.
  ///
  /// Fires on the 200 ms tick. Two things happen every tick:
  ///   1. A throttled silent REST refresh ([_maybeSilentRefresh]) so passenger
  ///      data keeps flowing from the API even between SignalR pings — this is
  ///      what makes the screen feel real-time without a loader.
  ///   2. The latest cached SignalR payload is re-merged + the UI repainted so
  ///      the live arrival clock stays current at the tick cadence.
  void _refreshPaxTrackingStatus() {
    if (!mounted) return;
    // Pull fresh passenger data from the API on a throttled cadence (no loader).
    _maybeSilentRefresh();

    final payload = _lastPayload;
    if (payload == null || payload.passengers.isEmpty) return;

    final byEmpId = <int, RouteTripPassenger>{
      for (final p in payload.passengers)
        if (p.empId != null) p.empId!: p,
    };

    final status = _latestStatus;
    if (status == null) return;

    bool changed = false;
    final updated = status.passengers.map((p) {
      final live = byEmpId[p.empId];
      final liveStatus = live?.paxTrackingStatus;
      final liveDeviation = live?.etaDeviationMinutes;
      final liveSchedule = live?.plannedScheduleTime;
      final statusChanged =
          liveStatus != null && liveStatus != p.paxTrackingStatus;
      final deviationChanged =
          liveDeviation != null && liveDeviation != p.etaDeviationMinutes;
      final scheduleChanged = liveSchedule != null &&
          liveSchedule.trim().isNotEmpty &&
          liveSchedule != p.plannedScheduleTime;
      if (statusChanged || deviationChanged || scheduleChanged) {
        changed = true;
        return TripPassenger(
          empId: p.empId,
          employeeID: p.employeeID,
          firstname: p.firstname,
          lastName: p.lastName,
          gender: p.gender,
          mobileno: p.mobileno,
          empLocCode: p.empLocCode,
          tripType: p.tripType,
          paxOrder: p.paxOrder,
          address: p.address,
          plannedLat: p.plannedLat,
          plannedLng: p.plannedLng,
          noShow: p.noShow,
          noShowReasonId: p.noShowReasonId,
          orsDeviation: p.orsDeviation,
          scheduled: p.scheduled,
          paxAdded: p.paxAdded,
          paxType: p.paxType,
          empDistance: p.empDistance,
          empDirectDistance: p.empDirectDistance,
          empCost: p.empCost,
          plannedScheduleTime:
              scheduleChanged ? liveSchedule : p.plannedScheduleTime,
          etaDeviationMinutes:
              deviationChanged ? liveDeviation : p.etaDeviationMinutes,
          empSigninTime: p.empSigninTime,
          empSigninLat: p.empSigninLat,
          empSigninLng: p.empSigninLng,
          empSignOutTime: p.empSignOutTime,
          empSignOutLat: p.empSignOutLat,
          empSignOutLng: p.empSignOutLng,
          cabReachedTime: p.cabReachedTime,
          cabReachedLat: p.cabReachedLat,
          cabReachedLng: p.cabReachedLng,
          reachedHomeTime: p.reachedHomeTime,
          reachedHomeLat: p.reachedHomeLat,
          reachedHomeLng: p.reachedHomeLng,
          paxTrackingStatus: statusChanged ? liveStatus : p.paxTrackingStatus,
        );
      }
      return p;
    }).toList();

    // Always repaint so the live expected-arrival clock stays current, even on
    // ticks where no passenger field changed. Only rebuild the timelines when
    // the underlying data actually changed (avoids needless work every 200 ms).
    if (changed) {
      _latestStatus = status.withPassengers(updated);
      // Keep the cached state in sync so the bottom sheet repaints from the
      // freshest passenger data on this silent tick (no loader, real-time).
      _latestData = _latestData?.copyWith(status: _latestStatus);
      _timeline =
          RideTimeline.fromStatus(_latestStatus!, meEmpId: widget.empId);
      _fullTimeline = RideTimeline.fromStatus(_latestStatus!,
          meEmpId: widget.empId, includeAllStops: true);
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Build the bus marker once MediaQuery is available. Guarded so a later
    // dependency change (theme, metrics) does not redraw it needlessly.
    if (!_busIconRequested) {
      _busIconRequested = true;
      _loadBusIcon();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _statusRefreshTimer?.cancel();
    _moveController.dispose();
    _pulseController.dispose();
    _sheetController.dispose();
    // Clean up the dummy simulator if it was running (testing mode only).
    if (_dummy != null) {
      _dummy!.removeLocationListener(_onSignalRLocation);
      _dummy!.dispose();
      _dummy = null;
    }
    // Clean up SignalR: leave the group and close the connection.
    if (_signalREnabled) {
      final dsId = widget.tripId;
      if (dsId != null) _signalR.leaveTrackingGroup(dsId);
      _signalR.removeLocationListener(_onSignalRLocation);
      _signalR.disconnect();
    }
    super.dispose();
  }

  void _setupFallbackMarkers() {
    _markers
      ..clear()
      ..add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLatLng,
          icon: _busIcon,
          infoWindow: const InfoWindow(title: 'Driver'),
          anchor: _kBusPinAnchor,
        ),
      );
  }

  void _applyStateToMap(RideTrackingDataState data) {
    final status = data.status;

    // Cache for the SignalR ETA computation, which runs outside the bloc.
    _latestStatus = status;
    // Cache the whole state so the bottom sheet reads driver/vehicle from
    // the freshest data on every repaint (incl. the silent 0.2 s tick).
    _latestData = data;

    // Rebuild the personalised timeline (boarding states, current target, my
    // position in the pickup sequence) from the freshest status.
    _timeline = RideTimeline.fromStatus(status, meEmpId: widget.empId);
    _fullTimeline = RideTimeline.fromStatus(status,
        meEmpId: widget.empId, includeAllStops: true);

    // The bloc's planned polyline traces the FULL fleet route (office → every
    // drop). On LOGOUT trips that overshoots the viewer's own drop, and on
    // LOGIN trips it shows the whole route before the viewer boards — both
    // want a personalised route, so don't seed it; the boarding-gated /capped
    // Directions route built below replaces it instead.
    if (_isLogoutTripType() || _isLoginTripType()) {
      _plannedPoints = const [];
    } else {
      _plannedPoints = data.plannedPolylinePoints;
    }

    if (status != null && status.hasLocation && !_signalRHasLocation) {
      final newLatLng = LatLng(status.latestLat!, status.latestLng!);
      // Only snap position on initial REST load — SignalR uses animated path.
      if (_animatedDriverLatLng == _fallbackCenter) {
        _animatedDriverLatLng = newLatLng;
      }
      // Seed the ETA from the REST status so a value shows before the first
      // SignalR push; subsequent SignalR updates keep it live. notify:false —
      // _applyStateToMap flushes its own setState below.
      _updateEta(
        driver: newLatLng,
        speedKmh: status.latestSpeed,
        notify: false,
      );
      _driverLatLng = newLatLng;
    }

    _initialCamera =
        CameraPosition(target: _animatedDriverLatLng, zoom: _followZoom);

    _markers.clear();

    // Stop markers, coloured by their live state (completed=green,
    // current=orange, upcoming=blue, no-show=red, office=purple). Only the
    // stops relevant to this passenger's view are rendered.
    _rebuildStopMarkers();

    // Bus marker — animated position. Not heading-rotated: the art is a pin.
    _markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: _animatedDriverLatLng,
        icon: _busIcon,
        anchor: _kBusPinAnchor,
        zIndexInt: 1,
        infoWindow: InfoWindow(
          title: status?.driverName ?? data.detail?.driverName ?? 'Driver',
          snippet: status?.trackingMessage ?? 'Your shuttle is on the way',
        ),
      ),
    );

    // Gray completed route + orange active shuttle→stop leg (Directions).
    _rebuildRoutePolylines(_plannedPoints);

    setState(() {});

    final tripId = status?.dsId ?? widget.tripId;
    if (tripId != null) {
      unawaited(_loadGpsRoutePolylines(tripId));
    } else if (_plannedPoints.length < 2) {
      unawaited(_applyDirectionsPlannedRoute());
    } else {
      unawaited(_refreshActiveLegPolyline());
    }

    // Camera: fit the whole trip ONCE (shuttle + stops + office), then leave it
    // fixed. Live GPS updates afterwards never move the camera — they only
    // animate the marker — so the background stays steady (Ola/Uber feel).
    _fitToTrackingBounds();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CabTrackingBloc, CabTrackingState>(
      listener: (context, state) {
        if (state is RideTrackingDataState) {
          _applyStateToMap(state);
          // Connect SignalR on first successful data load if server requests it.
          if (state.status != null) _connectSignalR(state.status!);
        } else if (state is CabTrackingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        // Prefer the cached _latestData: it carries the freshest SignalR/tick
        // merges (driver/vehicle + live stop status), so the sheet
        // refreshes in real time on every repaint — not just on bloc emits.
        // Fall back to the bloc state, then the dummy seed (dummy mode).
        final data = _latestData ??
            (state is RideTrackingDataState ? state : _dummyData);
        final isLoading = data == null &&
            (state is CabTrackingLoading || state is CabTrackingInitial);

        return Scaffold(
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: _initialCamera,
                style: _kMapStyle,
                onMapCreated: (controller) {
                  if (!_mapController.isCompleted) {
                    _mapController.complete(controller);
                  }
                  if (data != null) _applyStateToMap(data);
                  // Frame the trip once the controller is ready.
                  _fitToTrackingBounds();
                },
                // Track the visible region so we can detect shuttle drift, and clear
                // the in-flight guard once a programmatic move settles.
                onCameraIdle: () async {
                  if (!_mapController.isCompleted) return;
                  final ctrl = await _mapController.future;
                  _visibleBounds = await ctrl.getVisibleRegion();
                  _cameraMoveInFlight = false;
                },
                markers: _markers,
                polylines: _polylines,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height * 0.23,
                ),
              ),
              if (isLoading)
                const ColoredBox(
                  color: Color(0x33FFFFFF),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A6B4A)),
                  ),
                ),
              _TopBar(onBack: () => Navigator.of(context).maybePop()),
              _RecenterFab(
                // Tap → recenter on the shuttle. Long-press → re-fit the trip.
                onTap: () => _recenterOnShuttle(zoom: 15.0),
                onLongPress: () => _fitToTrackingBounds(force: true),
              ),
              _buildBottomSheet(data: data, isLoading: isLoading),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheet({
    required RideTrackingDataState? data,
    required bool isLoading,
  }) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.27,
      minChildSize: 0.27,
      maxChildSize: 0.55,
      snap: true,
      snapSizes: const [0.27, 0.55],
      builder: (context, scrollController) {
        // Rebuilt per frame so the stop list, its states and its ETAs stay in
        // step with the live feed (SignalR pushes + the silent 200 ms tick).
        final stops = _shuttleStops;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 14,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 8),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // No OTP card on a shuttle — boarding is by stop/QR, so
                      // there is no per-rider PIN to show here.

                      // Next-stop banner — the shuttle's current target stop
                      // and when it gets there.
                      if (!isLoading && stops.isNotEmpty) ...[
                        _ShuttleStatusBanner(
                          stops: stops,
                          isLogout: _fullTimeline.isLogout,
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Driver card
                      _DriverCard(
                        driverName: data?.status?.driverName ??
                            data?.detail?.driverName,
                        vehicleNo: data?.status?.vehicleNo ??
                            data?.detail?.vehicleRegistrationNo,
                        driverMobileNo: data?.status?.driverMobileNo,
                        dsId: data?.status?.dsId ?? widget.tripId,
                        empId: widget.empId,
                        isLoading: isLoading,
                        gateIvrCall: widget.gateIvrCall,
                      ),

                      // Expanded section — the shuttle's stop list. No
                      // passenger list and no rider count: a shuttle rider sees
                      // the route, not who else is on it.
                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOut,
                        child: _isExpanded
                            ? _ExpandedSection(
                                data: data,
                                stops: stops,
                                userName: widget.userName,
                                tripId: widget.tripId,
                                empId: widget.empId,
                                // Shuttle trips (TransportType == 2) never show
                                // the group chat entry.
                                gateChat: widget.gateChat &&
                                    !widget.isShuttleTransport,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _CircleButton(
                onTap: onBack,
                child: const Icon(Icons.arrow_back,
                    color: Color(0xFF1A6B4A), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Shuttle Tracking',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A6B4A),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Recenter FAB ─────────────────────────────────────────────────────────────

class _RecenterFab extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _RecenterFab({required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: MediaQuery.of(context).size.height * 0.26,
      child: _CircleButton(
        onTap: onTap,
        onLongPress: onLongPress,
        child: const Icon(Icons.my_location_rounded,
            color: Color(0xFF1A6B4A), size: 20),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _CircleButton({
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ─── Driver card ──────────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  final String? driverName;
  final String? vehicleNo;
  final String? driverMobileNo;
  final int? dsId;
  final int? empId;
  final bool isLoading;
  // UserAppConfiguration highest-priority gate for the IVR Call button.
  final bool gateIvrCall;

  const _DriverCard({
    this.driverName,
    this.vehicleNo,
    this.driverMobileNo,
    this.dsId,
    this.empId,
    this.isLoading = false,
    this.gateIvrCall = true,
  });

  Future<void> _onCallPressed(BuildContext context) async {
    final phone = driverMobileNo?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver phone number not available')),
      );
      return;
    }

    if (dsId == null || empId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start call')),
      );
      return;
    }

    // Show a blocking loader while the IVR call is being initiated.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? virtualNumber;
    try {
      final response = await sl<IvrCallRepo>().initiate(
        dsId: dsId!,
        empId: empId!,
        phoneNo: phone,
        callerType: 'E',
      );
      virtualNumber = response.ivrVirtualNumber?.trim();
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(ErrorMessage.from(e, fallback: 'Unable to start call')),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loader

    if (virtualNumber == null || virtualNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start call')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: virtualNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to start call')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = isLoading ? 'Loading…' : (driverName ?? '—');
    final plate = vehicleNo?.trim();
    final canCall = !isLoading && driverMobileNo?.trim().isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          ClipOval(
            child: Container(
              width: 46,
              height: 46,
              color: Colors.grey.shade200,
              child: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF1A6B4A),
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Driver',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                if (plate != null && plate.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    plate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // UserAppConfiguration highest-priority gate: hide the IVR Call button
          // entirely when isTripIvrCallAllowed is `false`.
          if (gateIvrCall)
            ElevatedButton.icon(
              onPressed: canCall ? () => _onCallPressed(context) : null,
              icon: const Icon(Icons.phone_rounded, size: 16),
              label: const Text('Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A6B4A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Expanded section ─────────────────────────────────────────────────────────

class _ExpandedSection extends StatelessWidget {
  final RideTrackingDataState? data;

  /// The shuttle's route as place-level stops. This is the ONLY route content
  /// the sheet renders — there is deliberately no passenger list and no rider
  /// count, since a shuttle rider is shown the line, not who is on it.
  final List<_ShuttleStop> stops;

  final String? userName;
  final int? tripId;
  final int? empId;
  // UserAppConfiguration highest-priority gate for the Chat button.
  final bool gateChat;

  const _ExpandedSection({
    this.data,
    required this.stops,
    this.userName,
    this.tripId,
    this.empId,
    this.gateChat = true,
  });

  void _openTripGroupChat(BuildContext context) {
    final id = tripId;
    if (id == null || id == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip ID is not available.')),
      );
      return;
    }

    final name = userName?.trim() ?? '';
    final participants = name.isNotEmpty ? name : 'Trip passengers';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripGroupChatScreen(
          tripId: id,
          myEmpId: empId ?? 0,
          otherEmpId: 373,
          otherName: 'Trip Group Chat',
          participants: participants,
          myName: name.isNotEmpty ? name : 'You',
          passengers: data?.status?.passengers ?? const [],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = data?.detail;
    final status = data?.status;

    final vehicle = (status?.vehicleNo?.trim().isNotEmpty == true
            ? status!.vehicleNo!.trim()
            : detail?.vehicleRegistrationNo?.trim()) ??
        '—';

    // Stops already served vs. the total on the line — a route-level progress
    // figure, with no reference to riders.
    final servedCount =
        stops.where((s) => s.state == StopState.completed).length;
    final totalStops = stops.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 12),

        // Shuttle vehicle number.
        Row(
          children: [
            const Icon(Icons.directions_bus_rounded,
                size: 18, color: Color(0xFF1A6B4A)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                vehicle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 12),

        // Route header — stops served out of the total on this shuttle line.
        Row(
          children: [
            const Icon(Icons.route_rounded, size: 18, color: Color(0xFF1A6B4A)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Shuttle stops',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            if (totalStops > 0)
              Text(
                '$servedCount/$totalStops covered',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),

        // The stop list itself — always shown while the sheet is expanded (no
        // toggle: the stops ARE the content of a shuttle sheet).
        if (stops.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ShuttleStopsList(stops: stops),
        ],

        // UserAppConfiguration highest-priority gate: hide the Chat entry
        // ("Need Shuttle Update?") entirely when isTripChatAllowed is `false`.
        if (gateChat) ...[
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 12),

          // Need Shuttle Update row
          GestureDetector(
            onTap: () => _openTripGroupChat(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded,
                          size: 22, color: Color(0xFF1A6B4A)),
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need Shuttle Update?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Chat with your group',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Color(0xFFAAAAAA), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

// ─── Shuttle status banner ──────────────────────────────────────────────────

/// Compact banner at the top of the sheet: where the shuttle is heading next
/// and when it gets there.
///
/// Framed entirely around the ROUTE — `Next stop · <place>` — never around a
/// rider's boarding state, so it says nothing about who is or isn't on board.
class _ShuttleStatusBanner extends StatelessWidget {
  final List<_ShuttleStop> stops;
  final bool isLogout;

  const _ShuttleStatusBanner({required this.stops, required this.isLogout});

  @override
  Widget build(BuildContext context) {
    // The stop the shuttle is heading to, else the first one still ahead.
    _ShuttleStop? next;
    for (final s in stops) {
      if (s.state == StopState.current) {
        next = s;
        break;
      }
    }
    next ??= stops.cast<_ShuttleStop?>().firstWhere(
          (s) => s!.state == StopState.upcoming,
          orElse: () => null,
        );

    // Every stop served → the run is finished.
    final finished = next == null;
    final myStop = stops.cast<_ShuttleStop?>().firstWhere(
          (s) => s!.isMine,
          orElse: () => null,
        );

    final Color color =
        finished ? const Color(0xFF1A6B4A) : const Color(0xFFF59E0B);
    final IconData icon =
        finished ? Icons.check_circle_rounded : Icons.directions_bus_rounded;

    final String title;
    final String subtitle;
    if (finished) {
      title = 'Shuttle run complete';
      subtitle = isLogout
          ? 'All stops covered — hope you had a good ride'
          : 'All stops covered';
    } else {
      title = 'Next stop · ${next.name}';
      // Position the rider's own stop within the line without naming anyone:
      // count how many stops the shuttle still has before reaching it.
      if (myStop != null && myStop.state != StopState.completed) {
        final before = _stopsBefore(myStop);
        subtitle = before == 0
            ? 'Your stop is next'
            : '$before stop${before == 1 ? '' : 's'} before yours';
      } else if (myStop != null) {
        subtitle = isLogout ? 'You have reached your stop' : "You're on board";
      } else {
        subtitle = 'Shuttle is on the way';
      }
    }

    // ETA strip: prefer the live countdown to the next stop, fall back to its
    // scheduled arrival clock.
    final etaText = next?.etaLabel;

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (etaText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(color: Color(0xFF1A6B4A)),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ETA to next stop',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    etaText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// How many stops the shuttle still has to serve before [target].
  int _stopsBefore(_ShuttleStop target) {
    var count = 0;
    for (final s in stops) {
      if (identical(s, target)) break;
      if (s.state != StopState.completed) count++;
    }
    return count;
  }
}

// ─── Shuttle stops list ─────────────────────────────────────────────────────

/// Vertical list of the shuttle's stops, in route order, with each stop's ETA.
///
/// This is the sheet's route view and the ONLY list on the screen. Every row is
/// a place — "Stop 3 · MG Road" — so no passenger name, count, or boarding
/// state of another rider can appear here.
class _ShuttleStopsList extends StatelessWidget {
  final List<_ShuttleStop> stops;

  const _ShuttleStopsList({required this.stops});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < stops.length; i++)
          _ShuttleStopRow(
            // Stable identity per stop so a row dropping out of the list can't
            // slide the next stop's ETA onto the previous row mid-animation.
            key: ValueKey(
              stops[i].isOffice ? 'office' : 'stop-${stops[i].index}',
            ),
            stop: stops[i],
            isLast: i == stops.length - 1,
          ),
      ],
    );
  }
}

/// One stop row: node + connector on the left, place name and ETA on the right.
class _ShuttleStopRow extends StatelessWidget {
  final _ShuttleStop stop;
  final bool isLast;

  const _ShuttleStopRow({super.key, required this.stop, required this.isLast});

  /// Row accent colour, mirroring the map marker hues.
  Color get _color {
    if (stop.isOffice) return const Color(0xFF7C3AED); // purple
    switch (stop.state) {
      case StopState.completed:
        return const Color(0xFF1A6B4A); // green
      case StopState.current:
        return const Color(0xFFF59E0B); // orange
      case StopState.upcoming:
      case StopState.noShow:
        return const Color(0xFF2563EB); // blue
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final done = stop.state == StopState.completed;
    final current = stop.state == StopState.current;
    final eta = stop.etaLabel;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node + connector down to the next stop.
          Column(
            children: [
              _ShuttleStopNode(stop: stop, color: color),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: done ? color : const Color(0xFFE0E0E0),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stop.isMine ? '${stop.name} (Your stop)' : stop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: (stop.isMine || current)
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // Time for THIS stop, beside its name — the live countdown
                      // when the shuttle is heading here, its scheduled arrival
                      // while it is still ahead, and on the rider's own stop the
                      // clock they were actually picked up at once boarded.
                      if (eta != null) ...[
                        const SizedBox(width: 8),
                        _ShuttleEtaChip(
                          label: eta,
                          color: color,
                          isBoarded: stop.boardedClock != null,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stop.sequenceLabel} · ${stop.statusLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The circular node on the stops list — colour reflects the stop state, and
/// the circle carries the stop's number so a rider can match a row to the
/// "Stop 3" sequence label and to the numbered map markers.
///
/// The number gives way to a glyph only where one says more than a digit: the
/// office terminus (a building, since it has no stop number) and the stop the
/// shuttle is currently driving to (a bus, which is what makes that one row
/// findable at a glance).
class _ShuttleStopNode extends StatelessWidget {
  final _ShuttleStop stop;
  final Color color;

  const _ShuttleStopNode({required this.stop, required this.color});

  @override
  Widget build(BuildContext context) {
    final IconData? icon;
    final bool filled;
    if (stop.isOffice) {
      icon = Icons.business_rounded;
      filled = true;
    } else {
      switch (stop.state) {
        case StopState.completed:
          icon = null;
          filled = true;
          break;
        case StopState.current:
          icon = Icons.directions_bus_rounded;
          filled = true;
          break;
        case StopState.upcoming:
        case StopState.noShow:
          icon = null;
          filled = false;
          break;
      }
    }

    final Color foreground = filled ? Colors.white : color;

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.white,
        border: Border.all(color: color, width: 2),
      ),
      child: icon != null
          ? Icon(icon, size: 18, color: foreground)
          : Text(
              '${stop.index}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: foreground,
                height: 1,
              ),
            ),
    );
  }
}

/// Small ETA chip on a stop row (e.g. `5 min`, `8:45 AM`).
///
/// The screen calls `setState` on every SignalR push and on the silent 200 ms
/// tick, so this subtree would otherwise rebuild ~5×/s and visibly flicker.
/// `Widget.==` is `@nonVirtual`, so a StatelessWidget can't opt out. Instead the
/// label is pushed into a [ValueNotifier] — which only notifies on a genuine
/// change — and the chip is built inside a [ValueListenableBuilder]. A tick
/// carrying an unchanged ETA never rebuilds it; a new ETA paints immediately.
///
/// The [RepaintBoundary] keeps the chip on its own layer, so a repaint of a
/// neighbouring row never re-rasterises these pixels.
class _ShuttleEtaChip extends StatefulWidget {
  final String label;
  final Color color;

  /// True when [label] is a pickup that already happened rather than an
  /// arrival still to come — swaps the clock glyph for a tick.
  final bool isBoarded;

  const _ShuttleEtaChip({
    required this.label,
    required this.color,
    this.isBoarded = false,
  });

  @override
  State<_ShuttleEtaChip> createState() => _ShuttleEtaChipState();
}

class _ShuttleEtaChipState extends State<_ShuttleEtaChip> {
  late final ValueNotifier<String> _label = ValueNotifier(widget.label);

  @override
  void didUpdateWidget(covariant _ShuttleEtaChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Assigning an equal String is a no-op for ValueNotifier, so ticks that
    // carry no ETA change never notify — the chip holds steady.
    _label.value = widget.label;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<String>(
        valueListenable: _label,
        builder: (context, label, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isBoarded
                      ? Icons.check_circle_rounded
                      : Icons.access_time_rounded,
                  size: 12,
                  color: widget.color,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.color,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Expected arrival clock time = planned schedule time + ETA deviation,
/// formatted as a 12-hour AM/PM string (e.g. `8:45 AM`).
///
/// [plannedScheduleTime] may be a full ISO datetime (`2026-06-08T08:30:00`) or
/// a bare time string (`08:30`, `8:30 AM`). Returns null when it can't be
/// parsed, so callers can fall back to the duration ETA.
String? formatPlannedArrivalClock(String? plannedScheduleTime, int? deviation) {
  final raw = plannedScheduleTime?.trim();
  if (raw == null || raw.isEmpty) return null;

  DateTime? parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    // Bare time string fallback: "8:30 AM", "08:30", "8:30:00".
    final m = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp][Mm])?$')
        .firstMatch(raw);
    if (m == null) return null;
    var hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final ampm = m.group(3)?.toUpperCase();
    if (ampm == 'PM' && hour != 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    parsed = DateTime(2000, 1, 1, hour, minute);
  }

  final arrival = parsed.add(Duration(minutes: deviation ?? 0));
  final hour24 = arrival.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = arrival.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

/// Formats a boarding/alighting timestamp (`empSigninTime`) as a `8:32 AM`
/// clock, matching the shape used by every other time on this screen.
///
/// Accepts the same inputs as [formatPlannedArrivalClock] — a full ISO datetime
/// or a bare time string — since the backend is inconsistent between the two.
/// Returns null when absent or unparseable, so callers simply omit the row.
String? formatBoardedClock(String? rawTime) =>
    formatPlannedArrivalClock(rawTime, 0);

/// Formats minutes into a compact ETA label (e.g. `5 min`, `1 h 10 min`).
String formatEta(int? minutes) {
  if (minutes == null) return '—';
  if (minutes <= 0) return 'Arriving';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// Formats a wall-clock [time] as `8:45 AM`.
///
/// Shares its output shape with [formatPlannedArrivalClock] so a live ETA and a
/// scheduled arrival are indistinguishable on the stop rows.
String formatClockTime(DateTime time) {
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

/// Converts a live "minutes from now" ETA into an arrival clock (`8:45 AM`).
///
/// The stop rows otherwise mix formats: scheduled stops read as a clock while
/// the active stop counted down as a duration (`1 h 10 min`). Rendering the
/// countdown as its arrival time keeps one format down the whole timetable.
/// Returns null when [minutes] is unknown so callers can fall back.
String? formatEtaAsClock(int? minutes, {DateTime? now}) {
  if (minutes == null) return null;
  final base = now ?? DateTime.now();
  return formatClockTime(base.add(Duration(minutes: minutes)));
}

// ─── Map style ────────────────────────────────────────────────────────────────

const String _kMapStyle = '''
[
  { "featureType": "administrative", "elementType": "labels", "stylers": [{ "visibility": "off" }] },
  { "featureType": "landscape", "elementType": "all", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.attraction", "elementType": "labels", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.business", "elementType": "all", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.business", "elementType": "labels", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.business", "elementType": "labels.icon", "stylers": [{ "visibility": "off" }] },
  { "featureType": "poi.government", "elementType": "labels", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.school", "elementType": "all", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.school", "elementType": "labels", "stylers": [{ "visibility": "off" }] },
  { "featureType": "road", "elementType": "all", "stylers": [{ "visibility": "on" }] },
  { "featureType": "road", "elementType": "labels", "stylers": [{ "visibility": "off" }] }
]
''';
