import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../features/trip_detail/data/model/cab_tracking/user_cab_tracking_response.dart';

/// Lifecycle state of a single stop (pickup or office) on the route.
///
/// Drives both the timeline UI and the marker colours. Ordering matters: every
/// stop before the cab's current target is [completed] (or [noShow]); exactly
/// one upcoming pickup is the [current] target; the rest are [upcoming]; the
/// office is [completed] only once the trip ends.
enum StopState {
  /// Pickup already serviced — passenger boarded, or office reached.
  completed,

  /// The stop the cab is actively heading to right now.
  current,

  /// A stop the cab will reach later.
  upcoming,

  /// Pickup the driver skipped (passenger never showed).
  noShow,
}

/// Kind of stop on the route — a passenger stop (pickup/drop) or the office.
enum StopKind { pickup, office }

/// Direction of the shift, derived from `tripType`:
///   * [login]  (tripType 1) → home pickups then office. Office is the
///     destination at the END. Stops are "Pickup N".
///   * [logout] (tripType 2) → office then home drops. Office is the ORIGIN at
///     the START (cab leaves from there). Stops are "Drop N".
enum TripDirection { login, logout }

TripDirection tripDirectionFrom(int? tripType) =>
    tripType == 2 ? TripDirection.logout : TripDirection.login;

/// Route progress for one passenger, derived from [TripPassenger.paxTrackingStatus].
enum PaxRoutePhase {
  /// Pending / Not Picked Up / Not Boarded — cab still needs to reach this stop.
  pending,

  /// In Cab (drop trips) — cab is driving this passenger to their drop point.
  inProgress,

  /// Picked Up / Dropped / Completed — stop is finished.
  done,

  /// No Show — skipped.
  noShow,
}

/// Parses live [paxTrackingStatus] into a [PaxRoutePhase].
/// Returns null when the string is absent so callers can fall back to timestamps.
PaxRoutePhase? paxRoutePhaseFromStatus(
  String? status, {
  required bool isPickupTrip,
}) {
  final s = (status ?? '').trim().toLowerCase();
  if (s.isEmpty) return null;

  if (s == 'no show') return PaxRoutePhase.noShow;
  if (s == 'pending') return PaxRoutePhase.pending;

  if (isPickupTrip) {
    if (s == 'picked up' || s == 'completed') return PaxRoutePhase.done;
    if (s == 'not picked up') return PaxRoutePhase.pending;
  } else {
    if (s == 'dropped' || s == 'completed') return PaxRoutePhase.done;
    if (s == 'in cab') return PaxRoutePhase.inProgress;
    if (s == 'not boarded') return PaxRoutePhase.pending;
  }

  if (s == 'completed') return PaxRoutePhase.done;
  return null;
}

/// Resolves the effective route phase for [p], preferring [paxTrackingStatus] and
/// falling back to boarding / drop timestamps when the server omits a status.
PaxRoutePhase paxRoutePhaseFor(
  TripPassenger p, {
  required bool isPickupTrip,
}) {
  final fromStatus = paxRoutePhaseFromStatus(
    p.paxTrackingStatus,
    isPickupTrip: isPickupTrip,
  );
  if (fromStatus != null) return fromStatus;

  if (p.isNoShow) return PaxRoutePhase.noShow;
  if (isPickupTrip) {
    return p.isBoarded ? PaxRoutePhase.done : PaxRoutePhase.pending;
  }
  if (p.isDropped) return PaxRoutePhase.done;
  if (p.isBoarded) return PaxRoutePhase.inProgress;
  return PaxRoutePhase.pending;
}

bool isPaxRouteResolved(TripPassenger p, {required bool isPickupTrip}) {
  final phase = paxRoutePhaseFor(p, isPickupTrip: isPickupTrip);
  return phase == PaxRoutePhase.done || phase == PaxRoutePhase.noShow;
}

bool isPaxRouteTarget(TripPassenger p, {required bool isPickupTrip}) {
  final phase = paxRoutePhaseFor(p, isPickupTrip: isPickupTrip);
  return phase == PaxRoutePhase.pending || phase == PaxRoutePhase.inProgress;
}

