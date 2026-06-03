import 'dart:convert';

import 'package:commutr_main/core/network/api_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

/// Payload delivered by the backend `ReceiveRouteLocation` event.
class RouteLocationPayload {
  final int? dsId;
  final double? latitude;
  final double? longitude;
  final double? speed;
  final String? gpsTime;
  final int? tripStatusCode;
  final String? tripStatusName;
  final String? source;
  final bool? panic;

  const RouteLocationPayload({
    this.dsId,
    this.latitude,
    this.longitude,
    this.speed,
    this.gpsTime,
    this.tripStatusCode,
    this.tripStatusName,
    this.source,
    this.panic,
  });

  factory RouteLocationPayload.fromJson(Map<String, dynamic> json) {
    double? readDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return RouteLocationPayload(
      dsId: (json['dsId'] as num?)?.toInt(),
      latitude: readDouble(json['latitude']),
      longitude: readDouble(json['longitude']),
      speed: readDouble(json['speed']),
      gpsTime: json['gpsTime']?.toString(),
      tripStatusCode: (json['tripStatusCode'] as num?)?.toInt(),
      tripStatusName: json['tripStatusName']?.toString(),
      source: json['source']?.toString(),
      panic: json['panic'] as bool?,
    );
  }

  @override
  String toString() =>
      'RouteLocationPayload(dsId=$dsId, lat=$latitude, lng=$longitude, '
      'speed=$speed, gpsTime=$gpsTime, status=$tripStatusName, panic=$panic)';
}

/// Reusable SignalR service for real-time vehicle route tracking.
///
/// Connection flow:
///   The signalr_netcore SDK handles negotiate + WebSocket automatically.
///   We only need to supply the accessTokenFactory and call connect().
///   3. Call [joinTrackingGroup] with dsId to subscribe to a trip's updates.
///
/// Usage:
/// ```dart
/// final service = RouteTrackingSignalRService();
/// service.addLocationListener((payload) { /* update map */ });
/// await service.connect(accessToken: token);
/// await service.joinTrackingGroup(dsId: tripId);
/// // on dispose:
/// await service.leaveTrackingGroup(dsId: tripId);
/// await service.disconnect();
/// ```
class RouteTrackingSignalRService {
  static const String _hubUrl = ApiConstants.routeTrackingHubUrl;

  static const String _joinMethod = 'JoinRouteTrackingGroup';
  static const String _leaveMethod = 'LeaveRouteTrackingGroup';
  static const String _receiveEvent = 'ReceiveRouteLocation';

  HubConnection? _connection;

  // Track the last joined group so we can rejoin after automatic reconnect.
  int? _lastJoinedDsId;

  // Prevent registering the ReceiveRouteLocation handler more than once.
  bool _listenerRegistered = false;

  final List<void Function(RouteLocationPayload)> _locationListeners = [];

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Returns true when the hub connection is active.
  bool get isConnected =>
      _connection?.state == HubConnectionState.Connected;

  /// Subscribe to incoming location updates.
  void addLocationListener(void Function(RouteLocationPayload) listener) {
    _locationListeners.add(listener);
    debugPrint('[RouteTrackingSignalR] Listener added. '
        'Total=${_locationListeners.length}');
  }

  /// Unsubscribe from location updates.
  void removeLocationListener(void Function(RouteLocationPayload) listener) {
    _locationListeners.remove(listener);
    debugPrint('[RouteTrackingSignalR] Listener removed. '
        'Total=${_locationListeners.length}');
  }

  /// Establish connection to the route-tracking hub.
  ///
  /// [accessToken] — JWT bearer token (without "Bearer " prefix).
  Future<void> connect({required String accessToken}) async {
    // Guard: skip if already connected.
    if (_connection?.state == HubConnectionState.Connected) {
      debugPrint('[RouteTrackingSignalR] Already connected — skipping connect().');
      return;
    }

    debugPrint('[RouteTrackingSignalR] Connecting to hub: $_hubUrl');

    // Let the SDK handle negotiate + transport selection automatically.
    // Passing accessTokenFactory attaches the JWT to both negotiate and WebSocket.
    _connection = HubConnectionBuilder()
        .withUrl(
          _hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => accessToken,
          ),
        )
        // Automatic reconnect with default back-off: 0s, 2s, 10s, 30s.
        .withAutomaticReconnect()
        .build();

    // Lifecycle: closed.
    _connection!.onclose(({error}) {
      debugPrint('[RouteTrackingSignalR] Connection CLOSED. error=$error');
    });

