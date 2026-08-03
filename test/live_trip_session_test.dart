import 'package:commutr_main/features/trip_detail/data/model/cab_tracking/user_cab_tracking_response.dart';
import 'package:commutr_main/ride_tracking/service/live_trip_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveTripSession', () {
    test('sessions for the same trip are equal', () {
      const a = LiveTripSession(tripId: 1, empId: 2, dsId: 3);
      const b = LiveTripSession(tripId: 1, empId: 2, dsId: 3);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different trip is a different session', () {
      const a = LiveTripSession(tripId: 1, empId: 2, dsId: 3);
      const b = LiveTripSession(tripId: 9, empId: 2, dsId: 3);
      expect(a, isNot(b));
    });

    test('a different dsId is a different session', () {
      // The controller uses inequality to decide whether to clear the previous
      // trip's notification, so dsId must participate in equality.
      const a = LiveTripSession(tripId: 1, empId: 2, dsId: 3);
      const b = LiveTripSession(tripId: 1, empId: 2, dsId: 4);
      expect(a, isNot(b));
    });
  });

  group('TripPassenger.copyWith', () {
    const base = TripPassenger(
      empId: 7,
      firstname: 'Rahul',
      lastName: 'Sharma',
      paxOrder: 2,
      paxTrackingStatus: 'Pending',
      etaDeviationMinutes: 3,
      empSigninTime: null,
      noShow: false,
    );

    test('replaces only the fields given', () {
      final updated = base.copyWith(paxTrackingStatus: 'Picked Up');

      expect(updated.paxTrackingStatus, 'Picked Up');
      // Everything else is preserved.
      expect(updated.empId, 7);
      expect(updated.firstname, 'Rahul');
      expect(updated.lastName, 'Sharma');
      expect(updated.paxOrder, 2);
      expect(updated.etaDeviationMinutes, 3);
    });

    test('omitted fields keep their previous value rather than nulling out', () {
      // This is the semantics the live-tracking merge depends on: a SignalR
      // payload that omits a field must never erase what REST already knew.
      final updated = base.copyWith();

      expect(updated.paxTrackingStatus, 'Pending');
      expect(updated.etaDeviationMinutes, 3);
      expect(updated.firstname, 'Rahul');
    });

    test('a passed null is treated as "keep existing", not "clear"', () {
      final updated = base.copyWith(paxTrackingStatus: null);
      expect(updated.paxTrackingStatus, 'Pending');
    });

    test('can flip boolean flags', () {
      final updated = base.copyWith(noShow: true);
      expect(updated.noShow, isTrue);
      expect(base.noShow, isFalse, reason: 'original must be untouched');
    });

    test('boarding a passenger updates the derived isBoarded getter', () {
      expect(base.isBoarded, isFalse);
      final boarded = base.copyWith(empSigninTime: '2026-08-03T09:14:00');
      expect(boarded.isBoarded, isTrue);
    });

    test('dropping a passenger updates the derived isDropped getter', () {
      expect(base.isDropped, isFalse);
      final dropped = base.copyWith(reachedHomeTime: '2026-08-03T19:40:00');
      expect(dropped.isDropped, isTrue);
    });
  });
}