/// Whether the orange active leg should be hidden for this passenger.
bool shouldHideActiveLegForPassenger(
  TripPassenger p, {
  required bool isPickupTrip,
}) {
  final s = (p.paxTrackingStatus ?? '').trim().toLowerCase();
  if (s == 'no show') return true;
  if (isPickupTrip) {
    return s == 'completed';
  }
  return s == 'dropped' || s == 'completed';
}

/// First fleet-wide passenger stop that needs an active leg (route order).
bool isPaxFleetActiveLegCandidate(
  TripPassenger p, {
  required bool isPickupTrip,
}) {
  if (shouldHideActiveLegForPassenger(p, isPickupTrip: isPickupTrip)) {
    return false;
  }
  if (isPaxRouteResolved(p, isPickupTrip: isPickupTrip)) {
    // Picked Up on pickup trips may still need cab → office.
    final s = (p.paxTrackingStatus ?? '').trim().toLowerCase();
    if (isPickupTrip && s == 'picked up') return false;
    if (!isPickupTrip) return false;
  }
  return isPaxRouteTarget(p, isPickupTrip: isPickupTrip);
}

/// True when [p] has been picked up but the pickup trip is not yet completed.
bool isPickedUpEnRouteToOffice(TripPassenger p) {
  final s = (p.paxTrackingStatus ?? '').trim().toLowerCase();
  if (s == 'picked up') return true;
  return p.isBoarded &&
      s != 'completed' &&
      (p.paxTrackingStatus == null || p.paxTrackingStatus!.trim().isEmpty);
}

StopState stopStateFromPhase(PaxRoutePhase phase, {required bool isTarget}) {
  switch (phase) {
    case PaxRoutePhase.noShow:
      return StopState.noShow;
    case PaxRoutePhase.done:
      return StopState.completed;
    case PaxRoutePhase.inProgress:
      return isTarget ? StopState.current : StopState.upcoming;
    case PaxRoutePhase.pending:
      return isTarget ? StopState.current : StopState.upcoming;
  }
}

/// One node on the personalised tracking timeline.
class RideStop {
  final StopKind kind;
  final StopState state;

  /// 1-based pickup order (`paxOrder`). Null for the office stop.
  final int? order;

  final String title;
  final String? subtitle;
  final LatLng? location;

  /// True when this pickup is the logged-in user ("me").
  final bool isMe;

  /// Boarding flag straight off [TripPassenger.isBoarded]. Always false for the
  /// office stop.
  final bool isBoarded;

  /// Scheduled time string for a pickup, or expected-arrival label for office.
  final String? timeLabel;

  /// Raw server-planned schedule time for this passenger
  /// (`TripPassenger.plannedScheduleTime`). Combined with [etaDeviationMinutes]
  /// to compute the live expected arrival clock time. Null for the office stop.
  final String? plannedScheduleTime;

  /// Live ETA deviation (minutes) off the planned schedule, server-provided
  /// (`TripPassenger.etaDeviationMinutes`). Added to [plannedScheduleTime].
  final int? etaDeviationMinutes;

  /// True when this is a logout/drop stop (affects labels: "Drop" vs "Pickup",
  /// "Dropped" vs "Boarded"). Always false for the office stop.
  final bool isDrop;

  /// Server-provided live tracking status for this passenger
  /// (`RouteTripPassenger.paxTrackingStatus`), shown verbatim on the timeline
  /// status pill when present. Null for the office stop or when the backend
  /// hasn't supplied one, in which case the derived [StopState] label is used.
  final String? paxTrackingStatus;

  const RideStop({
    required this.kind,
    required this.state,
    required this.title,
    this.order,
    this.subtitle,
    this.location,
    this.isMe = false,
    this.isBoarded = false,
    this.timeLabel,
    this.isDrop = false,
    this.paxTrackingStatus,
    this.plannedScheduleTime,
    this.etaDeviationMinutes,
  });

  bool get isOffice => kind == StopKind.office;
  bool get isPickup => kind == StopKind.pickup;

  /// Sequence label — "Pickup 2" (login) or "Drop 2" (logout).
  String get sequenceLabel {
    final n = order ?? 0;
    return isDrop ? 'Drop $n' : 'Pickup $n';
  }
}

