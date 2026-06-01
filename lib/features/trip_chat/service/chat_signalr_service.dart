import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../data/model/chat_message.dart';

/// Manages a single SignalR connection to the chat hub for one trip.
///
/// Call [connect] once, subscribe via [addListener], then
/// [disconnect] when the screen is disposed.
///
/// Connection flow:
///   1. POST {hubUrl}/negotiate?negotiateVersion=1  → connectionId + connectionToken
///   2. Open WebSocket to {hubUrl}?id={connectionToken} with skipNegotiation=true
class ChatSignalRService {
  HubConnection? _connection;
  String? _connectionId;
  String? _connectionToken;

  final List<void Function(ChatMessage)> _listeners = [];

  void addListener(void Function(ChatMessage) listener) =>
      _listeners.add(listener);

  void removeListener(void Function(ChatMessage) listener) =>
      _listeners.remove(listener);

  HubConnectionState get state =>
      _connection?.state ?? HubConnectionState.Disconnected;

  /// The connectionId assigned during negotiate. Available after [connect].
  String? get connectionId => _connectionId;

  /// [hubUrl]      — e.g. "https://dev-core.commutr.in/hubs/chat"
  /// [accessToken] — bearer token without "Bearer " prefix
  Future<void> connect({
    required String hubUrl,
    required String accessToken,
  }) async {
    if (_connection != null &&
        _connection!.state == HubConnectionState.Connected) {
      return;
    }

    // Step 1 — negotiate: get connectionId + connectionToken from server.
    await _negotiate(hubUrl: hubUrl, accessToken: accessToken);

    // Step 2 — build WebSocket URL with connectionToken as ?id= param.
    // SignalR requires skipNegotiation=true when we supply the token ourselves.
    final wsUrl = _connectionToken != null
        ? '$hubUrl?id=${Uri.encodeComponent(_connectionToken!)}'
        : hubUrl;

    _connection = HubConnectionBuilder()
        .withUrl(
          wsUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => accessToken,
            transport: HttpTransportType.WebSockets,
            skipNegotiation: _connectionToken != null,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.on('ReceiveMessage', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final raw = args[0];
        if (raw is Map<String, dynamic>) {
          final msg = ChatMessage.fromJson(raw);
          for (final l in List.of(_listeners)) {
            l(msg);
          }
        }
      } catch (e) {
        debugPrint('[ChatSignalR] ReceiveMessage parse error: $e');
      }
    });

    _connection!.onclose(({error}) =>
        debugPrint('[ChatSignalR] Connection closed. error=$error'));

    _connection!.onreconnecting(({error}) =>
        debugPrint('[ChatSignalR] Reconnecting… error=$error'));

    _connection!.onreconnected(({connectionId}) {
      _connectionId = connectionId;
      debugPrint('[ChatSignalR] Reconnected. connectionId=$connectionId');
    });

    try {
      await _connection!.start();
      debugPrint(
        '[ChatSignalR] Connected. '
        'connectionId=$_connectionId '
        'state=${_connection!.state}',
      );
    } catch (e) {
      debugPrint('[ChatSignalR] start() failed: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      await _connection?.stop();
    } catch (_) {}
    _connection = null;
    _connectionId = null;
    _connectionToken = null;
    _listeners.clear();
    debugPrint('[ChatSignalR] Disconnected.');
  }

  /// POST {hubUrl}/negotiate?negotiateVersion=1
  /// Stores connectionId + connectionToken for use in the WebSocket URL.
  Future<void> _negotiate({
    required String hubUrl,
    required String accessToken,
  }) async {
    final dio = Dio();
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '$hubUrl/negotiate',
        queryParameters: {'negotiateVersion': '1'},
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      final data = response.data;
      if (data != null) {
        _connectionId = data['connectionId'] as String?;
        _connectionToken = data['connectionToken'] as String?;
        debugPrint(
          '[ChatSignalR] Negotiate OK. '
          'connectionId=$_connectionId '
          'connectionToken=$_connectionToken',
        );
      }
    } catch (e) {
      // If negotiate fails we fall back to letting signalr_netcore negotiate.
      debugPrint('[ChatSignalR] Negotiate failed, will let SDK negotiate: $e');
    } finally {
      dio.close();
    }
  }
}
