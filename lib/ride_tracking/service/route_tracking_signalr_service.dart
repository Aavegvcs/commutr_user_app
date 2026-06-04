import 'dart:async';
import 'dart:convert';

import 'package:commutr_main/core/debug/api_log_entry.dart';
import 'package:commutr_main/core/debug/api_logger_service.dart';
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
class RouteTrackingSignalRService {
  static const String _hubUrl = ApiConstants.routeTrackingHubUrl;

  static const String _joinMethod = 'JoinRouteTrackingGroup';
  static const String _leaveMethod = 'LeaveRouteTrackingGroup';
  static const String _receiveEvent = 'ReceiveRouteLocation';

  HubConnection? _connection;

  int? _lastJoinedDsId;
  bool _listenerRegistered = false;
  bool _intentionalDisconnect = false;
  bool _reconnectLoopRunning = false;
  String? _lastAccessToken;
  Timer? _pingTimer;

  static const Duration _pingInterval = Duration(seconds: 25);

  static const List<Duration> _manualBackoff = [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  final List<void Function(RouteLocationPayload)> _locationListeners = [];

  // ── Logging helpers ─────────────────────────────────────────────────────────

  static String _ts() {
    final n = DateTime.now();
    final h = n.hour.toString().padLeft(2, '0');
    final m = n.minute.toString().padLeft(2, '0');
    final s = n.second.toString().padLeft(2, '0');
    final ms = n.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  void _log(String message) =>
      debugPrint('[SignalR ${_ts()}] $message');

  static String _prettyJson(dynamic value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  void _logSuccess({
    required String operation,
    required String url,
    dynamic requestBody,
    dynamic responseBody,
    Duration? duration,
  }) {
    _log('✅ $operation');
    if (requestBody != null) {
      _log('   request: ${_prettyJson(requestBody)}');
    }
    if (responseBody != null) {
      _log('   response: ${_prettyJson(responseBody)}');
    }
    ApiLoggerService.instance.addEntry(ApiLogEntry(
      id: 'sr_ok_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      method: 'WS',
      url: url,
      status: ApiLogStatus.success,
      source: ApiLogSource.signalR,
      requestBody: requestBody,
      responseBody: responseBody,
      duration: duration,
    ));
  }

  void _logError({
    required String operation,
    required String url,
    required String errorMessage,
    dynamic requestBody,
    dynamic responseBody,
    Duration? duration,
  }) {
    _log('🔴 $operation — $errorMessage');
    if (responseBody != null) {
      _log('   response: ${_prettyJson(responseBody)}');
    }
    ApiLoggerService.instance.addEntry(ApiLogEntry(
      id: 'sr_err_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      method: 'WS',
      url: url,
      status: ApiLogStatus.error,
      source: ApiLogSource.signalR,
      requestBody: requestBody,
      responseBody: responseBody,
      duration: duration,
      errorMessage: errorMessage,
    ));
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  void addLocationListener(void Function(RouteLocationPayload) listener) {
    _locationListeners.add(listener);
    _log('👂 Listener added  (total=${_locationListeners.length})');
  }

  void removeLocationListener(void Function(RouteLocationPayload) listener) {
    _locationListeners.remove(listener);
    _log('🔇 Listener removed (total=${_locationListeners.length})');
  }

  Future<void> connect({required String accessToken}) async {
    if (_connection?.state == HubConnectionState.Connected) {
      _log('⚡ Already connected — skipping connect().');
      return;
    }

    _intentionalDisconnect = false;
    _lastAccessToken = accessToken;

    _log('🔌 Connecting → $_hubUrl');

    final connectId = 'sr_connect_${DateTime.now().millisecondsSinceEpoch}';
    final connectStart = DateTime.now();
    ApiLoggerService.instance.addEntry(ApiLogEntry(
      id: connectId,
      timestamp: connectStart,
      method: 'WS',
      url: _hubUrl,
      status: ApiLogStatus.pending,
      source: ApiLogSource.signalR,
    ));

    _connection = HubConnectionBuilder()
        .withUrl(
          _hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => accessToken,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.onclose(({error}) {
      _stopPingTimer();
      _logError(
        operation: 'CLOSED',
        url: _hubUrl,
        errorMessage: error != null ? 'CLOSED: $error' : 'CLOSED',
        responseBody: error != null ? {'error': error.toString()} : null,
      );
      if (!_intentionalDisconnect) {
        _log('♻️  Starting manual reconnect loop…');
        _startReconnectLoop();
      }
    });

    _connection!.onreconnecting(({error}) {
      _log('🟡 RECONNECTING…${error != null ? " error=$error" : ""}');
      ApiLoggerService.instance.addEntry(ApiLogEntry(
        id: 'sr_reconnecting_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        method: 'WS',
        url: _hubUrl,
        status: ApiLogStatus.pending,
        source: ApiLogSource.signalR,
        errorMessage: error != null ? 'RECONNECTING: $error' : 'RECONNECTING…',
        responseBody:
            error != null ? {'event': 'RECONNECTING', 'error': error.toString()} : {'event': 'RECONNECTING'},
      ));
    });

    _connection!.onreconnected(({connectionId}) {
      _logSuccess(
        operation: 'RECONNECTED  connectionId=$connectionId',
        url: _hubUrl,
        responseBody: {'connectionId': connectionId, 'event': 'RECONNECTED'},
      );
      if (_lastJoinedDsId != null) {
        _log('📡 Rejoining group dsId=$_lastJoinedDsId after reconnect…');
        joinTrackingGroup(_lastJoinedDsId!);
      }
    });

    _registerLocationHandler();

    try {
      await _connection!.start();
      final elapsed = DateTime.now().difference(connectStart).inMilliseconds;
      final responseBody = {
        'event': 'CONNECTED',
        'state': '${_connection!.state}',
      };
      _log('🟢 CONNECTED  state=${_connection!.state}  (${elapsed}ms)');
      _log('   response: ${_prettyJson(responseBody)}');
      ApiLoggerService.instance.updateEntry(
        connectId,
        ApiLogEntry(
          id: connectId,
          timestamp: connectStart,
          method: 'WS',
          url: _hubUrl,
          status: ApiLogStatus.success,
          source: ApiLogSource.signalR,
          duration: Duration(milliseconds: elapsed),
          responseBody: responseBody,
        ),
      );
      _startPingTimer();
    } catch (e) {
      final elapsed = DateTime.now().difference(connectStart).inMilliseconds;
      _log('🔴 CONNECT FAILED (${elapsed}ms) — $e');
      ApiLoggerService.instance.updateEntry(
        connectId,
        ApiLogEntry(
          id: connectId,
          timestamp: connectStart,
          method: 'WS',
          url: _hubUrl,
          status: ApiLogStatus.error,
          source: ApiLogSource.signalR,
          duration: Duration(milliseconds: elapsed),
          errorMessage: e.toString(),
          responseBody: {'event': 'CONNECT_FAILED', 'error': e.toString()},
        ),
      );
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _stopPingTimer();
    _log('🔌 Disconnecting (intentional)…');
    try {
      await _connection?.stop();
      _logSuccess(
        operation: 'DISCONNECTED',
        url: _hubUrl,
        responseBody: {'event': 'DISCONNECTED', 'intentional': true},
      );
    } catch (e) {
      _logError(
        operation: 'DISCONNECT_FAILED',
        url: _hubUrl,
        errorMessage: e.toString(),
        responseBody: {'event': 'DISCONNECT_FAILED', 'error': e.toString()},
      );
    }
    _connection = null;
    _lastJoinedDsId = null;
    _listenerRegistered = false;
    _log('⬛ Disconnected — state cleared.');
  }

  Future<void> joinTrackingGroup(int dsId) async {
    final url = '$_hubUrl → $_joinMethod';
    final requestBody = {'dsId': dsId};
    if (_connection?.state != HubConnectionState.Connected) {
      final msg =
          'joinTrackingGroup($dsId) skipped — not connected (state=${_connection?.state})';
      _log('⚠️  $msg');
      _logError(operation: _joinMethod, url: url, errorMessage: msg, requestBody: requestBody);
      return;
    }
    try {
      await _connection!.invoke(_joinMethod, args: [dsId]);
      _lastJoinedDsId = dsId;
      _logSuccess(
        operation: 'Joined group dsId=$dsId',
        url: url,
        requestBody: requestBody,
        responseBody: {'event': _joinMethod, 'dsId': dsId, 'success': true},
      );
    } catch (e) {
      _logError(
        operation: 'Failed to join group dsId=$dsId',
        url: url,
        errorMessage: e.toString(),
        requestBody: requestBody,
        responseBody: {'event': _joinMethod, 'dsId': dsId, 'error': e.toString()},
      );
      rethrow;
    }
  }

  Future<void> leaveTrackingGroup(int dsId) async {
    final url = '$_hubUrl → $_leaveMethod';
    final requestBody = {'dsId': dsId};
    if (_connection?.state != HubConnectionState.Connected) {
      final msg = 'leaveTrackingGroup($dsId) skipped — not connected';
      _log('⚠️  $msg');
      _logError(operation: _leaveMethod, url: url, errorMessage: msg, requestBody: requestBody);
      return;
    }
    try {
      await _connection!.invoke(_leaveMethod, args: [dsId]);
      if (_lastJoinedDsId == dsId) _lastJoinedDsId = null;
      _logSuccess(
        operation: 'Left group dsId=$dsId',
        url: url,
        requestBody: requestBody,
        responseBody: {'event': _leaveMethod, 'dsId': dsId, 'success': true},
      );
    } catch (e) {
      _logError(
        operation: 'Failed to leave group dsId=$dsId',
        url: url,
        errorMessage: e.toString(),
        requestBody: requestBody,
        responseBody: {'event': _leaveMethod, 'dsId': dsId, 'error': e.toString()},
      );
      rethrow;
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  // ── Ping / heartbeat ────────────────────────────────────────────────────────

  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(_pingInterval, (_) => _ping());
    _log('💓 Heartbeat started (every ${_pingInterval.inSeconds}s)');
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> _ping() async {
    if (_intentionalDisconnect) return;
    final state = _connection?.state;
    if (state == HubConnectionState.Connected) {
      _log('💓 PING  state=$state');
      return;
    }
    // Connection is no longer live — stop the timer and trigger reconnect.
    _log('💔 PING detected dead connection (state=$state) — triggering reconnect');
    _stopPingTimer();
    _startReconnectLoop();
  }

  void _startReconnectLoop() {
    if (_reconnectLoopRunning) {
      _log('⚠️  Reconnect loop already running — skipping duplicate trigger');
      return;
    }
    _manualReconnectLoop();
  }

  Future<void> _manualReconnectLoop() async {
    _reconnectLoopRunning = true;
    int attempt = 0;
    try {
      while (!_intentionalDisconnect) {
        final delay = _manualBackoff[attempt.clamp(0, _manualBackoff.length - 1)];
        _log('⏳ Manual reconnect #${attempt + 1} in ${delay.inSeconds}s…');
        await Future<void>.delayed(delay);

        if (_intentionalDisconnect) break;
        if (_connection?.state == HubConnectionState.Connected) break;

        final token = _lastAccessToken;
        if (token == null) break;

        _log('🔄 Manual reconnect #${attempt + 1} — attempting connect…');
        try {
          _connection = null;
          _listenerRegistered = false;
          await connect(accessToken: token);
          if (_lastJoinedDsId != null) await joinTrackingGroup(_lastJoinedDsId!);
          _logSuccess(
            operation: 'Manual reconnect #${attempt + 1} SUCCESS',
            url: _hubUrl,
            responseBody: {'event': 'MANUAL_RECONNECT', 'attempt': attempt + 1},
          );
          return;
        } catch (e) {
          _logError(
            operation: 'Manual reconnect #${attempt + 1} FAILED',
            url: _hubUrl,
            errorMessage: e.toString(),
            responseBody: {
              'event': 'MANUAL_RECONNECT_FAILED',
              'attempt': attempt + 1,
              'error': e.toString(),
            },
          );
          attempt++;
        }
      }
      _log('🛑 Manual reconnect loop ended (intentional=$_intentionalDisconnect)');
    } finally {
      _reconnectLoopRunning = false;
    }
  }

  void _registerLocationHandler() {
    if (_listenerRegistered) return;
    _listenerRegistered = true;

    _connection!.on(_receiveEvent, (args) {
      if (args == null || args.isEmpty) {
        _logError(
          operation: '$_receiveEvent — null/empty args',
          url: '$_hubUrl → $_receiveEvent',
          errorMessage: 'null/empty args received',
        );
        return;
      }

      try {
        final raw = args[0];
        final Map<String, dynamic> jsonMap;

        if (raw is Map<String, dynamic>) {
          jsonMap = raw;
        } else if (raw is String) {
          jsonMap = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        } else {
          _logError(
            operation: '$_receiveEvent — unexpected payload type',
            url: '$_hubUrl → $_receiveEvent',
            errorMessage: 'unexpected type: ${raw.runtimeType}',
            responseBody: {'raw': raw.toString()},
          );
          return;
        }

        final payload = RouteLocationPayload.fromJson(jsonMap);

        _logSuccess(
          operation:
              '📍 LOCATION UPDATE'
              '  dsId=${payload.dsId}'
              '  lat=${payload.latitude?.toStringAsFixed(6)}'
              '  lng=${payload.longitude?.toStringAsFixed(6)}'
              '  speed=${payload.speed?.toStringAsFixed(1)} km/h'
              '  status=${payload.tripStatusName ?? payload.tripStatusCode}'
              '  gpsTime=${payload.gpsTime}'
              '  panic=${payload.panic}'
              '  src=${payload.source}',
          url: '$_hubUrl → $_receiveEvent',
          responseBody: jsonMap,
        );

        for (final listener in List.of(_locationListeners)) {
          listener(payload);
        }
      } catch (e) {
        _logError(
          operation: '$_receiveEvent parse error',
          url: '$_hubUrl → $_receiveEvent',
          errorMessage: 'Parse error: $e',
          responseBody: {'raw': args.toString()},
        );
      }
    });

    _log('✅ $_receiveEvent handler registered');
  }
}