/// The personalised, ordered set of stops a passenger should see, plus the
/// route-segmentation indices used to colour the polyline.
///
/// The route shape depends on [TripDirection] (from `tripType`):
///
///   * LOGIN  (tripType 1): Cab → Pickup1 → Pickup2 → … → **Office** (tail).
///       Not boarded → Cab → (pickups up to & including ME).
///       Boarded     → Cab → (remaining pickups after ME) → Office.
///
///   * LOGOUT (tripType 2): Cab leaves **Office** (head) → Drop1 → Drop2 → …
///       Not dropped → Cab → (drops up to & including MY drop).
///       Dropped     → (timeline collapses; I've reached home).
class RideTimeline {
  /// All stops in route order, already filtered to the passenger's view.
  final List<RideStop> stops;

  /// The cab's current target stop, or null when every stop is done.
  final RideStop? target;

  /// Login: true once the logged-in user has boarded.
  /// Logout: true once the logged-in user has been dropped home.
  final bool meBoarded;

  /// Number of stops still ahead of ME before the cab reaches my stop
  /// (0 once I'm the target / boarded / dropped). "N stops before you".
  final int stopsBeforeMe;

  /// Login vs logout — drives labelling (Pickup/Drop) and office placement.
  final TripDirection direction;

  const RideTimeline({
    required this.stops,
    required this.target,
    required this.meBoarded,
    required this.stopsBeforeMe,
    this.direction = TripDirection.login,
  });

  bool get isLogout => direction == TripDirection.logout;

  static const RideTimeline empty = RideTimeline(
    stops: [],
    target: null,
    meBoarded: false,
    stopsBeforeMe: 0,
  );