    // Lifecycle: attempting reconnect.
    _connection!.onreconnecting(({error}) {
      debugPrint('[RouteTrackingSignalR] RECONNECTING… error=$error');
    });

    // Lifecycle: successfully reconnected — rejoin the previous tracking group.
    _connection!.onreconnected(({connectionId}) {
      debugPrint('[RouteTrackingSignalR] RECONNECTED. connectionId=$connectionId');
      if (_lastJoinedDsId != null) {
        debugPrint('[RouteTrackingSignalR] Rejoining group dsId=$_lastJoinedDsId '
            'after reconnect.');
        joinTrackingGroup(_lastJoinedDsId!);
      }
    });

    // Register the ReceiveRouteLocation handler exactly once.
    _registerLocationHandler();

    // Step 3 — start the connection.
    try {
      await _connection!.start();
      debugPrint('[RouteTrackingSignalR] Connection SUCCESS. '
          'state=${_connection!.state}');
    } catch (e) {
      debugPrint('[RouteTrackingSignalR] Connection FAILED: $e');
      rethrow;
    }
  }

  /// Stop the hub connection and clear all state.
  Future<void> disconnect() async {
    debugPrint('[RouteTrackingSignalR] Disconnecting…');
    try {
      await _connection?.stop();
    } catch (e) {
      debugPrint('[RouteTrackingSignalR] Error during stop: $e');
    }
    _connection = null;
    _lastJoinedDsId = null;
    _listenerRegistered = false;
    debugPrint('[RouteTrackingSignalR] Disconnected and state cleared.');
  }

  /// Tell the server to push location updates for [dsId] to this client.
  Future<void> joinTrackingGroup(int dsId) async {
    if (_connection?.state != HubConnectionState.Connected) {
      debugPrint('[RouteTrackingSignalR] joinTrackingGroup($dsId) skipped — '
          'not connected (state=${_connection?.state}).');
      return;
    }
    try {
      await _connection!.invoke(_joinMethod, args: [dsId]);
      _lastJoinedDsId = dsId;
      debugPrint('[RouteTrackingSignalR] Joined tracking group dsId=$dsId ✓');
    } catch (e) {
      debugPrint('[RouteTrackingSignalR] Failed to join group dsId=$dsId: $e');
      rethrow;
    }
  }

  /// Tell the server to stop pushing updates for [dsId] to this client.
  Future<void> leaveTrackingGroup(int dsId) async {
    if (_connection?.state != HubConnectionState.Connected) {
      debugPrint('[RouteTrackingSignalR] leaveTrackingGroup($dsId) skipped — '
          'not connected.');
      return;
    }
    try {
      await _connection!.invoke(_leaveMethod, args: [dsId]);
      if (_lastJoinedDsId == dsId) _lastJoinedDsId = null;
      debugPrint('[RouteTrackingSignalR] Left tracking group dsId=$dsId ✓');
    } catch (e) {
      debugPrint('[RouteTrackingSignalR] Failed to leave group dsId=$dsId: $e');
      rethrow;
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Register the [_receiveEvent] handler once to avoid duplicate callbacks.
  void _registerLocationHandler() {
    if (_listenerRegistered) return;
    _listenerRegistered = true;

    _connection!.on(_receiveEvent, (args) {
      if (args == null || args.isEmpty) {
        debugPrint('[RouteTrackingSignalR] $_receiveEvent received null/empty args.');
        return;
      }

      debugPrint('[RouteTrackingSignalR] $_receiveEvent raw args: $args');

      try {
        final raw = args[0];
        final Map<String, dynamic> jsonMap;

        if (raw is Map<String, dynamic>) {
          jsonMap = raw;
        } else if (raw is String) {
          // Some SignalR servers send JSON-encoded strings.
          jsonMap = Map<String, dynamic>.from(
            jsonDecode(raw) as Map,
          );
        } else {
          debugPrint('[RouteTrackingSignalR] Unexpected payload type: '
              '${raw.runtimeType}');
          return;
        }

        final payload = RouteLocationPayload.fromJson(jsonMap);
        debugPrint('[RouteTrackingSignalR] Location update: $payload');

        // Dispatch to all registered listeners (copy to avoid ConcurrentModification).
        for (final listener in List.of(_locationListeners)) {
          listener(payload);
        }
      } catch (e) {
        debugPrint('[RouteTrackingSignalR] Failed to parse $_receiveEvent: $e');
      }
    });

    debugPrint('[RouteTrackingSignalR] $_receiveEvent handler registered.');
  }

}
