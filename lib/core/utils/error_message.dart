import 'dart:convert';

import 'package:dio/dio.dart';

import '../error/exceptions.dart';

/// Helpers to turn a caught error into a clean, human-readable message to show
/// the user, preferring the real server-returned message over a generic
/// fallback.
///
/// The convention across the app is to surface a short, friendly error string
/// (server `message`/`title`/`detail`/validation `errors`, or our own
/// [NetworkException]/[ServerException] message) — NEVER a raw
/// `DioException [...]` dump or an `Instance of 'ServerException'` string.
class ErrorMessage {
  ErrorMessage._();

  /// Best-effort user-facing message for any caught [error].
  ///
  /// Resolution order:
  /// 1. Our own typed exceptions ([NetworkException], [ServerException], …) —
  ///    use their carried message/title.
  /// 2. A [DioException] — dig into the response body, then the mapped app
  ///    exception in `error.error`. Its raw `toString()` is never shown.
  /// 3. Anything else — `toString()`, but only if it's a real message and not
  ///    a useless `Instance of '...'` / framework dump; otherwise [fallback].
  static String from(Object? error, {String fallback = 'Something went wrong'}) {
    if (error == null) return fallback;

    final typed = _fromTypedException(error);
    if (typed != null && typed.isNotEmpty) return typed;

    if (error is DioException) {
      final fromBody = _fromBody(error.response?.data);
      if (fromBody != null && fromBody.isNotEmpty) return fromBody;
      // The interceptor may have wrapped the error into one of our exceptions.
      final wrapped = _fromTypedException(error.error);
      if (wrapped != null && wrapped.isNotEmpty) return wrapped;
      // Deliberately do NOT surface error.message here — for a bad response it
      // is Dio's verbose "DioException [bad response]: ..." boilerplate.
      return fallback;
    }

    return _clean(error.toString()) ?? fallback;
  }

  /// Pulls the carried message out of our own exception types.
  static String? _fromTypedException(Object? error) {
    final String raw;
    switch (error) {
      case NetworkException(:final message):
      case BadRequestException(:final message):
      case UnauthorizedException(:final message):
      case NotFoundException(:final message):
      case ConflictException(:final message):
        raw = message;
      case ServerException(:final title):
        raw = title;
      default:
        return null;
    }
    return _clean(raw);
  }

  /// Extracts a message from a server response body (Map or JSON string),
  /// checking common keys and validation `errors` maps. Returns null if
  /// nothing usable is found.
  static String? _fromBody(dynamic data) {
    var body = data;
    if (body is String) {
      final trimmed = body.trim();
      if (trimmed.isEmpty) return null;
      try {
        body = jsonDecode(trimmed);
      } catch (_) {
        return _clean(trimmed);
      }
    }
    if (body is! Map) return null;

    final errors = body['errors'];
    if (errors is Map) {
      for (final v in errors.values) {
        if (v is List && v.isNotEmpty) return _clean(v.first.toString());
        if (v is String && v.trim().isNotEmpty) return _clean(v);
      }
    }

    for (final key in ['detail', 'title', 'message', 'error', 'errorMessage']) {
      final v = body[key];
      if (v is String && v.trim().isNotEmpty) return _clean(v);
      if (v is List && v.isNotEmpty) return _clean(v.first.toString());
    }

    final nested = body['result'];
    if (nested is Map) {
      for (final key in ['message', 'errorMessage', 'error']) {
        final v = nested[key];
        if (v is String && v.trim().isNotEmpty) return _clean(v);
      }
    }
    return null;
  }

  /// Trims, strips a leading `Exception: `, and rejects strings that are
  /// developer-facing noise rather than a user message. Returns null when the
  /// string isn't worth showing.
  static String? _clean(String? s) {
    if (s == null) return null;
    var text = s.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    if (text.isEmpty) return null;

    // "Instance of 'ServerException'", "Instance of '_Foo'", etc.
    if (RegExp(r"^Instance of '.*'$").hasMatch(text)) return null;
    // Dio's verbose "DioException [bad response]: ..." dump.
    if (text.startsWith('DioException')) return null;

    return text;
  }
}