  /// Builds the personalised timeline from the live status passengers.
  ///
  /// [meEmpId] identifies the logged-in passenger. The trip direction is read
  /// from `status.tripType` (falling back to the first passenger's `tripType`):
  /// `2` → logout/drop, anything else → login/pickup.
  ///
  /// Stop states and the cab's active target are driven primarily by each
  /// passenger's [TripPassenger.paxTrackingStatus] (Pickup: Pending / Not Picked
  /// Up / Picked Up / Completed / No Show; Drop: Pending / Not Boarded / In Cab /
  /// Dropped / No Show). When a status string is absent the builder falls back
  /// to boarding / drop timestamps (`empSigninTime`, `reachedHomeTime`, etc.).
  factory RideTimeline.fromStatus(
    TrackingStatusResponse? status, {
    int? meEmpId,
    bool includeAllStops = false,
  }) {
    if (status == null) return RideTimeline.empty;

    final direction = tripDirectionFrom(
      status.tripType ?? status.tripTypeCode ?? _firstTripType(status),
    );
    final isLogout = direction == TripDirection.logout;

    // Sort stops by their planned order.
    final pax = List<TripPassenger>.from(status.passengers)
      ..sort((a, b) => (a.paxOrder ?? 0).compareTo(b.paxOrder ?? 0));

    final isPickupTrip = !isLogout;

    int? meIndex;
    int? fleetTargetIndex; // first active-leg candidate in route order
    for (var i = 0; i < pax.length; i++) {
      final p = pax[i];
      if (meEmpId != null && p.empId == meEmpId) meIndex = i;
      if (fleetTargetIndex == null &&
          isPaxFleetActiveLegCandidate(p, isPickupTrip: isPickupTrip)) {
        fleetTargetIndex = i;
      }
    }

    final meDone = meIndex != null &&
        isPaxRouteResolved(pax[meIndex], isPickupTrip: isPickupTrip) &&
        paxRoutePhaseFor(pax[meIndex], isPickupTrip: isPickupTrip) !=
            PaxRoutePhase.noShow;

    final officeLocation =
        (status.officeLat != null && status.officeLng != null)
            ? LatLng(status.officeLat!, status.officeLng!)
            : null;
    final officeName = (status.officeDisplayName?.trim().isNotEmpty == true)
        ? status.officeDisplayName!.trim()
        : (status.officeLocName?.trim().isNotEmpty == true
            ? status.officeLocName!.trim()
            : 'Office');

    final List<RideStop> stops = [];

    // Personalised active-leg flags for the logged-in passenger.
    var meIsPickupTarget = false;
    var meIsDropTarget = false;
    var meNeedsOfficeBoarding = false;
    var meHeadingToOffice = false;
    if (meIndex != null) {
      final mePax = pax[meIndex];
      if (!shouldHideActiveLegForPassenger(mePax, isPickupTrip: isPickupTrip)) {
        final mePhase = paxRoutePhaseFor(mePax, isPickupTrip: isPickupTrip);
        if (isPickupTrip) {
          if (mePhase == PaxRoutePhase.pending) meIsPickupTarget = true;
          if (isPickedUpEnRouteToOffice(mePax)) meHeadingToOffice = true;
        } else {
          if (mePhase == PaxRoutePhase.pending) meNeedsOfficeBoarding = true;
          if (mePhase == PaxRoutePhase.inProgress) meIsDropTarget = true;
        }
      }
    }

    // LOGOUT: office is the ORIGIN. Current target when I'm Not Boarded.
    RideStop? officeStop;
    if (isLogout && (officeLocation != null || meIndex == null)) {
      final meNeedsOfficeBoardingForStop = meIndex == null
          ? fleetTargetIndex != null &&
              paxRoutePhaseFor(pax[fleetTargetIndex], isPickupTrip: false) ==
                  PaxRoutePhase.pending
          : meNeedsOfficeBoarding;
      officeStop = RideStop(
        kind: StopKind.office,
        state: meNeedsOfficeBoardingForStop
            ? StopState.current
            : StopState.completed,
        title: officeName,
        subtitle: status.officeAddress,
        location: officeLocation,
        timeLabel: 'Started here',
      );
      stops.add(officeStop);
    }

    for (var i = 0; i < pax.length; i++) {
      final p = pax[i];

      // Visibility — same personalisation rule for both directions, keyed on
      // whether MY own stop is done yet:
      //   not done → stops up to & including mine
      //   done     → remaining unresolved stops after mine (login only keeps
      //              showing them en route to office; logout has none left).
      final bool visible;
      if (includeAllStops) {
        visible = true; // full passenger list view — show everyone
      } else if (meIndex == null) {
        visible = true; // no identity → full route
      } else if (!meDone) {
        visible = i <= meIndex;
      } else {
        visible = i > meIndex &&
            !isPaxRouteResolved(p, isPickupTrip: isPickupTrip);
      }
      if (!visible) continue;

      final phase = paxRoutePhaseFor(p, isPickupTrip: isPickupTrip);
      final isFleetTarget = i == fleetTargetIndex;
      final isMeActiveTarget =
          meIndex != null && i == meIndex && (meIsPickupTarget || meIsDropTarget);
      final st = stopStateFromPhase(
        phase,
        isTarget: isMeActiveTarget || (meIndex == null && isFleetTarget),
      );

      final name = p.fullName.isNotEmpty ? p.fullName : 'Passenger';
      final doneTime = isLogout
          ? (p.reachedHomeTime ?? p.cabReachedTime)
          : p.empSigninTime;
      final boarded = phase == PaxRoutePhase.done ||
          phase == PaxRoutePhase.inProgress ||
          (phase != PaxRoutePhase.noShow &&
              (isLogout ? p.isDropped : p.isBoarded));
      stops.add(RideStop(
        kind: StopKind.pickup,
        state: st,
        order: p.paxOrder,
        title: name,
        subtitle: p.address,
        location: p.hasPickupLocation
            ? LatLng(p.pickupLat!, p.pickupLng!)
            : null,
        isMe: meIndex != null && i == meIndex,
        isBoarded: boarded,
        isDrop: isLogout,
        timeLabel: doneTime?.trim().isNotEmpty == true
            ? doneTime
            : p.plannedScheduleTime,
        paxTrackingStatus: p.paxTrackingStatus?.trim().isNotEmpty == true
            ? p.paxTrackingStatus!.trim()
            : null,
        plannedScheduleTime: p.plannedScheduleTime,
        etaDeviationMinutes: p.etaDeviationMinutes,
      ));
    }

    // LOGIN: office is the DESTINATION — append once I'm picked up or unidentified.
    final allPickupsResolved = fleetTargetIndex == null &&
        pax.every((p) => isPaxRouteResolved(p, isPickupTrip: true));
    if (!isLogout && (includeAllStops || meDone || meIndex == null)) {
      final officeIsTarget = allPickupsResolved ||
          meHeadingToOffice ||
          (meIndex == null && fleetTargetIndex == null);
      officeStop = RideStop(
        kind: StopKind.office,
        state: status.isCompleted
            ? StopState.completed
            : (officeIsTarget ? StopState.current : StopState.upcoming),
        title: officeName,
        subtitle: status.officeAddress,
        location: officeLocation,
        timeLabel: 'Expected arrival',
      );
      stops.add(officeStop);
    }

    // Active-leg target — personalised for the logged-in passenger when known.
    RideStop? target;
    RideStop? meStop;
    for (final s in stops) {
      if (s.isMe) meStop = s;
    }

    if (meIndex != null) {
      if (isPickupTrip) {
        if (meIsPickupTarget && meStop != null) {
          target = meStop;
        } else if (meHeadingToOffice && officeStop != null) {
          target = officeStop;
        }
      } else {
        if (meNeedsOfficeBoarding && officeStop != null) {
          target = officeStop;
        } else if (meIsDropTarget && meStop != null) {
          target = meStop;
        }
      }
    } else if (fleetTargetIndex != null) {
      final fleetPax = pax[fleetTargetIndex];
      final phase =
          paxRoutePhaseFor(fleetPax, isPickupTrip: isPickupTrip);
      if (phase == PaxRoutePhase.pending && isLogout && officeStop != null) {
        target = officeStop;
      } else {
        for (final s in stops) {
          if (!s.isOffice && s.order == fleetPax.paxOrder) {
            target = s;
            break;
          }
        }
      }
    } else if (allPickupsResolved && officeStop != null && !isLogout) {
      target = officeStop;
    }

    // Stops still ahead of me (only meaningful while I'm en route to my stop).
    var before = 0;
    if (meIndex != null && !meDone && fleetTargetIndex != null) {
      for (var i = fleetTargetIndex; i < meIndex; i++) {
        if (!isPaxRouteResolved(pax[i], isPickupTrip: isPickupTrip)) before++;
      }
    }

    return RideTimeline(
      stops: stops,
      target: target,
      meBoarded: meDone,
      stopsBeforeMe: before,
      direction: direction,
    );
  }

