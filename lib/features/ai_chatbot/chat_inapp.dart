import 'dart:convert';

import 'package:commutr_main/core/di/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Chat server base (scheme + host + port, no trailing slash).
const String kEtsChatBaseUrl = 'https://dev-core.commutr.in:5050';

/// Parent origin for embed / postMessage (matches `parent_origin` query param).
const String kEtsChatParentOrigin = 'https://dev-core.commutr.in';

const String kEtsChatHiveBoxName = 'ets_chat';

class EtsChatWebViewPage extends StatefulWidget {
  const EtsChatWebViewPage({
    super.key,
    this.chatBaseUrl = kEtsChatBaseUrl,
    this.parentOrigin = kEtsChatParentOrigin,
    required this.accessToken,
    required this.userId,
    required this.tenantId,
    this.userType = 'manager',
  });

  final String chatBaseUrl;
  final String parentOrigin;
  final String accessToken;
  final String userId;
  final String tenantId;
  final String userType;

  @override
  State<EtsChatWebViewPage> createState() => _EtsChatWebViewPageState();
}

class _EtsChatWebViewPageState extends State<EtsChatWebViewPage> {
  static const String _boxName = kEtsChatHiveBoxName;
  static const String _sessionKey = 'mobile_webview_session_id';
  static const String _deviceKey = 'mobile_webview_device_id';

  late final Box _box;
  late final WebViewController _controller;

  bool _ready = false;
  bool _loading = true;

  String _sessionId = '';
  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    _box = Hive.box(_boxName);
    _init();
  }

  Future<void> _init() async {
    _sessionId = (_box.get(_sessionKey) as String?) ?? '';
    _deviceId = (_box.get(_deviceKey) as String?) ?? '';

    if (_deviceId.isEmpty) {
      _deviceId = 'mobile-${DateTime.now().millisecondsSinceEpoch}';
      await _box.put(_deviceKey, _deviceId);
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _loading = true);
            }
          },
          onPageFinished: (_) async {
            await _captureSessionId();
            if (mounted) {
              setState(() => _loading = false);
            }
          },
        ),
      )
      ..loadHtmlString(
        _buildWrapperHtml(),
        baseUrl: widget.parentOrigin,
      );

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  String _buildWrapperHtml() {
    final base = widget.chatBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final chatUrl = Uri.parse('$base/').replace(
      queryParameters: <String, String>{
        'embed': '1',
        'parent_origin': widget.parentOrigin,
        'widget_embed': '1',
        'channel': 'mobile',
        'user_id': widget.userId,
        'tenant_id': widget.tenantId,
        'user_type': widget.userType,
        'device_id': _deviceId,
        if (_sessionId.isNotEmpty) 'session_id': _sessionId,
      },
    ).toString();

    final tokenJs = jsonEncode(widget.accessToken);
    final sessionJs = jsonEncode(_sessionId);
    final deviceJs = jsonEncode(_deviceId);
    final chatUrlJs = jsonEncode(chatUrl);
    final originJs = jsonEncode(base);

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      height: 100%;
      background: #ffffff;
      overflow: hidden;
    }
    #ets-chat-frame {
      border: 0;
      width: 100%;
      height: 100%;
      display: block;
      background: #ffffff;
    }
  </style>
</head>
<body>
  <iframe id="ets-chat-frame" title="ETS Chat"></iframe>

  <script>
    window.ETS_CHAT_AUTH_TOKEN = $tokenJs;
    window.ETS_CHAT_SESSION_ID = $sessionJs;
    window.ETS_CHAT_DEVICE_ID = $deviceJs;

    const iframe = document.getElementById('ets-chat-frame');
    const chatOrigin = new URL($originJs).origin;

    window.addEventListener('message', function(event) {
      if (event.origin !== chatOrigin) return;

      const data = event.data || {};
      if (data.type === 'ets-chat-auth-token-request' && data.requestId) {
        iframe.contentWindow.postMessage(
          {
            type: 'ets-chat-auth-token-response',
            requestId: data.requestId,
            token: window.ETS_CHAT_AUTH_TOKEN || ''
          },
          event.origin
        );
      }
    });

    iframe.src = $chatUrlJs;
  </script>
</body>
</html>
''';
  }

  Future<void> _captureSessionId() async {
    try {
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          try {
            return window.ETS_CHAT_SESSION_ID || '';
          } catch (e) {
            return '';
          }
        })();
      ''');

      final jsSession = _normalizeJsResult(result);
      if (jsSession.isNotEmpty && jsSession != _sessionId) {
        _sessionId = jsSession;
        await _box.put(_sessionKey, _sessionId);
      }
    } catch (_) {}
  }

  String _normalizeJsResult(Object? value) {
    if (value == null) return '';
    final raw = value.toString();
    if (raw == 'null' || raw == 'undefined') return '';
    if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
      return raw.substring(1, raw.length - 1);
    }
    return raw;
  }

  Future<void> reloadChatWithNewToken(String newToken) async {
    final tokenJs = jsonEncode(newToken);
    await _controller.runJavaScript('window.ETS_CHAT_AUTH_TOKEN = $tokenJs;');
    await _controller.reload();
  }

  Future<void> clearStoredSession() async {
    await _box.delete(_sessionKey);
    _sessionId = '';
    await _controller.loadHtmlString(
      _buildWrapperHtml(),
      baseUrl: widget.parentOrigin,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Transport Assistant',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1A5C38), // deep green brand color
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh conversation',
            splashRadius: 24,
          ),
          const VerticalDivider(width: 8, thickness: 1, color: Colors.white24),
          IconButton(
            onPressed: clearStoredSession,
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear chat history',
            splashRadius: 24,
          ),
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Stack(
        children: <Widget>[
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}     