import 'package:commutr_main/ride_tracking/model/ride_timeline.dart';
import 'package:commutr_main/ride_tracking/service/live_trip_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a stop with only the fields the notification formatter reads.
RideStop _stop({
  required StopState state,
  bool isMe = false,
  bool isOffice = false,
  int? order,
  String title = 'Pickup',
  String? paxTrackingStatus,
}) {
  return RideStop(
    kind: isOffice ? StopKind.office : StopKind.pickup,
    state: state,
    title: title,
    order: order,
    isMe: isMe,
    paxTrackingStatus: paxTrackingStatus,
  );
}

RideTimeline _timeline({
  required List<RideStop> stops,
  RideStop? target,
  bool meBoarded = false,
  int stopsBeforeMe = 0,
  TripDirection direction = TripDirection.login,
}) {
  return RideTimeline(
    stops: stops,
    target: target,
    meBoarded: meBoarded,
    stopsBeforeMe: stopsBeforeMe,
    direction: direction,
  );
}

void main() {
  group('LiveTripNotificationContent.fromTrackingState', () {
    test('returns null when there are no stops yet', () {
      final content = LiveTripNotificationContent.fromTrackingState(
        timeline: _timeline(stops: const [], target: null),
        etaMinutes: 7,
        tripId: 1,
        empId: 2,
      );
      expect(content, isNull);
    });

    test('counts down to my pickup on a login trip', () {
      final me = _stop(state: StopState.current, isMe: true, order: 1);
      final content = LiveTripNotificationContent.fromTrackingState(
        timeline: _timeline(
          stops: [me, _stop(state: StopState.upcoming, isOffice: true)],
          target: me,
        ),
        etaMinutes: 7,
        tripId: 55,
        empId: 99,
        vehicleNo: 'DL01AB3453',
        driverName: 'Rahul',
      );

      expect(content, isNotNull);
      expect(content!.title, 'Pickup in 7 min');
      expect(content.body, 'DL01AB3453 · Driver: Rahul');
      expect(content.isTerminal, isFalse);
      expect(content.payload, 'live_trip:55:99');
    });

    test('says Drop, not Pickup, on a logout trip', () {
      final me = _stop(state: StopState.current, isMe: true, order: 1);
      final content = LiveTripNotificationContent.fromTrackingState(
        timeline: _timeline(
          stops: [me],
          target: me,
          direction: TripDirection.logout,
        ),
        etaMinutes: 4,
        tripId: 1,
        empId: 2,
      );

      expect(content!.title, 'Drop in 4 min');
    });

    test('reports driver arrival from the live pax status', () {
      final me = _stop(
        state: StopState.current,
        isMe: true,
        order: 1,
        // Deliberately hyphenated + mixed case: the backend is inconsistent
        // about these and the parser must normalise them.
        paxTrackingStatus: 'Cab-Reached',
      );
      final content = LiveTripNotificationContent.fromTrackingState(
        timeline: _timeline(stops: [me], target: me),
        etaMinutes: 0,
        tripId: 1,
        empId: 2,
      );

      expect(content!.title, 'Driver has arrived');
    });

    test('shows how many stops are ahead of me', () {
      final other = _stop(state: StopState.current, order: 1, title: 'Pickup 1');
      final me = _stop(state: StopState.upcoming, isMe: true, order: 2);
      final content = LiveTripNotificationContent.fromTrackingState(
        timeline: _timeline(
          stops: [other, me],
          target: other,
          stopsBeforeMe: 2,
        ),
        etaMinutes: 12,
        tripId: 1,
        empId: 2,
      );

      expect(content!.title, '2 stops before you');
    });

    test('singularises a single stop ahead', () {
      final other = _stop(state: StopState.current, order: 1);
      final me = _stop(state: StopState.upcoming, isMe: true, order: 2);
      final content = LiveTripNotificationContent.fromTrackingState(
        timeline: _timeline(
          stops: [other, me],
          target: other,
          stopsBeforeMe: 1,
        ),
        etaMinutes: 5,
        tripId: 1,
        empId: 2,
      );

      expect(content!.title, '1 stop before you');
    });

    test('switches to the office leg once I have boarded', () {
      final office = _stop(state: StopState.current, isOffice: true);
      final content = LiveTripNotificationContent.fromTrackingState(
        timeline: _timeline(
          stops: [
            _stop(state: StopState.completed, isMe: true, order: 1),
            office,
          ],
          target: office,
          meBoarded: true,
        ),
        etaMinutes: 18,
        tripId: 1,
        empId: 2,
      );

      expect(content!.title, 'Reaching office in 18 min');
    });

    test('is terminal when the backend reports the trip completed', () {
      final me = _stop(state: StopState.current, isMe: true, order: 1);
      final content = LiveTripNotificationContent.fromTrackingState(
        timeline: _timeline(stops: [me], target: me),
        etaMinutes: 3,
        tripId: 1,
        empId: 2,
        tripCompleted: true,
      );

      expect(content!.isTerminal, isTrue);
      expect(content.title, 'Trip completed');
    });

    test('is terminal when every stop is resolved', () {
      final content = LiveTripNotificationContent.fromTrackingState(
        timeline: _timeline(
          stops: [
            _stop(state: StopState.completed, isMe: true, order: 1),
            _stop(state: StopState.completed, isOffice: true),
          ],
          target: null,
        ),
        etaMinutes: null,
        tripId: 1,
        empId: 2,
      );

      expect(content!.isTerminal, isTrue);
    });

    test('degrades gracefully when driver/vehicle are missing', () {
      final me = _stop(state: StopState.current, isMe: true, order: 1);
      final content = LiveTripNotificationContent.fromTrackingState(
        timeline: _timeline(stops: [me], target: me),
        etaMinutes: 6,
        tripId: 1,
        empId: 2,
        vehicleNo: '   ',
        driverName: null,
      );

      expect(content!.body, 'Tap to view live tracking');
    });

    test('falls back to a static headline when the ETA is unknown', () {
      final me = _stop(state: StopState.current, isMe: true, order: 1);
      final content = LiveTripNotificationContent.fromTrackingState(
        timeline: _timeline(stops: [me], target: me),
        etaMinutes: null,
        tripId: 1,
        empId: 2,
      );

      expect(content!.title, 'Pickup scheduled');
    });

    test('avoids "in 0 min" when the cab is seconds away', () {
      final me = _stop(state: StopState.current, isMe: true, order: 1);
      final content = LiveTripNotificationContent.fromTrackingState(
        timeline: _timeline(stops: [me], target: me),
        etaMinutes: 0,
        tripId: 1,
        empId: 2,
      );

      expect(content!.title, 'Pickup in less than a min');
    });

    test('progress and subText track resolved stops', () {
      final me = _stop(state: StopState.current, isMe: true, order: 2);
      final content = LiveTripNotificationContent.fromTrackingState(
        timeline: _timeline(
          stops: [
            _stop(state: StopState.completed, order: 1),
            me,
            _stop(state: StopState.upcoming, isOffice: true),
          ],
          target: me,
        ),
        etaMinutes: 9,
        tripId: 1,
        empId: 2,
      );

      // 1 of 3 stops resolved.
      expect(content!.progressPercent, 33);
      expect(content.subText, 'Stop 2 of 3');
    });

    test('counts a no-show as resolved for progress', () {
      final me = _stop(state: StopState.current, isMe: true, order: 2);
      final content = LiveTripNotificationContent.fromTrackingState(
        timeline: _timeline(
          stops: [_stop(state: StopState.noShow, order: 1), me],
          target: me,
        ),
        etaMinutes: 9,
        tripId: 1,
        empId: 2,
      );

      expect(content!.progressPercent, 50);
    });

    test('payload survives missing ids without crashing', () {
      final me = _stop(state: StopState.current, isMe: true, order: 1);
      final content = LiveTripNotificationContent.fromTrackingState(
        timeline: _timeline(stops: [me], target: me),
        etaMinutes: 5,
        tripId: null,
        empId: null,
      );

      // The router rejects this payload rather than opening a broken screen.
      expect(content!.payload, 'live_trip::');
    });
  });
}