  static int? _firstTripType(TrackingStatusResponse status) {
    for (final p in status.passengers) {
      if (p.tripType != null) return p.tripType;
    }
    return null;
  }
}

/// Marker hue for a stop, per the colour spec:
/// completed=green, current=orange, upcoming=blue, no-show=red, office=purple.
double markerHueForStop(RideStop stop) {
  if (stop.isOffice) return BitmapDescriptor.hueViolet; // purple
  switch (stop.state) {
    case StopState.completed:
      return BitmapDescriptor.hueGreen;
    case StopState.current:
      return BitmapDescriptor.hueOrange;
    case StopState.upcoming:
      return BitmapDescriptor.hueAzure; // blue
    case StopState.noShow:
      return BitmapDescriptor.hueRed;
  }
}

/// Solid colour used for timeline dots / chips (mirrors the marker hues).
Color colorForStop(RideStop stop) {
  if (stop.isOffice) return const Color(0xFF7C3AED); // purple
  switch (stop.state) {
    case StopState.completed:
      return const Color(0xFF1A6B4A); // green
    case StopState.current:
      return const Color(0xFFF59E0B); // orange
    case StopState.upcoming:
      return const Color(0xFF2563EB); // blue
    case StopState.noShow:
      return const Color(0xFFDC2626); // red
  }
}

/// Short status label for a stop's timeline row.
String statusLabelForStop(RideStop stop) {
  if (stop.isOffice) {
    if (stop.state == StopState.completed) {
      return stop.timeLabel == 'Started here' ? 'Start' : 'Reached';
    }
    if (stop.state == StopState.current) return 'En route';
    return 'Destination';
  }
  switch (stop.state) {
    case StopState.completed:
      return stop.isDrop ? 'Dropped' : 'Picked up';
    case StopState.current:
      return stop.isDrop ? 'In cab' : 'Arriving';
    case StopState.upcoming:
      return stop.isDrop ? 'Not boarded' : 'Not picked up';
    case StopState.noShow:
      return 'No show';
  }
}
