import 'dart:convert';

import 'cancel_schedule_confirmation_response.dart';

/// Wraps the `POST /UserApp/UserTripCancelConfirmation` response.
///
/// This is the active-trip counterpart to
/// [CancelScheduleConfirmationResponse]. The API is the single source of truth
/// for the active-trip cancel / no-show confirmation popup: it returns the
/// icon, title, message and the buttons (with their actions) to render.
///
/// The response is an envelope (identical in shape to the scheduled-cancel
/// confirmation): the outer `result[0]` carries `errorCode` / `dB_Response`,
/// and its inner `result` value is a **JSON-encoded string** holding the popup
/// config array.
///
/// Success shape:
/// ```json
/// {
///   "result": [
///     {
///       "errorCode": 0,
///       "dB_Response": "Success",
///       "result": "[{\"popupId\":\"no_show\",\"icon\":\"warning\",\"title\":\"Mark No Show\",\"message\":\"This schedule is past the cancellation time. Do you want to mark it as No Show?\",\"buttons\":[{\"id\":\"no_show\",\"text\":\"Mark No Show\",\"action\":\"markNoShow\",\"order\":1},{\"id\":\"go_back\",\"text\":\"Go Back\",\"action\":\"dismiss\",\"order\":2}]}]"
///     }
///   ],
///   "isSuccess": true,
///   "message": "Success"
/// }
/// ```
///
/// The popup config reuses [CancelSchedulePopup] / [CancelScheduleButton] /
/// [CancelScheduleAction] since the shape is identical to the scheduled flow.
class CancelActiveTripConfirmationResponse {
  /// `0` means the popup config is valid and the dialog should be shown.
  final int errorCode;

  /// Human-readable message. On failure (`errorCode != 0`) this is what should
  /// be surfaced to the user instead of opening the dialog.
  final String dbResponse;

  /// The popup configuration; `null` on failure / empty result.
  final CancelSchedulePopup? popup;

  const CancelActiveTripConfirmationResponse({
    required this.errorCode,
    required this.dbResponse,
    this.popup,
  });

  /// `true` when the backend returned a usable popup config.
  bool get isSuccess => errorCode == 0 && popup != null;

  factory CancelActiveTripConfirmationResponse.fromJson(
      Map<String, dynamic> json) {
    // Unwrap the outer envelope: prefer `result[0]`, fall back to the top-level
    // map for flat/legacy shapes.
    Map<String, dynamic> inner = json;
    final rawEnvelope = json['result'] ?? json['Result'];
    if (rawEnvelope is List &&
        rawEnvelope.isNotEmpty &&
        rawEnvelope.first is Map) {
      inner = Map<String, dynamic>.from(rawEnvelope.first as Map);
    } else if (rawEnvelope is Map) {
      inner = Map<String, dynamic>.from(rawEnvelope);
    }

    final rawError = inner['errorCode'] ?? inner['ErrorCode'];
    final errorCode = rawError is num
        ? rawError.toInt()
        : int.tryParse(rawError?.toString() ?? '') ?? -1;
    final dbResponse = (inner['dB_Response'] ??
            inner['DB_Response'] ??
            inner['dbResponse'] ??
            '')
        .toString()
        .trim();

    // The inner `result` is a JSON-encoded string holding the popup config
    // array (may also arrive already-decoded as a List/Map).
    final popup = _parsePopup(inner['result'] ?? inner['Result']);

    return CancelActiveTripConfirmationResponse(
      errorCode: errorCode,
      dbResponse: dbResponse,
      popup: popup,
    );
  }

  /// Decodes the nested popup config from a JSON string (or an
  /// already-decoded List/Map) into a [CancelSchedulePopup].
  static CancelSchedulePopup? _parsePopup(Object? raw) {
    if (raw == null) return null;
    Object? decoded = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return null;
      }
    }
    if (decoded is List) {
      if (decoded.isEmpty || decoded.first is! Map) return null;
      return CancelSchedulePopup.fromJson(
          Map<String, dynamic>.from(decoded.first as Map));
    }
    if (decoded is Map) {
      return CancelSchedulePopup.fromJson(Map<String, dynamic>.from(decoded));
    }
    return null;
  }
}
